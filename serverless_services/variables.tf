variable "parse_listing_role_ARN" {
  description = "Parsing listings Lambda Function's Role's ARN"
  type        = string
}

variable "parse_listing_ARN" {
  description = "Parsing listings Lambda Function ARN"
  type = string
}

variable "dynamo_username" {
  description = "Master username for DynamoDB table"
  sensitive = true
}

variable "dynamo_password" {
  description = "Master password for DynamoDB table"
  sensitive = true
}