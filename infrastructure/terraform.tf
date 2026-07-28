terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 6.0"
    }
    opensearch = {
      source = "opensearch-project/opensearch"
      version = "~> 2.3"
    }
  }
  required_version = ">= 1.2"
}