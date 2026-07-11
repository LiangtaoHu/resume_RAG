output "dynamo_table" {
    type = string
    description = "Name of DynamoDB table"
    value = aws_dynamodb_table.res_opt_dynamodb_table.id
}

output "dynamo_arn" {
    type = string
    description = "ARN of DynamoDB table"
    value = aws_dynamodb_table.res_opt_dynamodb_table.arn
}