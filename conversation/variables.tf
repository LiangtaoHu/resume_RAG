variable "bucket_name" {
  description = "S3 bucket used to store resumes. Created in s3lambdas.tf"
  type        = string
}

variable "lambda_role" {
  description = "Lambda role for lambda function defined in main.tf"
  type        = string
}