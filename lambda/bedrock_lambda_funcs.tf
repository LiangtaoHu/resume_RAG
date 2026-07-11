data "aws_region" "curr_region" {}

/*
Problems emerge here with module.opensearch.opensearch_arn
*/
resource "aws_iam_role_policy" "lambda_opensearch_policy" {
  name = "lambda-opensearch-serverless-access"
  role = aws_iam_role.lambda_role.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect   = "Allow"
      Action   = ["aoss:APIAccessAll"]
      Resource = [var.opensearch_arn]
    }]
  })
}


// Creating the actual Lambda function now, or defining it
resource "aws_lambda_function" "web_scraper_lambda" {
  // Make sure we first finish Lambda_DockerFile_Update before making this, question more
  depends_on = [null_resource.Lambda_DockerFile_Update] 
  function_name = "scraper_lambda_function"
  role          = aws_iam_role.lambda_role.arn
  package_type  = "Image"
  image_uri     = "${aws_ecr_repository.resume_RAG_ecr_repo.repository_url}:latest"
  timeout       = 180
  memory_size   = 2048
  environment {
    variables = {
      OPENSEARCH_URL = var.opensearch_url
      REGION_NAME = data.aws_region.curr_region.region
    }
  }
}
/*
Problems end here
*/

/*
Bedrock section
*/
resource "aws_iam_role" "lambda_bedrock_dynamo_role" {
  name = "lambda-bedrock-dynamo-role"
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action    = "sts:AssumeRole"
      Effect    = "Allow"
      Principal = { Service = "lambda.amazonaws.com" }
    }]
  })
}

data "aws_iam_policy_document" "invoke_agent_policy_doc" {
  statement {
    effect = "Allow"
    actions = ["bedrock:InvokeAgent"]
    resources = [var.bedrock_agent_arn]
  }
}

resource "aws_iam_policy" "invoke_agent_policy" {
  name = "invoke-agent-policy"
  policy = data.aws_iam_policy_document.invok_agent_policy.json
}

resource "aws_iam_role_policy_attachment" "bedrock_message_attachment" {
  role = aws_iam_role.lambda_bedrock_dynamo_role.name
  policy_arn =  aws_iam_policy.invoke_agent_policy.arn
}

resource "aws_iam_role_policy_attachment" "dynamodb_message_attachment" {
  role = aws_iam_role.lambda_bedrock_dynamo_role.name
  policy_arn = aws_iam_policy.lambda_dynamodb_policy.arn
}

data "archive_file" "message_bedrock_file" {
    type = "zip"
    source_file = "${path.module}/chat/message_bedrock.py"
    output_path = "${path.module}/chat/message_bedrock.zip"
}

resource "aws_lambda_function" "lambda_message_bedrock" {
    filename = data.archive_file.message_bedrock_file.output_path
    function_name = "lambda-message-bedrock"
    role = aws_iam_role.lambda_bedrock_dynamo_role
    handler = "message_bedrock.handler"
    source_code_hash = data.archive_file.message_bedrock_file.output_base64sha256
    runtime = "python3.9"
    environment {
      variables = {
        DYNAMO_DB_TABLE = var.dynamo_table
        KB_ID = var.kb_id
        AGENT_ID = var.agent_id
        REGION_NAME = var.bedrock_region
      }
    }
    tags = {}
}
/*
End of Bedrock section
*/