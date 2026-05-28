resource "aws_s3_bucket" "resume_bucket" {
    bucket = "liangtaohu-resume-bucket"
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
    policy = jsondecode({
        Version = "2012-10-17"
        Statement = [{
            Action = [ "s3:PutObject"]
            Effect = "Allow"
            Resource = aws_s3_bucket.resume_bucket.arn
        }]
    })
}

data "archive_file" "lambda_s3_upload_file" {
    type = "zip"
    source_file = "${path.module}/lambda/s3_upload.py"
    output_path = "${path.module}/lambda/lambda_s3_upload.zip"
}

resource "aws_lambda_function" "lambda_s3_upload_function" {
    filename = data.archive_file.lambda_s3_upload_file.output_path
    function_name = "lambda_s3_upload_function"
    role = aws_iam_role.lambda_s3_upload_role.arn
    handler = "s3_upload.lambda_handler"
    code_sha256 = data.archive_file.lambda_s3_upload_file.output_base64sha256
    runtime = "python3.9"
    environment {
      variables = {
        RESUME_BUCKET_NAME = aws_s3_bucket.resume_bucket.id
      }
    }
    tags = {}
}
