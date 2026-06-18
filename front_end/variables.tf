variable "upload_resume_ARN" {
    type = string
    description = "ARN of the Lambda function responsible for returning an S3 Presigned URL to upload resumes"
}

variable "parse_listing_ARN" {
    type = string
    description = "ARN of the Lambda function responsible for parsing a job listing and sending to a vector index"
}

variable "check_auth_ARN" {
    type = string
    description =  "ARN of the Lambda@Edge function responsible for checking if you have idTokens and redirecting you if you don't"
}

variable "parse_auth_ARN" {
    type = string
    description =  "ARN of the Lambda@Edge function responsible for injecting JWT cookies"
}