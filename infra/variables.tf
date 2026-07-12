// All Terraform input variables, grouped by domain. This replaces the
// previously-scattered variables.tf files under lambda/, lambda/*/,
// front_end/, and serverless_services/.

/* -------------------------------------------------------------------------- */
/* Cognito / CloudFront                                                       */
/* -------------------------------------------------------------------------- */

variable "SNS_external_ID" {
  type        = string
  description = "External ID for the Cognito SNS role trust policy (SMS MFA)."
}

variable "cloudfront_domain_name" {
  type        = string
  description = "CloudFront distribution domain name. Used for the Cognito callback URL and for the API Gateway CORS allow-list."
}

variable "cognito_user_pool_id" {
  type        = string
  description = "Cognito User Pool ID used to build the JWT issuer URL for the HTTP API authorizer."
}

variable "cognito_user_pool_client_id" {
  type        = string
  description = "Cognito User Pool App Client ID — listed as JWT audience on the HTTP API authorizer."
}

/* -------------------------------------------------------------------------- */
/* Lambda region / DynamoDB                                                   */
/* -------------------------------------------------------------------------- */

variable "lambda_region" {
  description = "Region where most non-Lambda@Edge functions live."
  type        = string
}

variable "region_name" {
  type        = string
  description = "Region where the S3-trigger Lambdas (alert_dynamo_link, add_dynamo_resume) run."
}

variable "dynamo_arn" {
  description = "ARN of the DynamoDB table used for user data."
  type        = string
}

variable "dynamo_table" {
  description = "Name of the DynamoDB table used for user data."
  type        = string
}

variable "dynamo_db_name" {
  type        = string
  description = "Alternate name reference for the DynamoDB table used by the S3-trigger Lambdas."
}

variable "dynamo_db_arn" {
  type        = string
  description = "Alternate ARN reference for the DynamoDB table used by the S3-trigger Lambdas."
}

variable "dynamo_username" {
  description = "Master username for the DynamoDB table (secrets manager)."
  type        = string
  sensitive   = true
}

variable "dynamo_password" {
  description = "Master password for the DynamoDB table (secrets manager)."
  type        = string
  sensitive   = true
}

/* -------------------------------------------------------------------------- */
/* S3 / resume bucket                                                         */
/* -------------------------------------------------------------------------- */

variable "resume_bucket" {
  type        = string
  description = "Name of the S3 bucket where users upload PDF resumes."
}

variable "resume_bucket_arn" {
  type        = string
  description = "ARN of the S3 resume bucket (used in IAM policies)."
}

variable "expiration_time" {
  description = "S3 presigned URL expiration time in seconds."
  type        = number
}

/* -------------------------------------------------------------------------- */
/* Bedrock / OpenSearch                                                       */
/* -------------------------------------------------------------------------- */

variable "bedrock_agent_arn" {
  description = "ARN of the Bedrock Agent that message_bedrock invokes."
  type        = string
}

variable "bedrock_region" {
  description = "Region where the Bedrock Agent was deployed."
  type        = string
}

variable "kb_id" {
  description = "ID of the Bedrock Knowledge Base used by message_bedrock."
  type        = string
}

variable "agent_id" {
  description = "ID of the Bedrock Agent used by message_bedrock."
  type        = string
}

variable "AGENT_ALIAS_ID" {
  type        = string
  description = "ID of the Bedrock Agent alias (specific version). NOT YET WIRED into message_bedrock — known TODO."
}

variable "parse_listing_ARN" {
  description = "ARN of the parse_listing (web scraper) Lambda. Used by the HTTP API integration, the KB data source, and the OpenSearch data-access policy."
  type        = string
}

variable "parse_listing_role_ARN" {
  description = "Execution role ARN of the parse_listing Lambda. Listed in the OpenSearch data-access policy."
  type        = string
}

/* -------------------------------------------------------------------------- */
/* HTTP API Lambda ARNs                                                       */
/* -------------------------------------------------------------------------- */

variable "parse_auth_ARN" {
  type        = string
  description = "ARN of the Lambda@Edge function that exchanges Cognito codes for tokens on /callback."
}

variable "upload_resume_ARN" {
  type        = string
  description = "Function ARN for the resume-upload Lambda (s3_presigned_url.handler)."
}

variable "message_ARN" {
  type        = string
  description = "Function ARN for the chat-message Lambda (message_bedrock.handler)."
}

variable "view_data_ARN" {
  type        = string
  description = "Function ARN for the view-user-data Lambda (conversation_starter.handler)."
}

variable "search_jobs_ARN" {
  type        = string
  description = "Function ARN for the keyword-search Lambda (Adzuna proxy). HTTP API integration, JWT-gated."
}

variable "job_crud_add_ARN" {
  type        = string
  description = "Function ARN for the job-add Lambda (creates JOB# rows from search hits)."
}

variable "job_crud_delete_ARN" {
  type        = string
  description = "Function ARN for the job-delete Lambda (soft-delete by setting deletedAt)."
}

/* -------------------------------------------------------------------------- */
/* Adzuna (search_jobs Lambda)                                                */
/* -------------------------------------------------------------------------- */

variable "adzuna_app_id" {
  type        = string
  description = "Adzuna API app_id. Used by search_jobs Lambda."
  sensitive   = true
}

variable "adzuna_app_key" {
  type        = string
  description = "Adzuna API app_key. Used by search_jobs Lambda."
  sensitive   = true
}

variable "adzuna_default_country" {
  type        = string
  description = "Default country code (e.g. 'us') for Adzuna search if the SPA does not override."
  default     = "us"
}