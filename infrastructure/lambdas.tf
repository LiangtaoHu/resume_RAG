data "aws_region" "curr_region" {}

/* ========================================================================== */
/* Listing Parser Lambda Function                                             */
/* ========================================================================== */
resource "aws_ecr_repository" "resume_rag_parse_listing_repo" {
  name = "resume-rag-parse-listing-repo"
  image_scanning_configuration {
    scan_on_push = true
  }
}

// Null resource is for executing arbitrary functions but doesn't do anything more than execution every apply
// I say every apply because we have triggers that are checked every apply, 
// that means the DockerFile, the code, or the function's requirements have changed and must be pushed towards AWS
resource "null_resource" "Lambda_DockerFile_Update" {
  triggers = {
    code_hash = filemd5("${path.module}/../lambda/parse_listing/lambda_scraper.py")
    requirements_hash = filemd5("${path.module}/../lambda/parse_listing/requirements.txt")
    docker_hash = filemd5("${path.module}/../lambda/parse_listing/Dockerfile")
  }

  provisioner "local-exec" {
    command = <<EOF
      # 1. Authenticate local Docker daemon with AWS ECR
      aws ecr get-login-password --region us-east-1 | docker login --username AWS --password-stdin ${aws_ecr_repository.resume_rag_parse_listing_repo.repository_url}
      
      # 2. Build the Docker image locally using the Dockerfile blueprint
      docker build -t ${aws_ecr_repository.resume_rag_parse_listing_repo.repository_url}:latest -f ${path.module}/../lambda/parse_listing/Dockerfile ${path.module}/../lambda/parse_listing/
      
      # 3. Push the image up to your AWS ECR Registry
      docker push ${aws_ecr_repository.resume_rag_parse_listing_repo.repository_url}:latest
    EOF
  }
}

resource "aws_iam_role" "lambda_parse_listing_role" {
  name = "lambda_parse_listing_role"
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action    = "sts:AssumeRole"
      Effect    = "Allow"
      Principal = { Service = "lambda.amazonaws.com" }
    }]
  })
  description = "Allows listing parser to invoke bedrock embeddings, upload Cloudwatch Logs"
}

resource "aws_iam_role_policy_attachment" "lambda_cloudwatch_logs_attachment" {
  role       = aws_iam_role.lambda_parse_listing_role.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
}

// Start of Bedrock Embedding Statement
data "aws_iam_policy_document" "lambda_embedding_statement" {
  statement {
    effect = "Allow"
    actions = ["bedrock:InvokeModel"]
    resources = ["arn:aws:bedrock:us-east-1::foundation-model/amazon.titan-embed-text-v2:0"]
  }
}

resource "aws_iam_policy" "lambda_embedding_policy" {
  name = "lambda-bedrock-model-access"
  policy = data.aws_iam_policy_document.lambda_embedding_statement.json
}

resource "aws_iam_role_policy_attachment" "lambda_embedding_attachment" {
  role = aws_iam_role.lambda_parse_listing_role.name
  policy_arn =  aws_iam_policy.lambda_embedding_policy.arn
}
// End of Bedrock Embedding Statement

data "aws_iam_policy_document" "lambda_aws_model_subscription_statement" {
  statement {
    effect = "Allow"
    actions = ["aws-market:Subscribe", "aws-market:Unsubscribe", "aws-market:ViewSubscriptions"]
    resources = ["*"]
  }
}

resource "aws_iam_policy" "lambda_aws_model_subscription_policy" {
  name = "lambda-aws-model-subscription"
  policy = data.aws_iam_policy_document.lambda_aws_model_subscription_statement.json
}

resource "aws_iam_role_policy_attachment" "lambda_aws_model_subscription_attachment" {
  role = aws_iam_role.lambda_parse_listing_role.name
  policy_arn = aws_iam_policy.lambda_aws_model_subscription_policy.arn
}

// Start of Dynamo GetItem, PutItem, Query Statement
data "aws_iam_policy_document" "lambda_dynamo_statement" {
  statement {
    effect = "Allow"
    actions = ["dynamodb:GetItem", "dynamodb:PutItem", "dynamodb:Query"]
    resources = [aws_dynamodb_table.res_opt_dynamodb_table.arn]
  }
}

resource "aws_iam_policy" "lambda_dynamo_policy" {
  name = "lambda-dynamodb-policy"
  policy = data.aws_iam_policy_document.lambda_dynamo_statement.json
}

resource "aws_iam_role_policy_attachment" "lambda_dynamo_attachment_parse_listing" {
  role = aws_iam_role.lambda_parse_listing_role.name
  policy_arn = aws_iam_policy.lambda_dynamo_policy.arn
}
// End of Dynamo GetItem, PutItem, Query Statement

resource "aws_iam_role_policy" "lambda_opensearch_policy" {
  name = "lambda-opensearch-serverless-access"
  role = aws_iam_role.lambda_parse_listing_role.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect   = "Allow"
      Action   = ["aoss:APIAccessAll"]
      Resource = [aws_opensearchserverless_collection.vector_db.arn]
    }]
  })
}

resource "aws_lambda_function" "lambda_parse_listing_func" {
  // Make sure we first finish Lambda_DockerFile_Update before making this, question more
  depends_on = [null_resource.Lambda_DockerFile_Update] 
  function_name = "lambda-parse-listing-func"
  role          = aws_iam_role.lambda_parse_listing_role.arn
  package_type  = "Image"
  image_uri     = "${aws_ecr_repository.resume_rag_parse_listing_repo.repository_url}:latest"
  timeout       = 180
  memory_size   = 2048
  environment {
    variables = {
      OPENSEARCH_URL = aws_opensearchserverless_collection.vector_db.collection_endpoint
      REGION_NAME = data.aws_region.curr_region.region
    }
  }
}

/* ========================================================================== */
/* Upload Resume Lambda Function                                              */
/* ========================================================================== */
resource "aws_iam_role" "lambda_upload_resume_role" {
    name = "lambda_upload_resume_role"
    assume_role_policy = jsonencode({
        Version = "2012-10-17"
        Statement = [{
            Effect = "Allow"
            Action = "sts:AssumeRole"
            Principal = { Service = "lambda.amazonaws.com"}
        }]
    })
}

resource "aws_iam_role_policy" "lambda_s3_upload_policy" {
    name = "lambda_s3_upload_policy"
    role = aws_iam_role.lambda_upload_resume_role.id
    policy = jsonencode({
        Version = "2012-10-17"
        Statement = [{
            Action = ["s3:PutObject"]
            Effect = "Allow"
            Resource = "${aws_s3_bucket.resume_bucket.arn}/*"
        }]
    })
}

// Dynamo Policy (Get, Put, Query) was created before in parse_listing's section. We just need to attach.
resource "aws_iam_role_policy_attachment" "lambda_dynamo_attachment_upload_resume" {
  role = aws_iam_role.lambda_upload_resume_role.name
  policy_arn = aws_iam_policy.lambda_dynamo_policy.arn
}

# data "archive_file" "lambda_upload_resume_file" {
#     type = "zip"
#     source_file = "${path.module}/../lambda/upload_resume/s3_presigned_url.py"
#     output_path = "${path.module}/../lambda/upload_resume/s3_presigned_url.zip"
# }

# data "archive_file" "lambda_layer_upload_resume_zip" {
#   type = "zip"
#   source_dir = "${path.module}/../lambda/upload_resume/lambda_layer"
#   output_path = "${path.module}/../lambda/upload_resume/lambda_layer/lambda_layer.zip"
# }

# resource aws_lambda_layer_version "lambda_layer_upload_resume" {
#   filename = data.archive_file.lambda_layer_upload_resume_zip.output_path
#   layer_name = "pymupdf4llm-layer"
#   source_code_hash = data.archive_file.lambda_layer_upload_resume_zip.output_base64sha256
#   compatible_runtimes = ["python3.9"]
#   skip_destroy = true
# }

resource "aws_ecr_repository" "resume_rag_upload_resume_repo" {
  name = "resume-rag-upload-resume-repo"
  image_scanning_configuration {
    scan_on_push = true
  }
}

resource "null_resource" "Lambda_DockerFile_Update" {
  triggers = {
    code_hash = filemd5("${path.module}/../lambda/upload_resume/image/s3_presigned_url.py")
    requirements_hash = filemd5("${path.module}/../lambda/upload_resume/image/requirements.txt")
    docker_hash = filemd5("${path.module}/../lambda/upload_resume/image/Dockerfile")
  }

  provisioner "local-exec" {
    command = <<EOF
      # 1. Authenticate local Docker daemon with AWS ECR
      aws ecr get-login-password --region us-east-1 | docker login --username AWS --password-stdin ${aws_ecr_repository.resume_rag_upload_resume_repo.repository_url}
      
      # 2. Build the Docker image locally using the Dockerfile blueprint
      docker build -t ${aws_ecr_repository.resume_rag_upload_resume_repo.repository_url}:latest -f ${path.module}/../lambda/upload_resume/image/Dockerfile ${path.module}/../lambda/upload_resume/image
      
      # 3. Push the image up to your AWS ECR Registry
      docker push ${aws_ecr_repository.resume_rag_upload_resume_repo.repository_url}:latest
    EOF
  }
}

resource "aws_lambda_function" "lambda_upload_resume_func" {
    depends_on = [null_resource.Lambda_DockerFile_upload_resume]
    function_name = "lambda-upload-resume-func"
    role = aws_iam_role.lambda_upload_resume_role.arn
    package_type = "Image"
    image_uri = "${aws_ecr_repository.resume_rag_upload_resume_repo.repository_url}:latest"
    timeout = 180
    memory_size = 2048
    environment {
      variables = {
        RESUME_BUCKET = aws_s3_bucket.resume_bucket.id,
        EXPIRATION_TIME = var.expiration_time,
        REGION_NAME = data.aws_region.curr_region.region
      }
    }
    tags = {}
}
/* ========================================================================== */
/* View Data Lambda Function                                                  */
/* ========================================================================== */
resource "aws_iam_role" "lambda_conversation_starter_role" {
  name = "lambda_conversation_starter_role"
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action    = "sts:AssumeRole"
      Effect    = "Allow"
      Principal = { Service = "lambda.amazonaws.com" }
    }]
  })
}

// Dynamo Policy (Get, Put, Query) was created before in parse_listing's section. We just need to attach.
resource "aws_iam_role_policy_attachment" "lambda_dynamo_attachment_view_data" {
  role = aws_iam_role.lambda_conversation_starter_role.name
  policy_arn = aws_iam_policy.lambda_dynamo_policy.arn
}

data "archive_file" "lambda_conversation_starter_file" {
    type = "zip"
    source_file = "${path.module}/../lambda/view_data/conversation_starter.py"
    output_path = "${path.module}/../lambda/view_data/conversation_starter.zip"
}

resource "aws_lambda_function" "lambda_conversation_starter_func" {
    filename = data.archive_file.lambda_conversation_starter_file.output_path
    function_name = "lambda_conversation_starter_func"
    role = aws_iam_role.lambda_conversation_starter_role.arn
    handler = "conversation_starter.handler"
    source_code_hash = data.archive_file.lambda_conversation_starter_file.output_base64sha256
    runtime = "python3.9"
    environment {
      variables = {
        DYNAMO_DB_TABLE = aws_dynamodb_table.res_opt_dynamodb_table.id
      }
    }
    tags = {}
}

/* ========================================================================== */
/* Message Bedrock Agent Lambda Function                                      */
/* ========================================================================== */
resource "aws_iam_role" "lambda_message_bedrock_resume_agent_role" {
  name = "lambda_message_agent_role"
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action    = "sts:AssumeRole"
      Effect    = "Allow"
      Principal = { Service = "lambda.amazonaws.com" }
    }]
  })
}

data "aws_iam_policy_document" "lambda_invoke_bedrock_statement" {
  statement {
    effect = "Allow"
    actions = ["bedrock:InvokeAgent"]
    resources = [aws_bedrockagent_agent.resume_agent.agent_arn]
  }
}

resource "aws_iam_policy" "lambda_invoke_bedrock_policy" {
  name = "lambda_invoke_agent_policy"
  policy = data.aws_iam_policy_document.lambda_invoke_bedrock_statement.json
}

resource "aws_iam_role_policy_attachment" "lambda_invoke_bedrock_attachment" {
  role = aws_iam_role.lambda_message_bedrock_resume_agent_role.name
  policy_arn =  aws_iam_policy.lambda_invoke_bedrock_policy.arn
}

// Dynamo Policy (Get, Put, Query) was created before in parse_listing's section. We just need to attach.
resource "aws_iam_role_policy_attachment" "lambda_dynamo_attachment_message_bedrock" {
  role = aws_iam_role.lambda_message_bedrock_resume_agent_role.name
  policy_arn = aws_iam_policy.lambda_dynamo_policy.arn
}

data "archive_file" "lambda_message_bedrock_file" {
    type = "zip"
    source_file = "${path.module}/../lambda/chat/message_bedrock.py"
    output_path = "${path.module}/../lambda/chat/message_bedrock.zip"
}

resource "aws_lambda_function" "lambda_message_bedrock_func" {
    filename = data.archive_file.lambda_message_bedrock_file.output_path
    function_name = "lambda-message-bedrock"
    role = aws_iam_role.lambda_message_bedrock_resume_agent_role.arn
    handler = "message_bedrock.handler"
    source_code_hash = data.archive_file.lambda_message_bedrock_file.output_base64sha256
    runtime = "python3.9"
    environment {
      variables = {
        DYNAMO_DB_TABLE = aws_dynamodb_table.res_opt_dynamodb_table.id
        KB_ID = aws_bedrockagent_knowledge_base.rag_kb.id
        AGENT_ID = aws_bedrockagent_agent.resume_agent.agent_id
        REGION_NAME = data.aws_region.curr_region.region
      }
    }
    tags = {}
}

/* ========================================================================== */
/* Delete Entries Lambda Function                                             */
/* ========================================================================== */
resource "aws_iam_role" "lambda_delete_entries_role" {
  name = "lambda_delete_entries_role"
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action    = "sts:AssumeRole"
      Effect    = "Allow"
      Principal = { Service = "lambda.amazonaws.com" }
    }]
  })
}

data "aws_iam_policy_document" "lambda_delete_entries_statement" {
  statement {
    effect = "Allow"
    actions = ["dynamodb:delete_item"]
    resources = [aws_dynamodb_table.res_opt_dynamodb_table.arn]
  }
}

resource "aws_iam_policy" "lambda_delete_entries_policy" {
  name = "lambda_delete_entries_policy"
  policy = data.aws_iam_policy_document.lambda_delete_entries_statement.json
}

resource "aws_iam_role_policy_attachment" "lambda_delete_entries_attachment" {
  role = aws_iam_role.lambda_delete_entries_role.name
  policy_arn =  aws_iam_policy.lambda_delete_entries_policy.arn
}

data "archive_file" "lambda_delete_entries_file" {
    type = "zip"
    source_file = "${path.module}/../lambda/delete_entries/delete_entry.py"
    output_path = "${path.module}/../lambda/delete_entries/delete_entry.zip"
}

resource "aws_lambda_function" "lambda_delete_entries_func" {
    filename = data.archive_file.lambda_delete_entries_file.output_path
    function_name = "lambda-delete-entries"
    role = aws_iam_role.lambda_delete_entries_role.arn
    handler = "message_bedrock.handler"
    source_code_hash = data.archive_file.lambda_delete_entries_file.output_base64sha256
    runtime = "python3.9"
    environment {
      variables = {
        DYNAMO_DB_TABLE = aws_dynamodb_table.res_opt_dynamodb_table.id
      }
    }
    tags = {}
}

/* ========================================================================== */
/* Lambda@Edge Functions (Check/Parse Auth)                                   */
/* Not in use because, we've changed to an API Gateway validation system and  */
/* A client side request to inject the correct code into our local storage    */
/* then redirect                                                              */
/* ========================================================================== */

# data "aws_iam_policy_document" "lambda_at_edge_statement" {
#     statement {
#         actions = ["sts:AssumeRole"]
#         principals {
#           type = "Service"
#           identifiers = ["lambda.amazonaws.com", "edgelambda.amazonaws.com"]
#         }
#     }
# }

# resource "aws_iam_role" "lambda_at_edge_role" {
#     name = "lambda-at-edge-role"
#     assume_role_policy = data.aws_iam_policy_document.lambda_at_edge_statement.json
# }

# data "archive_file" "lambda_at_edge_check_auth_file" {
#     type = "zip"
#     source_file = "${path.module}/../lambda/authorization/check_auth.py"
#     output_path = "${path.module}/../lambda/authorization/check_auth.zip"
# }

# resource "aws_lambda_function" "lambda_at_edge_check_auth_func" {
#     filename = data.archive_file.lambda_at_edge_check_auth_file.output_path
#     function_name = "check-auth-at-edge"
#     role = aws_iam_role.lambda_at_edge_role.arn
#     handler = "check_auth.lambda_handler"
#     code_sha256 = data.archive_file.lambda_at_edge_check_auth_file.output_base64sha256

#     provider = aws.us_east_1
#     publish = true
# }

# data "archive_file" "lambda_at_edge_parse_auth_file" {
#     type = "zip"
#     source_file = "${path.module}/../lambda/authorization/parse_auth.py"
#     output_path = "${path.module}/../lambda/authorization/parse_auth.zip"
# }

# resource "aws_lambda_function" "lambda_at_edge_parse_auth_func" {
#     filename = data.archive_file.lambda_at_edge_parse_auth_file.output_path
#     function_name = "parse-auth-at-edge"
#     role = aws_iam_role.lambda_at_edge_role.arn
#     handler = "parse_auth.lambda_handler"
#     code_sha256 = data.archive_file.lambda_at_edge_parse_auth_file.output_base64sha256

#     provider = aws.us_east_1
#     publish = true
# }

/* ========================================================================== */
/* S3 Event Trigger Lambda Functions (alert_dynamo_link/add_dynamo_resume)    */
/* ========================================================================== */
resource "aws_iam_role" "lambda_s3_trigger_role" {
    name = "lambda-s3-trigger-role"
    assume_role_policy = jsonencode({
        Version = "2012-10-17"
        Statement = [{
            Effect = "Allow"
            Action = "sts:AssumeRole"
            Principal = { Service = "lambda.amazonaws.com"}
        }]
    })
}

data "aws_iam_policy_document" "lambda_s3_trigger_statement" {
  statement {
    effect = "Allow"
    actions = ["dynamodb:GetItem", "dynamodb:UpdateItem", "dynamodb:PutItem"]
    resources = [aws_dynamodb_table.res_opt_dynamodb_table.arn]
  }
  statement {
    effect = "Allow"
    actions = ["s3:GetObject"]
    resources = ["${aws_s3_bucket.resume_bucket.arn}/*"]
  }
}

resource "aws_iam_policy" "lambda_s3_trigger_policy" {
  name = "lambda-s3-trigger-policy"
  policy = data.aws_iam_policy_document.lambda_s3_trigger_statement.json
}

resource "aws_iam_role_policy_attachment" "lambda_s3_trigger_attachment" {
  role = aws_iam_role.lambda_s3_trigger_role.name
  policy_arn = aws_iam_policy.lambda_s3_trigger_policy.arn
}

data "archive_file" "lambda_s3_trigger_on_object_upload_file" {
    type = "zip"
    source_file = "${path.module}/../lambda/upload_resume/on_object_upload.py"
    output_path = "${path.module}/../lambda/upload_resume/on_object_upload.zip"
}

resource "aws_lambda_function" "lambda_s3_trigger_on_object_upload_func" {
  function_name    = "on-object-upload-trigger"
  role             = aws_iam_role.lambda_s3_trigger_role.arn
  handler          = "on_object_upload.handler"
  filename         = data.archive_file.lambda_s3_trigger_on_object_upload_file.output_path
  runtime = "python3.9"
  source_code_hash = data.archive_file.lambda_s3_trigger_on_object_upload_file.output_base64sha256
  environment {
    variables = {
      REGION_NAME   = data.aws_region.curr_region.region
      DYNAMO_DB_TABLE = aws_dynamodb_table.res_opt_dynamodb_table.id
    }
  }
}

resource "aws_s3_bucket_notification" "s3_on_object_upload_notification" {
    bucket = aws_s3_bucket.resume_bucket.id
    lambda_function {
      lambda_function_arn = aws_lambda_function.lambda_s3_trigger_on_object_upload_func.arn
      events = ["s3:ObjectCreated:*"]
    }
    depends_on = [ aws_lambda_permission.allow_s3_to_invoke_trigger ]
}

resource "aws_lambda_permission" "allow_s3_to_invoke_trigger" {
  statement_id  = "AllowS3InvokeTrigger"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.lambda_s3_trigger_on_object_upload_func.function_name
  principal     = "s3.amazonaws.com"
  source_arn    = aws_s3_bucket.resume_bucket.arn
}