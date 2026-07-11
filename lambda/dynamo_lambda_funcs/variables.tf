variable "dynamo_arn" {
  description = "ARN of the DynamoDB table used to keep track of user data"
  type = string
}

variable "dynamo_table" {
  description = "Name of the DynamoDB table used to keep track of user data"
  type = string
}