variable "dynamo_username" {
  description = "Master username for DynamoDB table"
  sensitive = true
}

variable "dynamo_password" {
  description = "Master password for DynamoDB table"
  sensitive = true
}