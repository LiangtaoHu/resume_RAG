variable "SNS_external_ID" {
    type = string
    description = "External ID for SNS messaging in Cognito"
    sensitive = true
}

variable "lambda_region" {
  description = "Region name for Lambda functions to upload resumes or parse job listings"
  type        = string
}