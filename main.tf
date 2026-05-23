provider "aws" {
  region = "us-east-1"
}

# 1. AWS ECR - The Docker Registry where your image will be stored
resource "aws_ecr_repository" "lambda_repo" {
  name                 = "scraper-lambda-container"
  image_tag_mutability = "MUTABLE"

  # Cleans up old container images automatically to avoid extra storage costs
  image_scanning_configuration {
    scan_on_push = true
  }
}

# 2. Automate Docker Build & Push directly from your local machine
resource "null_resource" "docker_push" {
  triggers = {
    # Re-build and re-push ONLY if your code, requirements, or Dockerfile changes
    code_hash       = filemd5("${path.module}/lambda_scraper.py")
    requirements    = filemd5("${path.module}/requirements.txt")
    docker_hash     = filemd5("${path.module}/Dockerfile")
  }

  provisioner "local-exec" {
    command = <<EOF
      # 1. Authenticate your local Docker daemon with AWS ECR
      aws ecr get-login-password --region us-east-1 | docker login --username AWS --password-stdin ${aws_ecr_repository.lambda_repo.repository_url}
      
      # 2. Build the Docker image locally using the Dockerfile blueprint
      docker build -t ${aws_ecr_repository.lambda_repo.repository_url}:latest .
      
      # 3. Push the image up to your AWS ECR Registry
      docker push ${aws_ecr_repository.lambda_repo.repository_url}:latest
    EOF
  }
}

# 3. Variable definition for your OpenAI Key
variable "openai_api_key" {
  type        = string
  description = "The secret API key for OpenAI"
  sensitive   = true # Mask this value from showing up plain-text in your CLI logs
}

# 4. AWS Secrets Manager - Storing the Key
resource "aws_secretsmanager_secret" "openai_secret" {
  name        = "lambda-openai-api-key"
  description = "OpenAI API Key for the Python scraper Lambda"
}

resource "aws_secretsmanager_secret_version" "openai_secret_val" {
  secret_id     = aws_secretsmanager_secret.openai_secret.id
  secret_string = jsonencode({
    OPENAI_API_KEY = var.openai_api_key
  })
}

# 5. IAM Lambda Role & Permissions
resource "aws_iam_role" "iam_for_lambda" {
  name = "lambda-role"
  
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action    = "sts:AssumeRole"
      Effect    = "Allow"
      Principal = { Service = "://amazonaws.com" }
    }]
  })
}

# Grants your Lambda permission to write errors/logs to CloudWatch
resource "aws_iam_role_policy_attachment" "lambda_logs" {
  role       = aws_iam_role.iam_for_lambda.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
}

# Grants your Lambda permission to read ONLY your OpenAI key from Secrets Manager
resource "aws_iam_role_policy" "lambda_secrets_policy" {
  name = "lambda-secrets-manager-read"
  role = aws_iam_role.iam_for_lambda.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect   = "Allow"
      Action   = ["secretsmanager:GetSecretValue"]
      Resource = [aws_secretsmanager_secret.openai_secret.arn]
    }]
  })
}

# 6. AWS Lambda Function Configuration (Container Image Mode)
resource "aws_lambda_function" "test_scraper" {
  function_name = "scraper_lambda_function"
  role          = aws_iam_role.iam_for_lambda.arn
  
  # Tells Lambda to look for a container image rather than a ZIP folder
  package_type  = "Image"
  image_uri     = "${aws_ecr_repository.lambda_repo.repository_url}:latest"

  # Upgraded settings for Chrome rendering performance
  timeout       = 180  # 3 minutes maximum runtime limit
  memory_size   = 2048 # 2 GB allocated RAM minimum to run headless browser smoothly

  environment {
    variables = {
      # Pass the target secret name so boto3 knows where to read the API Key
      SECRETS_MANAGER_NAME = aws_secretsmanager_secret.openai_secret.name
    }
  }

  # Forces Terraform to finish building and pushing the Docker image BEFORE attempting to build the Lambda
  depends_on = [null_resource.docker_push]
}