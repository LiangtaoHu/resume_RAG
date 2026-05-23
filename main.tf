provider "aws" {
  region = "us-east-1"
}

resource "aws_iam_role" "iam_for_lambda" {
    name = "lambda-role"
    assume_role_policy = jsonencode({
        Version = "2012-10-17"
        Statement = [
            {
                Action = "sts:AssumeRole"
                Effect = "Allow"
                Principal = {
                    Service = "://amazonaws.com"
                }
            }
        ]
    })
}

data "archive_file" "lambda_zip" {
  type        = "zip"
  source_file = "lambda_scraper.py"
  output_path = "scraper_terraform_lambda_func.zip"
}

resource "aws_lambda_function" "test_scraper" {
  filename      = "scraper.zip"
  function_name = "scraper_terraform_lambda_func"
  role          = aws_iam_role.iam_for_lambda.arn
  handler       = "lambda_scraper.handler" # filename.function_name

  # The source_code_hash triggers a redeploy when your code changes
  source_code_hash = data.archive_file.lambda_zip.output_base64sha256

  runtime = "python3.9"

  environment {
    variables = {
        OPENAI_API_KEY = ""
    }
  }
}

// Create Vector Database and store in there by converting in lambda function