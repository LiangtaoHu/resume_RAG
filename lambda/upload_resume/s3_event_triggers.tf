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

resource "aws_iam_role_policy" "lambda_s3_trigger_policy" {
    name = "lambda_s3_trigger_policy"
    role = aws_iam_role.lambda_s3_trigger_role.id
    policy = jsonencode({
        Version = "2012-10-17"
        Statement = [{
            Action = ["dynamodb:GetItem", "dynamodb:UpdateItem", "dynamodb:PutItem"]
            Effect = "Allow"
            Resource = var.dynamo_db_arn
        },
        {
          Action = ["s3:GetObject"]
          Effect = "Allow"
          Resource = "${var.resume_bucket_arn}/*"
        }]
    })
}

resource "aws_iam_role_policy_attachment" "lambda_dynamodb_policy_upload" {
  role = aws_iam_role.lambda_s3_trigger_role.name
  policy_arn = aws_iam_policy.lambda_s3_trigger_policy.arn
}

data "archive_file" "alert_dynamo_link_file" {
    type = "zip"
    source_file = "alert_dynamo_link.py"
    output_path = "alert_dynamo_link.zip"
}

resource "aws_lambda_function" "alert_dynamo_link_trigger" {
  function_name    = "alert-dynamo-link-trigger"
  role             = aws_iam_role.lambda_s3_trigger_role
  handler          = "alert_dynamo_link.handler"
  filename         = data.archive_file.alert_dynamo_link_file.output_path
  runtime = "python3.9"
  source_code_hash = data.archive_file.alert_dynamo_link_file.output_base64sha256
  environment {
    variables = {
      REGION_NAME   = var.region_name
      DYNAMO_DB_NAME = var.dynamo_db_name
    }
  }
}

resource "aws_s3_bucket_notification" "aws_alert_dynamo_link" {
    bucket = var.resume_bucket
    lambda_function {
      lambda_function_arn = aws_lambda_function.alert_dynamo_link_trigger.arn
      events = ["s3:ObjectCreated:*"]
    }
}

data "archive_file" "add_dynamo_resume_file" {
    type = "zip"
    source_file = "add_dynamo_resume.py"
    output_path = "add_dynamo_resume.zip"
}

resource "aws_lambda_function" "add_dynamo_resume_trigger" {
  function_name    = "add-dynamo-resume-trigger"
  role             = aws_iam_role.lambda_s3_trigger_role
  handler          = "add_dynamo_resume.handler"
  filename         = data.archive_file.add_dynamo_resume_file.output_path
  runtime = "python3.9"
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
      events = ["s3:ObjectCreated:*"]
    }
}