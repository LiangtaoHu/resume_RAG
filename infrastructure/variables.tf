variable "dynamo_username" {
    type = string
    description = "Username for DynamoDB Table"
}

variable "dynamo_password" {
    type = string
    description = "Password for DynamoDB Table"
}

variable "expiration_time" {
    type = number
    description = "Total time for an S3 Presigned URL to be valid"
}

variable "SNS_external_ID" {
    type = string
}

variable "agent_alias_id" {
    type = string
}