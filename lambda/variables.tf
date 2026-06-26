variable "lambda_region" {
  description = "Region name for Lambda functions to upload resumes or parse job listings"
  type        = string
}

variable "dynamo_arn" {
  description = "ARN of the DynamoDB table used to keep track of user data"
  type = string
}

variable "dynamo_table" {
  description = "Name of the DynamoDB table used to keep track of user data"
  type = string
}

variable "expiration_time" {
  description = "S3 presigned URL expiration time"
  type = number
}

variable "bedrock_agent_arn" {
  description = "ARN of bedrock agent"
  type = string
}

variable "kb_id" {
  description = "ID of knowledge base"
  type = string
}

variable "agent_id" {
  description = "ID of bedrock agent"
  type = string
}

variable "bedrock_region" {
  description = "Region name where bedrock agent was deployed."
  type = string
}