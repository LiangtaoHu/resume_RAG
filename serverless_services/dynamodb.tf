resource "aws_secretsmanager_secret" "dynamo_username" {
    name = "doc-db-username"
}

resource "aws_secretsmanager_secret_version" "dynamodb_username" {
    secret_id = aws_secretsmanager_secret.dynamodb_username
    secret_string = var.dynamodb_username
}

resource "aws_secretsmanager_secret" "dynamodb_password" {
    name = "doc-db-password"
}

resource "aws_secretsmanager_secret_version" "dynamodb_password" {
    secret_id = aws_secretsmanager_secret.dynamodb_password
    secret_string = var.dynamodb_password
}

resource "aws_dynamodb_table" "res_opt_dynamodb_table" {
    name = "user-info"
    billing_mode = "PAY_PER_REQUEST"
}
