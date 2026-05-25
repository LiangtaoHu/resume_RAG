// Still need to export AWS_ACCESS_KEY_ID, AWS_SECRET_ACCESS_KEY, and OpenAI key (Any way to do this properly?)
provider "aws" {
  region = "us-east-1"
}

/* 
  Stage One:
  - Creating the Lambda Function that serves to scrape webpages, get the necessary information, then have them embedded.
  - Since we're going to be using Langchain, Selenium, etc, a typical Lambda function won't have the proper size, so we'll
  need a docker file.
  - We'll store our DockerFile in AWS ECR.
*/

resource "aws_ecr_repository" "resume_RAG_ecr_repo" {
  name = "Resume RAG Images"
  image_scanning_configuration {
    scan_on_push = true
  }
}

// Null resource is for executing arbitrary functions but doesn't do anything more than execution every apply
// I say every apply because we have triggers that are checked every apply, 
// that means the DockerFile, the code, or the function's requirements have changed and must be pushed towards AWS
resource "null_resource" "Lambda_DockerFile_Update" {
  triggers = {
    code_hash = filemd5("${path.module}/lambda/lambda_scraper.py")
    requirements_hash = filemd5("${path.module}/lambda/requirements.txt")
    docker_hash = filemd5("${path.module}/lambda/Dockerfile")
  }

  provisioner "local-exec" {
    command = <<EOF
      # 1. Authenticate local Docker daemon with AWS ECR
      aws ecr get-login-password --region us-east-1 | docker login --username AWS --password-stdin ${aws_ecr_repository.resume_RAG_ecr_repo.repository_url}
      
      # 2. Build the Docker image locally using the Dockerfile blueprint
      docker build -t ${aws_ecr_repository.resume_RAG_ecr_repo.repository_url} -f ${path.module}/lambda/Dockerfile ${path.module}/lambda/
      
      # 3. Push the image up to your AWS ECR Registry
      docker push ${aws_ecr_repository.resume_RAG_ecr_repo.repository_url}
    EOF
  }
}

// We use AWS secret manager in order to save the OpenAI secret key so the lambda can call that instead of having it hard coded. 
resource "aws_secretsmanager_secret" "openai_secret" {
  name        = "lambda-openai-api-key"
  description = "OpenAI API Key for the Python scraper Lambda"
}

// Provide a value to the secret
resource "aws_secretsmanager_secret_version" "openai_secret_val" {
  secret_id     = aws_secretsmanager_secret.openai_secret.id
  secret_string = jsonencode({
    OPENAI_API_KEY = var.openai_api_key
  })
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

// Define policy document that allows the lambda function to only access the OpenAI secret key
data "aws_iam_policy_document" "lambda_secrets_policy" {
  statement {
    effect = "Allow"
    actions = ["secretsmanager:GetSecretValue"]
    resources = [aws_secretsmanager_secret.openai_secret.arn]
  }
}

// Create IAM policy with that policy document
resource "aws_iam_policy" "lambda_secrets_policy" {
  name = "lambda-secrets-manager-read"
  policy = data.aws_iam_policy_document.lambda_secrets_policy.json
}

// Attaches it to the role
resource "aws_iam_role_policy_attachment" "lambda_secretmanager_read" {
  role = aws_iam_role.lambda_role.arn
  policy_arn = aws_iam_policy.lambda_secrets_policy.name
}

resource "aws_iam_policy_document" "lambda_bedrock_policy" {
  statement {
    effect = "Allow"
    actions = ["bedrock:InvokeModel"]
    resources = ["arn:aws:bedrock:us-east-1::foundation-model/amazon.titan-embed-text-v2:0"]
  }
}

resource "aws_iam_policy" "lambda_bedrock_policy" {
  name = "lambda-bedrock-model-access"
  policy = aws_iam_policy_document.lambda_bedrock_policy.json
}

resource "aws_iam_role_policy_attachment" "lambda_bedrock_policy" {
  role = aws_iam_role.lambda_role.arn
  policy_arn =  aws_iam_policy.lambda_bedrock_policy.name
}

// Creating the actual Lambda function now, or defining it
resource "aws_lambda_function" "web_scraper_lambda" {
  // Make sure we first finish Lambda_DockerFile_Update before making this, question more
  depends_on = [null_resource.Lambda_DockerFile_Update] 
  function_name = "scraper_lambda_function"
  role          = aws_iam_role.iam_for_lambda.arn
  package_type  = "Image"
  image_uri     = "${aws_ecr_repository.lambda_repo.repository_url}:latest"
  timeout       = 180
  memory_size   = 2048
  environment {
    variables = {
      SECRETS_MANAGER_NAME = aws_secretsmanager_secret.openai_secret.name
      OPENSEARCH_URL       = aws_opensearchserverless_collection.vector_db.collection_endpoint
    }
  }
}

// OpenSearch Serverless Collection as Vector Database
resource "aws_opensearchserverless_collection" "vector_db" {
  name             = "resume-rag-database"
  type             = "VECTORSEARCH" # Crucial: Allocates specific vector indexing infrastructure
  description      = "Vector store for job listing contexts and resumes"
}

// OpenSearch Security Encryption Policy
resource "aws_opensearchserverless_security_policy" "encryption" {
  name        = "rag-encryption-policy"
  type        = "encryption"
  description = "Encryption policy for vector search collection"
  
  # AWS manages encryption using their default keys
  policy = jsonencode({
    Rules = [{
      ResourceType = "collection"
      Resource     = ["collection/resume-rag-database"]
    }]
    AWSOwnedKey = true
  })
}

// OpenSearch Network Access Policy (Public endpoint configuration)
resource "aws_opensearchserverless_security_policy" "network" {
  name        = "rag-network-policy"
  type        = "network"
  description = "Public access policy for vector collection endpoints"
  
  policy = jsonencode([{
    Component    = "collection"
    ResourceType = "collection"
    Resource     = ["collection/resume-rag-db"]
  }, {
    Component    = "dashboard"
    ResourceType = "dashboard"
    Resource     = ["collection/resume-rag-db"]
  }])
}

// Data Access Policy: Grant permissions to your Lambda function's IAM Role
resource "aws_opensearchserverless_access_policy" "data_access" {
  name        = "rag-data-access-policy"
  type        = "data"
  description = "Grants read/write permissions to Lambda execution role"
  
  policy = jsonencode([{
    Rules = [{
      ResourceType = "index"
      Resource     = ["index/resume-rag-db/*"]
      Permission   = [
        "aoss:CreateIndex",
        "aoss:DescribeIndex",
        "aoss:ReadDocument",
        "aoss:WriteDocument"
      ]
    }, {
      ResourceType = "collection"
      Resource     = ["collection/resume-rag-db"]
      Permission   = [
        "aoss:CreateCollectionItems",
        "aoss:UpdateCollectionItems",
        "aoss:DescribeCollectionItems"
      ]
    }]
    Principal = [aws_iam_role.lambda_role.arn]
  }])
}

// Grant your Lambda base IAM role structural network connectivity rights
resource "aws_iam_role_policy" "lambda_opensearch_policy" {
  name = "lambda-opensearch-serverless-access"
  role = aws_iam_role.iam_for_lambda.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect   = "Allow"
      Action   = ["aoss:APIAccessAll"]
      Resource = [aws_opensearchserverless_collection.vector_db.arn]
    }]
  })
}