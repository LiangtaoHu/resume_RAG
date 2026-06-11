variable "SNS_external_ID" {
    type = string
    description = "External ID for SNS messaging in Cognito"
    sensitive = true
}

variable "upload_resume_ARN" {
    type = string
    description = "ARN of the Lambda function responsible for returning an S3 Presigned URL to upload resumes"
}

variable "parse_listing_ARN" {
    type = string
    description = "ARN of the Lambda function responsible for parsing a job listing and sending to a vector index"
}