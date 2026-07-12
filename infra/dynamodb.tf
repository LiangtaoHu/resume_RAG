// Single-table DynamoDB layout for all user data.
//
// DynamoTable Attributes:
//   HK = "USER#<sub>"
//   SK = "RESUME#<file>" | "LINK" | "JOB#<company>-<position>" | "CONV#<id>"
//   RESUME# row extras: S3Location, cachedText
//   LINK    row extras: url, fields, status, expiresIn
//   CONV#   row extras: resumeID, ChatHistory
//   JOB#    row extras: company, position, url, status, adzunaId?, deletedAt?
//
// ChatHistory is a dict of {role, message, timestamp, generated_file?}.

resource "aws_secretsmanager_secret" "dynamo_username" {
  name = "doc-db-username"
}

resource "aws_secretsmanager_secret_version" "dynamodb_username" {
  secret_id     = aws_secretsmanager_secret.dynamo_username.id
  secret_string = var.dynamo_username
}

resource "aws_secretsmanager_secret" "dynamodb_password" {
  name = "doc-db-password"
}

resource "aws_secretsmanager_secret_version" "dynamodb_password" {
  secret_id     = aws_secretsmanager_secret.dynamodb_password.id
  secret_string = var.dynamo_password
}

resource "aws_dynamodb_table" "res_opt_dynamodb_table" {
  name         = "res-optimizer-user-data"
  billing_mode = "PAY_PER_REQUEST"
  hash_key     = "HK"
  range_key    = "SK"

  attribute {
    name = "HK"
    type = "S"
  }

  attribute {
    name = "SK"
    type = "S"
  }

  ttl {
    attribute_name = "expiresIn"
    enabled        = true
  }

  point_in_time_recovery {
    enabled = true
  }
}