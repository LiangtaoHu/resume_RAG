data "aws_iam_policy_document" "lambda_at_edge_policy" {
    statement {
        actions = ["sts:AssumeRole"]
        principals {
          type = "Service"
          identifiers = ["lambda.amazonaws.com", "edgelambda.amazonaws.com"]
        }
    }
}

resource "aws_iam_role" "lambda_at_edge_role" {
    name = "lambda-at-edge-role"
    assume_role_policy = data.aws_iam_policy_document.lambda_at_edge_policy.json
}

data "archive_file" "check_auth_file" {
    type = "zip"
    source_file = "${path.module}/authorization/check_auth.py"
    output_path = "${path.module}/authorization/check_auth.zip"
}

resource "aws_lambda_function" "check_auth" {
    filename = data.archive_file.check_auth_file.output_path
    function_name = "check-auth-at-edge"
    role = aws_iam_role.lambda_at_edge_role
    handler = check_auth.lambda_handler
    code_sha256 = data.archive_file.check_auth_file.output_base64sha256

    provider = aws.us_east_1
    publish = true
}

data "archive_file" "parse_auth_file" {
    type = "zip"
    source_file = "${path.module}/authorization/parse_auth.py"
    output_path = "${path.module}/authorization/parse_auth.zip"
}

resource "aws_lambda_function" "parse_auth" {
    filename = data.archive_file.parse_auth_file.output_path
    function_name = "parse-auth-at-edge"
    role = aws_iam_role.lambda_at_edge_role
    handler = parse_auth.lambda_handler
    code_sha256 = data.archive_file.parse_auth_file.output_base64sha256

    provider = aws.us_east_1
    publish = true
}