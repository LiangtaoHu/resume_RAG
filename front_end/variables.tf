variable "upload_resume_ARN" {
    type = string
    description = "Function ARN for the resume-upload Lambda (used by HTTP API integration). Not a Function URL anymore."
}

variable "parse_listing_ARN" {
    type = string
    description = "Function ARN for the parse-listing Lambda (used by HTTP API integration and by the Bedrock KB data source)."
}

variable "parse_auth_ARN" {
    type = string
    description =  "ARN of the Lambda@Edge function responsible for injecting JWT cookies and handing off the idToken via /dashboard?token=..."
}

variable "message_ARN" {
    type = string
    description = "Function ARN for the chat-message Lambda (used by HTTP API integration)."
}

variable "view_data_ARN" {
    type = string
    description = "Function ARN for the view-user-data Lambda (used by HTTP API integration)."
}

variable "search_jobs_ARN" {
    type = string
    description = "Function ARN for the keyword-search Lambda (Adzuna proxy). HTTP API integration, JWT-gated."
}

variable "job_crud_add_ARN" {
    type = string
    description = "Function ARN for the job-add Lambda (creates JOB# rows from search hits). One of two functions sharing the job_crud zip."
}

variable "job_crud_delete_ARN" {
    type = string
    description = "Function ARN for the job-delete Lambda (soft-delete by setting deletedAt). One of two functions sharing the job_crud zip."
}

variable "cognito_user_pool_id" {
    type        = string
    description = "Cognito User Pool ID used to build the JWT issuer URL for the HTTP API authorizer."
}

variable "cognito_user_pool_client_id" {
    type        = string
    description = "Cognito User Pool App Client ID — listed as JWT audience on the HTTP API authorizer."
}