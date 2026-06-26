data "aws_region" "curr_region" {}

/* 
  Stage One:
  - Creating the Lambda Function that serves to scrape webpages, get the necessary information, then have them embedded.
  - Since we're going to be using Langchain, Selenium, etc, a typical Lambda function won't have the proper size, so we'll
  need a docker file.
  - We'll store our DockerFile in AWS ECR.
*/

resource "aws_ecr_repository" "resume_RAG_ecr_repo" {
  name = "resume-rag-images"
  image_scanning_configuration {
    scan_on_push = true
  }
}

// Null resource is for executing arbitrary functions but doesn't do anything more than execution every apply
// I say every apply because we have triggers that are checked every apply, 
// that means the DockerFile, the code, or the function's requirements have changed and must be pushed towards AWS
resource "null_resource" "Lambda_DockerFile_Update" {
  triggers = {
    code_hash = filemd5("${path.module}/parse_listing/lambda_scraper.py")
    requirements_hash = filemd5("${path.module}/parse_listing/requirements.txt")
    docker_hash = filemd5("${path.module}/parse_listing/Dockerfile")
  }

  provisioner "local-exec" {
    command = <<EOF
      # 1. Authenticate local Docker daemon with AWS ECR
      aws ecr get-login-password --region us-east-1 | docker login --username AWS --password-stdin ${aws_ecr_repository.resume_RAG_ecr_repo.repository_url}
      
      # 2. Build the Docker image locally using the Dockerfile blueprint
      docker build -t ${aws_ecr_repository.resume_RAG_ecr_repo.repository_url}:latest -f ${path.module}/parse_listing/Dockerfile ${path.module}/parse_listing/
      
      # 3. Push the image up to your AWS ECR Registry
      docker push ${aws_ecr_repository.resume_RAG_ecr_repo.repository_url}:latest
    EOF
  }
}

// IAM Role creation for Lambda to assume
resource "aws_iam_role" "lambda_role" {
  name = "lambda_role"
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action    = "sts:AssumeRole"
      Effect    = "Allow"
      Principal = { Service = "lambda.amazonaws.com" }
    }]
  })
}

// Attaches a pre-created IAM policy and attaches it to the role
// Anyone who has that role will have this policy
// This role allows the lambda function to execute/upload logs to CloudWatch
resource "aws_iam_role_policy_attachment" "lambda_logs" {
  role       = aws_iam_role.lambda_role.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
}

data "aws_iam_policy_document" "lambda_bedrock_policy" {
  statement {
    effect = "Allow"
    actions = ["bedrock:InvokeModel"]
    resources = ["arn:aws:bedrock:us-east-1::foundation-model/amazon.titan-embed-text-v2:0"]
  }
}

resource "aws_iam_policy" "lambda_bedrock_policy" {
  name = "lambda-bedrock-model-access"
  policy = data.aws_iam_policy_document.lambda_bedrock_policy.json
}

resource "aws_iam_role_policy_attachment" "lambda_bedrock_policy" {
  role = aws_iam_role.lambda_role.name
  policy_arn =  aws_iam_policy.lambda_bedrock_policy.arn
}

data "aws_iam_policy_document" "lambda_dynamodb_policy" {
  statement {
    effect = "Allow"
    actions = ["dynamodb:GetItem", "dynamodb:PutItem", "dynamodb:Query"]
    resources = [var.dynamo_arn]
  }
}

resource "aws_iam_policy" "lambda_dynamodb_policy" {
  name = "lambda-dynamodb-policy"
  policy = data.aws_iam_policy_document.lambda_dynamodb_policy.json
}

resource "aws_iam_role_policy_attachment" "lambda_dynamodb_policy" {
  role = aws_iam_role.lambda_role.name
  policy_arn = aws_iam_policy.lambda_dynamodb_policy.arn
}

resource "aws_iam_role_policy" "lambda_opensearch_policy" {
  name = "lambda-opensearch-serverless-access"
  role = aws_iam_role.lambda_role.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect   = "Allow"
      Action   = ["aoss:APIAccessAll"]
      Resource = [module.opensearch.opensearch_arn]
    }]
  })
}

// Creating the actual Lambda function now, or defining it
resource "aws_lambda_function" "web_scraper_lambda" {
  // Make sure we first finish Lambda_DockerFile_Update before making this, question more
  depends_on = [null_resource.Lambda_DockerFile_Update] 
  function_name = "scraper_lambda_function"
  role          = aws_iam_role.lambda_role.arn
  package_type  = "Image"
  image_uri     = "${aws_ecr_repository.resume_RAG_ecr_repo.repository_url}:latest"
  timeout       = 180
  memory_size   = 2048
  environment {
    variables = {
      OPENSEARCH_URL = module.opensearch.opensearch_url
      REGION_NAME = data.aws_region.curr_region.region
    }
  }
}

resource "aws_iam_role" "lambda_s3_upload_role" {
    name = "lambda_s3_upload_role"
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
    role = aws_iam_role.lambda_s3_upload_role.id
    policy = jsonencode({
        Version = "2012-10-17"
        Statement = [{
            Action = ["s3:PutObject"]
            Effect = "Allow"
            Resource = "${aws_s3_bucket.resume_bucket.arn}/*"
        }]
    })
}

resource "aws_iam_role_policy_attachment" "lambda_dynamodb_policy_upload" {
  role = aws_iam_role.lambda_s3_upload_role.name
  policy_arn = aws_iam_policy.lambda_dynamodb_policy.arn
}

data "archive_file" "lambda_s3_upload_file" {
    type = "zip"
    source_file = "${path.module}/upload_resume/s3_presigned_url.py"
    output_path = "${path.module}/upload_resume/s3_presigned_url.zip"
}

resource "aws_lambda_function" "lambda_s3_upload_function" {
    filename = data.archive_file.lambda_s3_upload_file.output_path
    function_name = "lambda_s3_upload_function"
    role = aws_iam_role.lambda_s3_upload_role.arn
    handler = "s3_presigned_url.handler"
    source_code_hash = data.archive_file.lambda_s3_upload_file.output_base64sha256
    runtime = "python3.9"
    environment {
      variables = {
        RESUME_BUCKET = aws_s3_bucket.resume_bucket.id,
        EXPIRATION_TIME = var.expiration_time,
        REGION_NAME = data.aws_region.curr_region.region
      }
    }
    tags = {}
}

# Choose_two_data_src.py
resource "aws_iam_role" "lambda_dynamo_role" {
  name = "lambda_dynamo_role"
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action    = "sts:AssumeRole"
      Effect    = "Allow"
      Principal = { Service = "lambda.amazonaws.com" }
    }]
  })
}

resource "aws_iam_role_policy_attachment" "lambda_dynamodb_policy" {
  role = aws_iam_role.lambda_dynamo_role.name
  policy_arn = aws_iam_policy.lambda_dynamodb_policy.arn
}

data "archive_file" "display_user_data" {
    type = "zip"
    source_file = "${path.module}/view_data/conversation_starter.py"
    output_path = "${path.module}/view_data/conversation_starter.zip"
}

resource "aws_lambda_function" "lambda_display_user_data" {
    filename = data.archive_file.display_user_data.output_path
    function_name = "lambda-display-user-data"
    role = aws_iam_role.lambda_dynamo_role.arn
    handler = "conversation_starter.handler"
    source_code_hash = data.archive_file.display_user_data.output_base64sha256
    runtime = "python3.9"
    environment {
      variables = {
        DYNAMO_DB_TABLE = var.dynamo_table
      }
    }
    tags = {}
}

resource "aws_iam_role" "lambda_bedrock_dynamo_role" {
  name = "lambda-bedrock-dynamo-role"
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action    = "sts:AssumeRole"
      Effect    = "Allow"
      Principal = { Service = "lambda.amazonaws.com" }
    }]
  })
}

data "aws_iam_policy_document" "invoke_agent_policy_doc" {
  statement {
    effect = "Allow"
    actions = ["bedrock:InvokeAgent"]
    resources = [var.bedrock_agent_arn]
  }
}

resource "aws_iam_policy" "invoke_agent_policy" {
  name = "invoke-agent-policy"
  policy = data.aws_iam_policy_document.invok_agent_policy.json
}

resource "aws_iam_role_policy_attachment" "bedrock_message_attachment" {
  role = aws_iam_role.lambda_bedrock_dynamo_role.name
  policy_arn =  aws_iam_policy.invoke_agent_policy.arn
}

resource "aws_iam_role_policy_attachment" "dynamodb_message_attachment" {
  role = aws_iam_role.lambda_bedrock_dynamo_role.name
  policy_arn = aws_iam_policy.lambda_dynamodb_policy.arn
}

data "archive_file" "message_bedrock_file" {
    type = "zip"
    source_file = "${path.module}/chat/message_bedrock.py"
    output_path = "${path.module}/chat/message_bedrock.zip"
}

resource "aws_lambda_function" "lambda_message_bedrock" {
    filename = data.archive_file.message_bedrock_file.output_path
    function_name = "lambda-message-bedrock"
    role = aws_iam_role.lambda_bedrock_dynamo_role
    handler = "message_bedrock.handler"
    source_code_hash = data.archive_file.message_bedrock_file.output_base64sha256
    runtime = "python3.9"
    environment {
      variables = {
        DYNAMO_DB_TABLE = var.dynamo_table
        KB_ID = var.kb_id
        AGENT_ID = var.agent_id
        REGION_NAME = var.bedrock_region
      }
    }
    tags = {}
}