// Centralized Terraform root for the resume-optimizer app.
//
// All previously-scattered .tf files (root, front_end/, lambda/, serverless_services/)
// have been merged here. Python sources under ../lambda/ and the React SPA under
// ../front_end/spa/ are NOT moved — Terraform only references them via path.module.

// Still need to export AWS_ACCESS_KEY_ID, AWS_SECRET_ACCESS_KEY (TODO comment from
// the original main.tf — apply-time env vars).
provider "aws" {
  region = "us-east-1"
}

// us_east_1 alias required for Lambda@Edge functions (CloudFront-served Lambdas
// must live in us-east-1 regardless of the distribution's primary region).
provider "aws" {
  alias  = "us_east_1"
  region = "us-east-1"
}

terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 6.0"
    }
  }
  required_version = ">= 1.2"
}