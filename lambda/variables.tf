variable "lambda_region" {
  description = "Region name for Lambda functions to upload resumes or parse job listings"
  type        = string
}

variable "bedrock_agent_arn" {
  description = "ARN of bedrock agent"
  type = string
}
variable "dynamo_arn" {
  description = "ARN of the DynamoDB table used to keep track of user data"
  type = string
}

variable "dynamo_table" {
  description = "Name of the DynamoDB table used to keep track of user data"
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

variable "opensearch_arn" {
  type = string
  description = "ARN of opensearch collection"
}

variable "opensearch_url" {
  type = string
  description = "URL of opensearch collection"
}