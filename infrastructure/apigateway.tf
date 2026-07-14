resource "aws_api_gateway_rest_api" "rest_api" {
    name = "res-opt-rest-api"
    endpoint_configuration {
      types = ["REGIONAL"]
    }
}

/* ========================================================================== */
/* Cognito Identity Provider                                                  */
/* ========================================================================== */
resource "aws_api_gateway_authorizer" "cognito_user_pools_auth" {
    name = "api-gateway-cognito-user-pool-auth"
    rest_api_id = aws_api_gateway_rest_api.rest_api.id
    type = "COGNITO_USER_POOLS"
    provider_arns = [aws_cognito_user_pool.user_pool.arn]
    identity_source = "method.request.header.Authorization"
}

resource "aws_api_gateway_resource" "api_prefix" {
  rest_api_id = aws_api_gateway_rest_api.rest_api.id
  parent_id = aws_api_gateway_rest_api.rest_api.root_resource_id
  path_part = "api"
}
/* ========================================================================== */
/* Linking Parse Listing Lambda                                               */
/* ========================================================================== */
resource "aws_api_gateway_resource" "parse_listing" {
    rest_api_id = aws_api_gateway_rest_api.rest_api.id
    path_part = "parse_listing"
    parent_id = aws_api_gateway_resource.api_prefix.id
}

resource "aws_api_gateway_method" "parse_listing" {
    rest_api_id = aws_api_gateway_rest_api.rest_api.id
    resource_id = aws_api_gateway_resource.parse_listing.id
    http_method = "POST"
    authorization = "COGNITO_USER_POOLS"
    authorizer_id = aws_api_gateway_authorizer.cognito_user_pools_auth.id
}

resource "aws_api_gateway_integration" "parse_listing" {
    rest_api_id = aws_api_gateway_rest_api.rest_api.id
    resource_id = aws_api_gateway_resource.parse_listing.id
    http_method = aws_api_gateway_method.parse_listing.http_method
    type = "AWS_PROXY"
    integration_http_method = "POST"
    uri = aws_lambda_function.lambda_parse_listing_func.invoke_arn
}

resource "aws_lambda_permission" "parse_listing_permission" {
  statement_id  = "rest-api-invoke-parse-listing"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.lambda_parse_listing_func.arn
  principal     = "apigateway.amazonaws.com"
  source_arn = "${aws_api_gateway_rest_api.rest_api.execution_arn}/*/POST/api/parse_listing"
}
/* ========================================================================== */
/* Linking Message Bedrock Lambda                                             */
/* ========================================================================== */
resource "aws_api_gateway_resource" "message_bedrock" {
    rest_api_id = aws_api_gateway_rest_api.rest_api.id
    path_part = "message_bedrock"
    parent_id = aws_api_gateway_resource.api_prefix.id
}

resource "aws_api_gateway_method" "message_bedrock" {
    rest_api_id = aws_api_gateway_rest_api.rest_api.id
    resource_id = aws_api_gateway_resource.message_bedrock.id
    http_method = "POST"
    authorization = "COGNITO_USER_POOLS"
    authorizer_id = aws_api_gateway_authorizer.cognito_user_pools_auth.id
}

resource "aws_api_gateway_integration" "message_bedrock" {
    rest_api_id = aws_api_gateway_rest_api.rest_api.id
    resource_id = aws_api_gateway_resource.message_bedrock.id
    http_method = aws_api_gateway_method.message_bedrock.http_method
    type = "AWS_PROXY"
    integration_http_method = "POST"
    uri = aws_lambda_function.lambda_message_bedrock_func.invoke_arn
}

resource "aws_lambda_permission" "message_bedrock_permission" {
  statement_id  = "rest-api-invoke-message-bedrock"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.lambda_message_bedrock_func.arn
  principal     = "apigateway.amazonaws.com"
  source_arn = "${aws_api_gateway_rest_api.rest_api.execution_arn}/*/POST/api/message_bedrock"
}
/* ========================================================================== */
/* Linking Upload Resume Lambda                                               */
/* ========================================================================== */
resource "aws_api_gateway_resource" "upload_resume" {
    rest_api_id = aws_api_gateway_rest_api.rest_api.id
    path_part = "upload_resume"
    parent_id = aws_api_gateway_resource.api_prefix.id
}

resource "aws_api_gateway_method" "upload_resume" {
    rest_api_id = aws_api_gateway_rest_api.rest_api.id
    resource_id = aws_api_gateway_resource.upload_resume.id
    http_method = "GET"
    authorization = "COGNITO_USER_POOLS"
    authorizer_id = aws_api_gateway_authorizer.cognito_user_pools_auth.id
}

resource "aws_api_gateway_integration" "upload_resume" {
    rest_api_id = aws_api_gateway_rest_api.rest_api.id
    resource_id = aws_api_gateway_resource.upload_resume.id
    http_method = aws_api_gateway_method.upload_resume.http_method
    type = "AWS_PROXY"
    integration_http_method = "POST"
    uri = aws_lambda_function.lambda_upload_resume_func.invoke_arn
}

resource "aws_lambda_permission" "upload_resume_permissions" {
  statement_id  = "rest-api-invoke-upload-resume"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.lambda_upload_resume_func.arn
  principal     = "apigateway.amazonaws.com"
  source_arn = "${aws_api_gateway_rest_api.rest_api.execution_arn}/*/GET/api/upload_resume"
}
/* ========================================================================== */
/* Linking Conversation Starter Lambda (view_data)                            */
/* ========================================================================== */
resource "aws_api_gateway_resource" "conversation_starter" {
    rest_api_id = aws_api_gateway_rest_api.rest_api.id
    path_part = "conversation_starter"
    parent_id = aws_api_gateway_resource.api_prefix.id
}

resource "aws_api_gateway_method" "conversation_starter" {
    rest_api_id = aws_api_gateway_rest_api.rest_api.id
    resource_id = aws_api_gateway_resource.conversation_starter.id
    http_method = "GET"
    authorization = "COGNITO_USER_POOLS"
    authorizer_id = aws_api_gateway_authorizer.cognito_user_pools_auth.id
}

resource "aws_api_gateway_integration" "conversation_starter" {
    rest_api_id = aws_api_gateway_rest_api.rest_api.id
    resource_id = aws_api_gateway_resource.conversation_starter.id
    http_method = aws_api_gateway_method.conversation_starter.http_method
    type = "AWS_PROXY"
    integration_http_method = "POST"
    uri = aws_lambda_function.lambda_conversation_starter_func.invoke_arn
}

resource "aws_lambda_permission" "conversation_starter_permissions" {
  statement_id  = "rest-api-invoke-conversation-starter"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.lambda_conversation_starter_func.arn
  principal     = "apigateway.amazonaws.com"
  source_arn = "${aws_api_gateway_rest_api.rest_api.execution_arn}/*/GET/api/conversation_starter"
}
/* ========================================================================== */
/* Redirect in case of failed authorization                                   */
/* ========================================================================== */
resource "aws_api_gateway_gateway_response" "failed_auth" {
    rest_api_id = aws_api_gateway_rest_api.rest_api.id
    status_code = "302"
    response_type = "UNAUTHORIZED"

    response_parameters = {
        "gatewayresponse.header.Location" = "'https://${aws_cognito_user_pool_domain.user_pool_domain.domain}.auth.${data.aws_region.curr_region.region}://${aws_cognito_user_pool_client.user_pool_client.id}&response_type=code&response_type=code&redirect_uri=https://${aws_cloudfront_distribution.cloudfront_distribution.domain_name}/callback'"
    }
}

// Finalizing it all
resource "aws_api_gateway_deployment" "rest_api" {
    rest_api_id = aws_api_gateway_rest_api.rest_api.id
    triggers = {
        api_structure = sha1(jsonencode([
            aws_api_gateway_resource.api_prefix,
            aws_api_gateway_resource.parse_listing,
            aws_api_gateway_resource.message_bedrock,
            aws_api_gateway_resource.upload_resume,
            aws_api_gateway_resource.conversation_starter,
            aws_api_gateway_method.parse_listing,
            aws_api_gateway_method.message_bedrock,
            aws_api_gateway_method.upload_resume,
            aws_api_gateway_method.conversation_starter,
            aws_api_gateway_integration.parse_listing,
            aws_api_gateway_integration.message_bedrock,
            aws_api_gateway_integration.upload_resume,
            aws_api_gateway_integration.conversation_starter,
        ]))
        lambda_definitions = join(",", [
            aws_lambda_function.lambda_parse_listing_func.source_code_hash,
            aws_lambda_function.lambda_conversation_starter_func.source_code_hash,
            aws_lambda_function.lambda_message_bedrock_func.source_code_hash,
            aws_lambda_function.lambda_upload_resume_func.source_code_hash,
        ])
    }
    lifecycle {
        create_before_destroy = true
    }
}

resource "aws_api_gateway_stage" "rest_api" {
    deployment_id = aws_api_gateway_deployment.rest_api.id
    rest_api_id = aws_api_gateway_rest_api.rest_api.id
    stage_name = "dev"
}