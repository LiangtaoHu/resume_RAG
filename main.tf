// Still need to export AWS_ACCESS_KEY_ID, AWS_SECRET_ACCESS_KEY (Any way to do this properly?)
provider "aws" {
  region = "us-east-1"
}


// Should output dynamo_arn, and dynamo_table
module "dynamodb_instance" {
  source = "./serverless_services/dynamodb"
  dynamo_password = "test_password"
  dynamo_username = "test_username"
}

module "base_lambda_functions" {
  source = "./lambda/base_lambda_funcs"
  expiration_time = 500
  dynamo_arn = module.dynamodb_instance.dynamo_arn
  dynamo_table = module.dynamodb_instance.dynamo_table
  depends_on = [module.dynamodb_instance]
}

# module "dynamo_lambdas" {
#   source = "./lambda/dynamo_lambda_funcs"
#   dynamo_arn = dynamodb_instance.dynamo_arn
#   dynamo_table = dynamodb_intance.dynamo_table
#   depends_on = [module.dynamodb_instance]
# }

# module "agent_arch" {
#   source = "./serverless_services/agent"
#   depends_on = ["./lambda/base_lambda_funcs"]
#   parse_listing_ARN = base_lambda_functions.parse_listing_ARN
#   parse_listing_role_ARN = base_lambda_functions.parse_listing_role_ARN
# }