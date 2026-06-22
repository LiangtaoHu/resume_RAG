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
us-east-1 DynamoDB table that keeps track of the listings the user has parsed as well as the active S3 links so far
*/
resource "aws_dynamodb_table" "res_opt_dynamodb_table" {
    name = "res-optimizer-user-data"
    billing_mode = "PAY_PER_REQUEST"
    hash_key = "HK"
    range_key = "SK"
    /*
    {
        HK: User-1
        SK: JOB#xxxx
        Company: xxxx
        Position: xxxx
    }
    OR
    {
        HK: User-1
        SK: LINK
        url: xxxx
        expiresIn:
    }
    */
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

