resource "aws_secretsmanager_secret" "dynamo_username" {
    name = "doc-db-username"
}

resource "aws_secretsmanager_secret_version" "dynamodb_username" {
    secret_id = aws_secretsmanager_secret.dynamodb_username
    secret_string = var.dynamo_username
}

resource "aws_secretsmanager_secret" "dynamodb_password" {
    name = "doc-db-password"
}

resource "aws_secretsmanager_secret_version" "dynamodb_password" {
    secret_id = aws_secretsmanager_secret.dynamodb_password
    secret_string = var.dynamo_password
}

/*
DynamoTable Attributes:
HK takes the form of USER#<ID>
SK takes the form of RESUME#<ID>, LINK, or CONV#<ID>
If we're doing USER & RESUME, the additional attributes are S3Location, CachedText
If we're doing USER & LINK, the additional attributes are url, fields, status, and expiresIn
If we're doing USER & CONV, the additional attributes are resumeID, ChatHistory

ChatHistory takes the form of a dictionary of messages
Messages have the following form:
    {
        "role": "User" OR "Agent"
        "message": "some_text"
        "timestamp": "some_time"
        "generated_file" (OPTIONAL ONLY IF AGENT MESSAGE): {
            "InternalID":
        }
    }
*/
resource "aws_dynamodb_table" "res_opt_dynamodb_table" {
    name = "res-optimizer-user-data"
    billing_mode = "PAY_PER_REQUEST"
    hash_key = "HK"
    range_key = "SK"

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
        enabled = true
    }

    point_in_time_recovery {
      enabled = true
    }
}

