// Static Hosting + CloudFront distribution

resource "aws_lambda_function_url" "upload_resume_url" {
    authorization_type = "AWS_IAM"
    function_name = var.upload_resume_ARN
}

resource "aws_lambda_function_url" "parse_listing_url" {
    authorization_type = "AWS_IAM"
    function_name = var.parse_listing_ARN
}

locals {
    s3_origin_id = "static-s3-origin"
    upload_resume_id = "lambda-upload-url"
    parse_listing_id = "lambda-parse-listing"
    my_domain = "customdomain.com"
}

// TODO: Create ACM Certificate 
data "aws_acm_certificate" "issued_cert" {
    domain = "*.${local.my_domain}"
    statuses = ["ISSUED"]
}

resource "aws_s3_bucket" "website_bucket" {
    bucket = "liangtaohu-website-bucket"
}

data "aws_iam_policy_document" "allow_CloudFront_Read" {
    statement {
        principals {
            type = "Service"
            identifiers = ["cloudfront.amazonaws.com"]
        }
        actions = ["s3:GetObject"]
        resources = ["${aws_s3_bucket.website_bucket.arn}/*"]
        condition {
            test     = "StringEquals"
            variable = "AWS:SourceArn"
            values = [aws_cloudfront_distribution.cloudfront_distribution.arn]
        }
    }
}

resource "aws_s3_bucket_policy" "website_bucket_policy" {
    bucket = aws_s3_bucket.website_bucket.id
    policy = data.aws_iam_policy_document.allow_CloudFront_Read.json
}

resource "aws_cloudfront_origin_access_control" "cloudfront_oac" {
    name = "cloudfront_oac"
    origin_access_control_origin_type = "s3"
    signing_behavior = "always"
    signing_protocol = "sigv4"
}

resource "aws_cloudfront_origin_access_control" "lambda_oac" {
    name = "lambda_oac"
    origin_access_control_origin_type = "lambda"
    signing_behavior = "always"
    signing_protocol = "sigv4"
}

resource "aws_cloudfront_distribution" "cloudfront_distribution" {
    aliases = ["${local.my_domain}"]

    // Static Website Bucket origin
    origin {
      domain_name = aws_s3_bucket.website_bucket.bucket_regional_domain_name
      origin_access_control_id = aws_cloudfront_origin_access_control.cloudfront_oac.id
      origin_id = local.s3_origin_id
    }
    // Upload Resume origin
    origin {
      domain_name = replace(replace(aws_lambda_function_url.upload_resume_url.function_url, "https://", ""), "/", "")
      origin_id = local.upload_resume_id
      origin_access_control_id = aws_cloudfront_origin_access_control.lambda_oac.id

    #   custom_origin_config {
    #     https_port = 443
    #     http_port = 80
    #     origin_protocol_policy = "https-only"
    #     origin_ssl_protocols = ["TLSv1.2"]
    #   }
    }
    // Parse Listing origin
    origin {
      domain_name = replace(replace(aws_lambda_function_url.parse_listing_url.function_url, "https://", ""), "/", "")
      origin_id = local.parse_listing_id
      origin_access_control_id = aws_cloudfront_origin_access_control.lambda_oac.id
    #   custom_origin_config {
    #     https_port = 443
    #     http_port = 80
    #     origin_protocol_policy = "https-only"
    #     origin_ssl_protocols = ["TLSv1.2"]
    #   }
    }
    // Message origin
    origin {
        domain_name =
        origin_id =
        origin_access_control_id = 
    }
    // List Resumes Origin
    origin {
        domain_name =
        origin_id =
        origin_access_control_id = 
    }
    // List Parsed Job Listings Origin
    origin {
        domain_name =
        origin_id =
        origin_access_control_id = 
    }

    enabled = true
    default_root_object = "index.html"

    default_cache_behavior {
      allowed_methods = ["GET", "HEAD", "OPTIONS"]
      cached_methods = ["GET", "HEAD"]
      target_origin_id = local.s3_origin_id
      viewer_protocol_policy = "redirect-to-https"
      // TODO: ttl?
      origin_request_policy_id = "b689b0a8-53d0-40ab-baf2-68738e2966ac"   // AllViewer Except Host header
    }
    // TODO: Ordered Cache Behavior for Chatting

    // Ordered Cache Behavior for uploading resume
    ordered_cache_behavior {
        target_origin_id = local.upload_resume_id
        viewer_protocol_policy = "redirect-to-https"
        cached_methods = ["GET", "HEAD"]
        allowed_methods = ["GET", "HEAD", "OPTIONS"]
        path_pattern = "/api/v1/upload_resume"
        // Could we configure this to the length of time the presigned URL is valid? In order to prevent mass creation.
        cache_policy_id = "4135ea2d-6df8-44a3-9df3-4b5a84be39ad"        // No caching
        origin_request_policy_id = "b689b0a8-53d0-40ab-baf2-68738e2966ac"   // AllViewer Except Host header
        lambda_function_association {
          event_type = "viewer-request"
          lambda_arn = "${var.check_auth_ARN}"
        }
    }

    // Ordered Cache Behavior for parsing listings
    ordered_cache_behavior {
        target_origin_id = local.parse_listing_id 
        viewer_protocol_policy = "redirect-to-https"
        cached_methods = ["GET", "HEAD"]
        allowed_methods = ["GET", "HEAD", "OPTIONS", "PUT", "PATCH", "POST", "DELETE"]
        path_pattern = "/api/v1/parse_listing"
        cache_policy_id = "4135ea2d-6df8-44a3-9df3-4b5a84be39ad"        // No caching
        origin_request_policy_id = "216adef6-5c7f-47e4-b989-5492eafa07d3"   // AllViewer
        lambda_function_association {
          event_type = "viewer-request"
          lambda_arn = var.check_auth_ARN
        }
    }

    ordered_cache_behavior {
        target_origin_id = local.s3_origin_id
        viewer_protocol_policy = "redirect-to-https"
        cached_methods = ["GET", "HEAD"]
        allowed_methods = ["GET", "HEAD"]
        path_pattern = "/callback"
        cache_policy_id = "4135ea2d-6df8-44a3-9df3-4b5a84be39ad"        // No caching
        origin_request_policy_id = "216adef6-5c7f-47e4-b989-5492eafa07d3"   // AllViewer
        lambda_function_association {
          event_type = "viewer-request"
          lambda_arn = var.parse_auth_ARN
        }
    }

    restrictions {
      geo_restriction {
        locations = ["US", "CA"]
        restriction_type = "whitelist"
      }
    }

    viewer_certificate {
        acm_certificate_arn = aws_acm_certificate.cert.arn
        ssl_support_method = "sni-only"
    }

    price_class = "PriceClass_100"
}