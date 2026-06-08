// Still need to export AWS_ACCESS_KEY_ID, AWS_SECRET_ACCESS_KEY, and OpenAI key (Any way to do this properly?)
provider "aws" {
  region = "us-east-1"
}

module "opensearch" {
  source = "./conversation"
  bucket_name = aws_s3_bucket.resume_bucket.id
  lambda_role = aws_iam_role.lambda_role.arn
  alb_domain_name = var.alb_domain_name
  SNS_external_ID = var.SNS_external_ID
  upload_resume_ARN = aws_lambda_function.lambda_s3_upload_function.arn
  parse_listing_ARN = aws_lambda_function.lambda_s3_upload_function.arn
}