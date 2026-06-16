variable "SNS_external_ID" {
    type = string
    description = "External ID for SNS messaging in Cognito"
}

variable "cloudfront_domain_name" {
    type = string
    description = "Cloudfront domain name for S3 bucket"
}