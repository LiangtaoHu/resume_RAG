variable "bucket_name" {
  description = "S3 bucket used to store resumes. Created in s3lambdas.tf"
  type        = string
}

variable "lambda_role" {
  description = "Lambda role for lambda function defined in main.tf"
  type        = string
}

variable "upload_resume_ARN" {
  description = "Lambda function ARN responsible for uploading resumes"
  type        = string
}

variable "parse_listing_ARN" {
  description = "Lambda function ARN responsible for parsing job listings"
  type        = string
}

variable "alb_domain_name" {
  description = "ALB Custom Domain Name"
  type        = string
}

variable "SNS_external_ID" {
    type = string
    description = "External ID for SNS messaging in Cognito"
    sensitive = true
}