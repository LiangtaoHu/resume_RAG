variable "lambda_region" {
  description = "Region name for Lambda functions to upload resumes or parse job listings"
  type        = string
}

variable "dynamo_arn" {
  description = "ARN of the DynamoDB table used to keep track of user data"
  type = string
}

variable "expiration_time" {
  description = "S3 presigned URL expiration time"
  type = number
}