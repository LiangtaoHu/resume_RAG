// HTTP API sitting between CloudFront and the 4 backend Lambdas.
// Performs Cognito JWT validation natively via aws_apigatewayv2_authorizer.
// Each target function receives the verified Cognito `sub` claim on
// event.requestContext.authorizer.jwt.claims.

resource "aws_apigatewayv2_api" "resume_optimizer_api" {
  name          = "resume-optimizer-api"
  protocol_type = "HTTP"

  cors_configuration {
    allow_origins = [
      "https://${var.cloudfront_domain_name}",
      "https://customdomain.com"
    ]
    allow_methods = ["GET", "POST", "OPTIONS", "PUT", "PATCH", "DELETE"]
    allow_headers = [
      "Content-Type",
      "Authorization",
      "X-Amz-Date",
      "X-Amz-Security-Token"
    ]
    allow_credentials = false
    max_age           = 300
  }
}

// Native JWT authorizer backed by the existing Cognito User Pool.
// identity_source is locked to the Authorization header — HTTP API JWT
// authorizers do not accept cookie-based identity sources.
resource "aws_apigatewayv2_authorizer" "cognito_jwt" {
  api_id           = aws_apigatewayv2_api.resume_optimizer_api.id
  authorizer_type  = "JWT"
  name             = "cognito-jwt"
  identity_sources = ["$request.header.Authorization"]

  jwt_configuration {
    issuer    = "https://cognito-idp.${var.lambda_region}.amazonaws.com/${var.cognito_user_pool_id}"
    audience  = [var.cognito_user_pool_client_id]
  }
}

// 4 Lambda integrations (AWS_PROXY v2.0).
locals {
  api_gw_origin_id = "api-gateway-origin"
}

resource "aws_apigatewayv2_integration" "upload_resume" {
  api_id                 = aws_apigatewayv2_api.resume_optimizer_api.id
  integration_type       = "AWS_PROXY"
  integration_method     = "POST"
  integration_uri        = var.upload_resume_ARN
  payload_format_version = "2.0"
}

resource "aws_apigatewayv2_integration" "parse_listing" {
  api_id                 = aws_apigatewayv2_api.resume_optimizer_api.id
  integration_type       = "AWS_PROXY"
  integration_method     = "POST"
  integration_uri        = var.parse_listing_ARN
  payload_format_version = "2.0"
}

resource "aws_apigatewayv2_integration" "message" {
  api_id                 = aws_apigatewayv2_api.resume_optimizer_api.id
  integration_type       = "AWS_PROXY"
  integration_method     = "POST"
  integration_uri        = var.message_ARN
  payload_format_version = "2.0"
}

resource "aws_apigatewayv2_integration" "view_data" {
  api_id                 = aws_apigatewayv2_api.resume_optimizer_api.id
  integration_type       = "AWS_PROXY"
  integration_method     = "POST"
  integration_uri        = var.view_data_ARN
  payload_format_version = "2.0"
}

// Keyword search (Adzuna proxy) — preview only, no DB writes.
resource "aws_apigatewayv2_integration" "search_jobs" {
  api_id                 = aws_apigatewayv2_api.resume_optimizer_api.id
  integration_type       = "AWS_PROXY"
  integration_method     = "POST"
  integration_uri        = var.search_jobs_ARN
  payload_format_version = "2.0"
}

// Job CRUD: add (creates a JOB# row from a search hit) and delete (soft-delete
// by setting `deletedAt`). Two separate Lambda functions share a single
// zip-packaged archive; each route dispatches to its own function.
resource "aws_apigatewayv2_integration" "jobs_crud_add" {
  api_id                 = aws_apigatewayv2_api.resume_optimizer_api.id
  integration_type       = "AWS_PROXY"
  integration_method     = "POST"
  integration_uri        = var.job_crud_add_ARN
  payload_format_version = "2.0"
}

resource "aws_apigatewayv2_integration" "jobs_crud_delete" {
  api_id                 = aws_apigatewayv2_api.resume_optimizer_api.id
  integration_type       = "AWS_PROXY"
  integration_method     = "POST"
  integration_uri        = var.job_crud_delete_ARN
  payload_format_version = "2.0"
}

// 4 routes — each gated by the JWT authorizer.
resource "aws_apigatewayv2_route" "upload_resume" {
  api_id             = aws_apigatewayv2_api.resume_optimizer_api.id
  route_key          = "GET /api/v1/upload_resume"
  target             = "integrations/${aws_apigatewayv2_integration.upload_resume.id}"
  authorization_type = "JWT"
  authorizer_id      = aws_apigatewayv2_authorizer.cognito_jwt.id
}

resource "aws_apigatewayv2_route" "parse_listing" {
  api_id             = aws_apigatewayv2_api.resume_optimizer_api.id
  route_key          = "POST /api/v1/parse_listing"
  target             = "integrations/${aws_apigatewayv2_integration.parse_listing.id}"
  authorization_type = "JWT"
  authorizer_id      = aws_apigatewayv2_authorizer.cognito_jwt.id
}

resource "aws_apigatewayv2_route" "message" {
  api_id             = aws_apigatewayv2_api.resume_optimizer_api.id
  route_key          = "POST /api/v1/message"
  target             = "integrations/${aws_apigatewayv2_integration.message.id}"
  authorization_type = "JWT"
  authorizer_id      = aws_apigatewayv2_authorizer.cognito_jwt.id
}

resource "aws_apigatewayv2_route" "view_data" {
  api_id             = aws_apigatewayv2_api.resume_optimizer_api.id
  route_key          = "GET /api/v1/view_data"
  target             = "integrations/${aws_apigatewayv2_integration.view_data.id}"
  authorization_type = "JWT"
  authorizer_id      = aws_apigatewayv2_authorizer.cognito_jwt.id
}

// Keyword search route — preview only, no DB writes. Calls search_jobs Lambda.
resource "aws_apigatewayv2_route" "search_jobs" {
  api_id             = aws_apigatewayv2_api.resume_optimizer_api.id
  route_key          = "POST /api/v1/search_jobs"
  target             = "integrations/${aws_apigatewayv2_integration.search_jobs.id}"
  authorization_type = "JWT"
  authorizer_id      = aws_apigatewayv2_authorizer.cognito_jwt.id
}

// Job CRUD: add (creates a JOB# row from a search hit) and delete
// (soft-delete by setting `deletedAt`). Two separate Lambda functions share
// a single zip-packaged archive; each route dispatches to its own function.
resource "aws_apigatewayv2_route" "jobs_add" {
  api_id             = aws_apigatewayv2_api.resume_optimizer_api.id
  route_key          = "POST /api/v1/jobs/add"
  target             = "integrations/${aws_apigatewayv2_integration.jobs_crud_add.id}"
  authorization_type = "JWT"
  authorizer_id      = aws_apigatewayv2_authorizer.cognito_jwt.id
}

resource "aws_apigatewayv2_route" "jobs_delete" {
  api_id             = aws_apigatewayv2_api.resume_optimizer_api.id
  route_key          = "POST /api/v1/jobs/delete"
  target             = "integrations/${aws_apigatewayv2_integration.jobs_crud_delete.id}"
  authorization_type = "JWT"
  authorizer_id      = aws_apigatewayv2_authorizer.cognito_jwt.id
}

resource "aws_apigatewayv2_stage" "default" {
  api_id      = aws_apigatewayv2_api.resume_optimizer_api.id
  name        = "$default"
  auto_deploy = true
}

// Resource-based Lambda permissions — API Gateway needs to be allowed to invoke
// each function. This is the standard pattern for HTTP API integrations;
// no separate API Gateway execution role is required.
resource "aws_lambda_permission" "upload_resume_apigw" {
  statement_id  = "AllowAPIGatewayInvoke"
  action        = "lambda:InvokeFunction"
  function_name = var.upload_resume_ARN
  principal     = "apigateway.amazonaws.com"
  source_arn    = "${aws_apigatewayv2_api.resume_optimizer_api.execution_arn}/*/*"
}

resource "aws_lambda_permission" "parse_listing_apigw" {
  statement_id  = "AllowAPIGatewayInvoke"
  action        = "lambda:InvokeFunction"
  function_name = var.parse_listing_ARN
  principal     = "apigateway.amazonaws.com"
  source_arn    = "${aws_apigatewayv2_api.resume_optimizer_api.execution_arn}/*/*"
}

resource "aws_lambda_permission" "message_apigw" {
  statement_id  = "AllowAPIGatewayInvoke"
  action        = "lambda:InvokeFunction"
  function_name = var.message_ARN
  principal     = "apigateway.amazonaws.com"
  source_arn    = "${aws_apigatewayv2_api.resume_optimizer_api.execution_arn}/*/*"
}

resource "aws_lambda_permission" "view_data_apigw" {
  statement_id  = "AllowAPIGatewayInvoke"
  action        = "lambda:InvokeFunction"
  function_name = var.view_data_ARN
  principal     = "apigateway.amazonaws.com"
  source_arn    = "${aws_apigatewayv2_api.resume_optimizer_api.execution_arn}/*/*"
}

resource "aws_lambda_permission" "search_jobs_apigw" {
  statement_id  = "AllowAPIGatewayInvoke"
  action        = "lambda:InvokeFunction"
  function_name = var.search_jobs_ARN
  principal     = "apigateway.amazonaws.com"
  source_arn    = "${aws_apigatewayv2_api.resume_optimizer_api.execution_arn}/*/*"
}

resource "aws_lambda_permission" "jobs_crud_add_apigw" {
  statement_id  = "AllowAPIGatewayInvoke"
  action        = "lambda:InvokeFunction"
  function_name = var.job_crud_add_ARN
  principal     = "apigateway.amazonaws.com"
  source_arn    = "${aws_apigatewayv2_api.resume_optimizer_api.execution_arn}/*/*"
}

resource "aws_lambda_permission" "jobs_crud_delete_apigw" {
  statement_id  = "AllowAPIGatewayInvoke"
  action        = "lambda:InvokeFunction"
  function_name = var.job_crud_delete_ARN
  principal     = "apigateway.amazonaws.com"
  source_arn    = "${aws_apigatewayv2_api.resume_optimizer_api.execution_arn}/*/*"
}

output "api_endpoint" {
  value = aws_apigatewayv2_api.resume_optimizer_api.api_endpoint
}
