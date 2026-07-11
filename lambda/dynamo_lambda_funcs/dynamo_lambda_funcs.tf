// DynamoDB section
data "aws_iam_policy_document" "lambda_dynamodb_policy" {
  statement {
    effect = "Allow"
    actions = ["dynamodb:GetItem", "dynamodb:PutItem", "dynamodb:Query"]
    resources = [var.dynamo_arn]
  }
}

resource "aws_iam_policy" "lambda_dynamodb_policy" {
  name = "lambda-dynamodb-policy"
  policy = data.aws_iam_policy_document.lambda_dynamodb_policy.json
}

resource "aws_iam_role_policy_attachment" "lambda_dynamodb_policy_one" {
  role = aws_iam_role.lambda_role.name
  policy_arn = aws_iam_policy.lambda_dynamodb_policy.arn
}

# Choose_two_data_src.py
resource "aws_iam_role" "lambda_dynamo_role" {
  name = "lambda_dynamo_role"
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action    = "sts:AssumeRole"
      Effect    = "Allow"
      Principal = { Service = "lambda.amazonaws.com" }
    }]
  })
}

resource "aws_iam_role_policy_attachment" "lambda_dynamodb_policy_two" {
  role = aws_iam_role.lambda_dynamo_role.name
  policy_arn = aws_iam_policy.lambda_dynamodb_policy.arn
}

data "archive_file" "display_user_data" {
    type = "zip"
    source_file = "${path.module}/../view_data/conversation_starter.py"
    output_path = "${path.module}/../view_data/conversation_starter.zip"
}

resource "aws_lambda_function" "lambda_display_user_data" {
    filename = data.archive_file.display_user_data.output_path
    function_name = "lambda-display-user-data"
    role = aws_iam_role.lambda_dynamo_role.arn
    handler = "conversation_starter.handler"
    source_code_hash = data.archive_file.display_user_data.output_base64sha256
    runtime = "python3.9"
    environment {
      variables = {
        DYNAMO_DB_TABLE = var.dynamo_table
      }
    }
    tags = {}
}
// End of dynamoDB section