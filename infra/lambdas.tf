// All Lambda functions and their IAM roles/policies.
//
// Python sources live in ../lambda/ and are NOT moved into infra/. archive_file
// `source_file` paths point there via ${path.module}/../lambda/.
// The previously-broken `module.opensearch.*` references (no module was ever
// declared) are inlined here as `aws_opensearchserverless_collection.vector_db.*`.
//
// `data "aws_region" "curr_region"` is declared in bedrock.tf.

/* ========================================================================== */
/* Lambda@Edge: parse_auth (viewer-request on /callback)                      */
/* ========================================================================== */

data "aws_iam_policy_document" "lambda_at_edge_policy" {
  statement {
    actions = ["sts:AssumeRole"]
    principals {
      type        = "Service"
      identifiers = ["lambda.amazonaws.com", "edgelambda.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "lambda_at_edge_role" {
  name                 = "lambda-at-edge-role"
  assume_role_policy   = data.aws_iam_policy_document.lambda_at_edge_policy.json
}

data "archive_file" "parse_auth_file" {
  type        = "zip"
  source_file = "${path.module}/../lambda/authorization/parse_auth.py"
  output_path = "${path.module}/../lambda/authorization/parse_auth.zip"
}

resource "aws_lambda_function" "parse_auth" {
  filename         = data.archive_file.parse_auth_file.output_path
  function_name    = "parse-auth-at-edge"
  role             = aws_iam_role.lambda_at_edge_role.arn
  handler          = "parse_auth.lambda_handler"
  code_sha256      = data.archive_file.parse_auth_file.output_base64sha256

  provider = aws.us_east_1
  publish  = true
}

/* ========================================================================== */
/* Web scraper (Docker container Lambda — Selenium)                           */
/* ========================================================================== */

resource "aws_ecr_repository" "resume_RAG_ecr_repo" {
  name = "resume-rag-images"
  image_scanning_configuration {
    scan_on_push = true
  }
}

resource "null_resource" "Lambda_DockerFile_Update" {
  triggers = {
    code_hash        = filemd5("${path.module}/../lambda/parse_listing/lambda_scraper.py")
    requirements_hash = filemd5("${path.module}/../lambda/parse_listing/requirements.txt")
    docker_hash      = filemd5("${path.module}/../lambda/parse_listing/Dockerfile")
  }

  provisioner "local-exec" {
    command = <<EOF
      aws ecr get-login-password --region us-east-1 | docker login --username AWS --password-stdin ${aws_ecr_repository.resume_RAG_ecr_repo.repository_url}
      docker build -t ${aws_ecr_repository.resume_RAG_ecr_repo.repository_url}:latest -f ${path.module}/../lambda/parse_listing/Dockerfile ${path.module}/../lambda/parse_listing/
      docker push ${aws_ecr_repository.resume_RAG_ecr_repo.repository_url}:latest
    EOF
  }
}

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

resource "aws_iam_role_policy_attachment" "lambda_logs" {
  role       = aws_iam_role.lambda_role.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
}

data "aws_iam_policy_document" "lambda_bedrock_policy" {
  statement {
    effect    = "Allow"
    actions   = ["bedrock:InvokeModel"]
    resources = ["arn:aws:bedrock:us-east-1::foundation-model/amazon.titan-embed-text-v2:0"]
  }
}

resource "aws_iam_policy" "lambda_bedrock_policy" {
  name   = "lambda-bedrock-model-access"
  policy = data.aws_iam_policy_document.lambda_bedrock_policy.json
}

resource "aws_iam_role_policy_attachment" "lambda_bedrock_policy" {
  role       = aws_iam_role.lambda_role.name
  policy_arn = aws_iam_policy.lambda_bedrock_policy.arn
}

data "aws_iam_policy_document" "lambda_dynamodb_policy" {
  statement {
    effect = "Allow"
    actions = [
      "dynamodb:GetItem",
      "dynamodb:PutItem",
      "dynamodb:UpdateItem",
      "dynamodb:Query"
    ]
    resources = [var.dynamo_arn]
  }
}

resource "aws_iam_policy" "lambda_dynamodb_policy" {
  name   = "lambda-dynamodb-policy"
  policy = data.aws_iam_policy_document.lambda_dynamodb_policy.json
}

resource "aws_iam_role_policy_attachment" "lambda_dynamodb_policy" {
  role       = aws_iam_role.lambda_role.name
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
      Resource = [aws_opensearchserverless_collection.vector_db.arn]
    }]
  })
}

resource "aws_lambda_function" "web_scraper_lambda" {
  depends_on   = [null_resource.Lambda_DockerFile_Update]
  function_name = "scraper_lambda_function"
  role          = aws_iam_role.lambda_role.arn
  package_type  = "Image"
  image_uri     = "${aws_ecr_repository.resume_RAG_ecr_repo.repository_url}:latest"
  timeout       = 180
  memory_size   = 2048
  environment {
    variables = {
      OPENSEARCH_URL = aws_opensearchserverless_collection.vector_db.collection_endpoint
      REGION_NAME    = data.aws_region.curr_region.region
    }
  }
}

/* ========================================================================== */
/* Resume upload Lambda (s3_presigned_url.handler)                            */
/* ========================================================================== */

resource "aws_iam_role" "lambda_s3_upload_role" {
  name = "lambda_s3_upload_role"
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Action    = "sts:AssumeRole"
      Principal = { Service = "lambda.amazonaws.com" }
    }]
  })
}

resource "aws_iam_role_policy" "lambda_s3_upload_policy" {
  name = "lambda_s3_upload_policy"
  role = aws_iam_role.lambda_s3_upload_role.id
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action   = ["s3:PutObject"]
      Effect   = "Allow"
      Resource = "${var.resume_bucket_arn}/*"
    }]
  })
}

resource "aws_iam_role_policy_attachment" "lambda_dynamodb_policy_upload" {
  role       = aws_iam_role.lambda_s3_upload_role.name
  policy_arn = aws_iam_policy.lambda_dynamodb_policy.arn
}

data "archive_file" "lambda_s3_upload_file" {
  type        = "zip"
  source_file = "${path.module}/../lambda/upload_resume/s3_presigned_url.py"
  output_path = "${path.module}/../lambda/upload_resume/s3_presigned_url.zip"
}

resource "aws_lambda_function" "lambda_s3_upload_function" {
  filename         = data.archive_file.lambda_s3_upload_file.output_path
  function_name    = "lambda_s3_upload_function"
  role             = aws_iam_role.lambda_s3_upload_role.arn
  handler          = "s3_presigned_url.handler"
  source_code_hash = data.archive_file.lambda_s3_upload_file.output_base64sha256
  runtime          = "python3.9"
  environment {
    variables = {
      RESUME_BUCKET   = var.resume_bucket
      EXPIRATION_TIME = var.expiration_time
      REGION_NAME     = data.aws_region.curr_region.region
    }
  }
}

/* ========================================================================== */
/* View-user-data Lambda (conversation_starter.handler)                       */
/* ========================================================================== */

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

resource "aws_iam_role_policy_attachment" "lambda_dynamo_role_dynamodb" {
  role       = aws_iam_role.lambda_dynamo_role.name
  policy_arn = aws_iam_policy.lambda_dynamodb_policy.arn
}

data "archive_file" "display_user_data" {
  type        = "zip"
  source_file = "${path.module}/../lambda/view_data/conversation_starter.py"
  output_path = "${path.module}/../lambda/view_data/conversation_starter.zip"
}

resource "aws_lambda_function" "lambda_display_user_data" {
  filename         = data.archive_file.display_user_data.output_path
  function_name    = "lambda-display-user-data"
  role             = aws_iam_role.lambda_dynamo_role.arn
  handler          = "conversation_starter.handler"
  source_code_hash = data.archive_file.display_user_data.output_base64sha256
  runtime          = "python3.9"
  environment {
    variables = {
      DYNAMO_DB_TABLE = var.dynamo_table
    }
  }
}

/* ========================================================================== */
/* Chat / Bedrock message Lambda (message_bedrock.handler)                     */
/* ========================================================================== */

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
    effect    = "Allow"
    actions   = ["bedrock:InvokeAgent"]
    resources = [var.bedrock_agent_arn]
  }
}

resource "aws_iam_policy" "invoke_agent_policy" {
  name   = "invoke-agent-policy"
  policy = data.aws_iam_policy_document.invoke_agent_policy_doc.json
}

resource "aws_iam_role_policy_attachment" "bedrock_message_attachment" {
  role       = aws_iam_role.lambda_bedrock_dynamo_role.name
  policy_arn = aws_iam_policy.invoke_agent_policy.arn
}

resource "aws_iam_role_policy_attachment" "dynamodb_message_attachment" {
  role       = aws_iam_role.lambda_bedrock_dynamo_role.name
  policy_arn = aws_iam_policy.lambda_dynamodb_policy.arn
}

data "archive_file" "message_bedrock_file" {
  type        = "zip"
  source_file = "${path.module}/../lambda/chat/message_bedrock.py"
  output_path = "${path.module}/../lambda/chat/message_bedrock.zip"
}

resource "aws_lambda_function" "lambda_message_bedrock" {
  filename         = data.archive_file.message_bedrock_file.output_path
  function_name    = "lambda-message-bedrock"
  role             = aws_iam_role.lambda_bedrock_dynamo_role.arn
  handler          = "message_bedrock.handler"
  source_code_hash = data.archive_file.message_bedrock_file.output_base64sha256
  runtime          = "python3.9"
  environment {
    variables = {
      DYNAMO_DB_TABLE = var.dynamo_table
      KB_ID           = var.kb_id
      AGENT_ID        = var.agent_id
      REGION_NAME     = var.bedrock_region
    }
  }
}

/* ========================================================================== */
/* search_jobs Lambda (Adzuna proxy)                                          */
/* ========================================================================== */

data "archive_file" "search_jobs_file" {
  type        = "zip"
  source_file = "${path.module}/../lambda/search_jobs/search_jobs.py"
  output_path = "${path.module}/../lambda/search_jobs/search_jobs.zip"
}

resource "aws_lambda_function" "search_jobs" {
  filename         = data.archive_file.search_jobs_file.output_path
  function_name    = "lambda-search-jobs"
  role             = aws_iam_role.lambda_role.arn
  handler          = "search_jobs.handler"
  source_code_hash = data.archive_file.search_jobs_file.output_base64sha256
  runtime          = "python3.9"
  timeout          = 30
  memory_size      = 256
  environment {
    variables = {
      ADZUNA_APP_ID          = var.adzuna_app_id
      ADZUNA_APP_KEY         = var.adzuna_app_key
      ADZUNA_DEFAULT_COUNTRY = var.adzuna_default_country
      REGION_NAME            = data.aws_region.curr_region.region
    }
  }
}

/* ========================================================================== */
/* job_crud Lambda (add_job.handler + delete_job.handler; one zip)           */
/* ========================================================================== */

data "archive_file" "job_crud_file" {
  type        = "zip"
  source_dir  = "${path.module}/../lambda/job_crud"
  output_path = "${path.module}/../lambda/job_crud/job_crud.zip"
  excludes    = ["*.tf", "*.zip"]
}

resource "aws_lambda_function" "job_crud_add" {
  filename         = data.archive_file.job_crud_file.output_path
  function_name    = "lambda-job-crud-add"
  role             = aws_iam_role.lambda_role.arn
  handler          = "add_job.handler"
  source_code_hash = data.archive_file.job_crud_file.output_base64sha256
  runtime          = "python3.9"
  timeout          = 15
  memory_size      = 256
  environment {
    variables = {
      DYNAMO_DB_TABLE = var.dynamo_table
    }
  }
}

resource "aws_lambda_function" "job_crud_delete" {
  filename         = data.archive_file.job_crud_file.output_path
  function_name    = "lambda-job-crud-delete"
  role             = aws_iam_role.lambda_role.arn
  handler          = "delete_job.handler"
  source_code_hash = data.archive_file.job_crud_file.output_base64sha256
  runtime          = "python3.9"
  timeout          = 15
  memory_size      = 256
  environment {
    variables = {
      DYNAMO_DB_TABLE = var.dynamo_table
    }
  }
}

/* ========================================================================== */
/* S3-event-trigger Lambdas (alert_dynamo_link, add_dynamo_resume)            */
/* ========================================================================== */

resource "aws_iam_role" "lambda_s3_trigger_role" {
  name = "lambda-s3-trigger-role"
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Action    = "sts:AssumeRole"
      Principal = { Service = "lambda.amazonaws.com" }
    }]
  })
}

resource "aws_iam_role_policy" "lambda_s3_trigger_policy" {
  name = "lambda_s3_trigger_policy"
  role = aws_iam_role.lambda_s3_trigger_role.id
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action   = ["dynamodb:GetItem", "dynamodb:UpdateItem", "dynamodb:PutItem"]
      Effect   = "Allow"
      Resource = var.dynamo_db_arn
      },
      {
        Action   = ["s3:GetObject"]
        Effect   = "Allow"
        Resource = "${var.resume_bucket_arn}/*"
      }
    ]
  })
}

data "archive_file" "alert_dynamo_link_file" {
  type        = "zip"
  source_file = "${path.module}/../lambda/upload_resume/alert_dynamo_link.py"
  output_path = "${path.module}/../lambda/upload_resume/alert_dynamo_link.zip"
}

resource "aws_lambda_function" "alert_dynamo_link_trigger" {
  function_name    = "alert-dynamo-link-trigger"
  role             = aws_iam_role.lambda_s3_trigger_role.arn
  handler          = "alert_dynamo_link.handler"
  filename         = data.archive_file.alert_dynamo_link_file.output_path
  runtime          = "python3.9"
  source_code_hash = data.archive_file.alert_dynamo_link_file.output_base64sha256
  environment {
    variables = {
      REGION_NAME    = var.region_name
      DYNAMO_DB_NAME = var.dynamo_db_name
    }
  }
}

resource "aws_s3_bucket_notification" "aws_alert_dynamo_link" {
  bucket = var.resume_bucket
  lambda_function {
    lambda_function_arn = aws_lambda_function.alert_dynamo_link_trigger.arn
    events              = ["s3:ObjectCreated:*"]
  }
}

data "archive_file" "add_dynamo_resume_file" {
  type        = "zip"
  source_file = "${path.module}/../lambda/upload_resume/add_dynamo_resume.py"
  output_path = "${path.module}/../lambda/upload_resume/add_dynamo_resume.zip"
}

resource "aws_lambda_function" "add_dynamo_resume_trigger" {
  function_name    = "add-dynamo-resume-trigger"
  role             = aws_iam_role.lambda_s3_trigger_role.arn
  handler          = "add_dynamo_resume.handler"
  filename         = data.archive_file.add_dynamo_resume_file.output_path
  runtime          = "python3.9"
  source_code_hash = data.archive_file.add_dynamo_resume_file.output_base64sha256
  environment {
    variables = {
      DYNAMO_DB_NAME = var.dynamo_db_name
    }
  }
}

resource "aws_s3_bucket_notification" "aws_add_dynamo_resume" {
  bucket = var.resume_bucket
  lambda_function {
    lambda_function_arn = aws_lambda_function.add_dynamo_resume_trigger.arn
    events              = ["s3:ObjectCreated:*"]
  }
}