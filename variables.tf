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