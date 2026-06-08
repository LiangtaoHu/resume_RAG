# variable "openai_api_key" {
#   type        = string
#   description = "OpenAI key, used for web scraping"
#   sensitive   = true
# }

variable "SNS_external_ID" {
    type = string
    description = "External ID for SNS messaging in Cognito"
    sensitive = true
}

variable "alb_domain_name" {
  description = "ALB Custom Domain Name"
  type        = string
}

variable "lambda_region" {
  description = "Region name for Lambda functions to upload resumes or parse job listings"
  type        = string
}