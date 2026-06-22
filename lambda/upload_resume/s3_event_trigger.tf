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
            Action = ["dynamodb:GetItem", "dynamodb:UpdateItem"]
            Effect = "Allow"
            Resource = var.dynamo_db_arn
        }]
    })
}

resource "aws_iam_role_policy_attachment" "lambda_dynamodb_policy_upload" {
  role = aws_iam_role.lambda_s3_trigger_role.name
  policy_arn = aws_iam_policy.lambda_s3_trigger_policy.arn
}

data "archive_file" "alert_dynamo_trigger_file" {
    type = "zip"
    source_file = "s3_upload_trigger.py"
    output_path = "s3_upload_trigger.zip"
}

resource "aws_lambda_function" "alert_dynamo_trigger" {
  function_name    = "alert-dynamo-trigger"
  role             = aws_iam_role.lambda_s3_trigger_role
  handler          = "s3_upload_trigger.handler"
  filename         = data.archive_file.alert_dynamo_trigger_file.output_path
  runtime = "python3.9"
  source_code_hash = data.archive_file.alert_dynamo_trigger_file.output_base64sha256
  environment {
    variables = {
      REGION_NAME   = var.region_name
      DYNAMO_DB_NAME = var.dynamo_db_name
    }
  }
}

resource "aws_s3_bucket_notification" "aws_lambda_trigger" {
    bucket = var.resume_bucket
    lambda_function {
      lambda_function_arn = aws_lambda_function.alert_dynamo_trigger.arn
      events = ["s3:ObjectCreated:*"]
    }
}