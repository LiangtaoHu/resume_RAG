// Static Hosting + CloudFront distribution
locals {
    s3_origin_id = "static-s3-origin"
    upload_resume_id = "lambda-upload-url"
    parse_listing_id = "lambda-parse-listing"
    message_id = "lambda-message-bedrock"
    view_data_id = "lambda-view-user-data"
    my_domain = "customdomain.com"

    no_caching_policy = "4135ea2d-6df8-44a3-9df3-4b5a84be39ad"
    all_viewer_except_host = "b689b0a8-53d0-40ab-baf2-68738e2966ac"
    all_viewer = "216adef6-5c7f-47e4-b989-5492eafa07d3"
    caching_optimized = "658327ea-f89d-4fab-a63d-7e88639e58f6"
}

resource "aws_lambda_function_url" "upload_resume" {
    authorization_type = "AWS_IAM"
    function_name = aws_lambda_function.lambda_upload_resume_func.arn
}

resource "aws_lambda_function_url" "parse_listing" {
    authorization_type = "AWS_IAM"
    function_name = aws_lambda_function.lambda_parse_listing_func.arn
}

resource "aws_lambda_function_url" "message_bedrock" {
    authorization_type = "AWS_IAM"
    function_name = aws_lambda_function.lambda_message_bedrock_func.arn
}

resource "aws_lambda_function_url" "conversation_starter" {
    authorization_type = "AWS_IAM"
    function_name = aws_lambda_function.lambda_conversation_starter_func.arn
}

// TODO: Create ACM Certificate 
data "aws_acm_certificate" "issued_cert" {
    domain = "*.${local.my_domain}"
    statuses = ["ISSUED"]
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
      domain_name = replace(replace(aws_lambda_function_url.upload_resume.function_url, "https://", ""), "/", "")
      origin_id = local.upload_resume_id
      origin_access_control_id = aws_cloudfront_origin_access_control.lambda_oac.id
    }
    // Parse Listing origin
    origin {
      domain_name = replace(replace(aws_lambda_function_url.parse_listing.function_url, "https://", ""), "/", "")
      origin_id = local.parse_listing_id
      origin_access_control_id = aws_cloudfront_origin_access_control.lambda_oac.id
    }
    // Message origin
    origin {
        domain_name = replace(replace(aws_lambda_function_url.message_bedrock.function_url, "https://", ""), "/", "")
        origin_id = local.message_id
        origin_access_control_id = aws_cloudfront_origin_access_control.lambda_oac.id
    }
    // view_data origin
    origin {
        domain_name = replace(replace(aws_lambda_function_url.conversation_starter.function_url, "https://", ""), "/", "")
        origin_id = local.view_data_id
        origin_access_control_id = aws_cloudfront_origin_access_control.lambda_oac.id
    }

    enabled = true
    default_root_object = "index.html"

    // Ordered Cache Behavior for uploading resume
    ordered_cache_behavior {
        target_origin_id = local.upload_resume_id
        viewer_protocol_policy = "redirect-to-https"
        cached_methods = ["GET", "HEAD"]
        allowed_methods = ["GET", "HEAD", "OPTIONS"]
        path_pattern = "/api/v1/upload_resume"
        // Could we configure this to the length of time the presigned URL is valid? In order to prevent mass creation.
        cache_policy_id =  local.no_caching_policy
        origin_request_policy_id = local.all_viewer_except_host
        lambda_function_association {
          event_type = "viewer-request"
          lambda_arn = "${aws_lambda_function.lambda_at_edge_check_auth_func.arn}"
        }
    }

    // Ordered Cache Behavior for parsing listings
    ordered_cache_behavior {
        target_origin_id = local.parse_listing_id 
        viewer_protocol_policy = "redirect-to-https"
        cached_methods = ["GET", "HEAD"]
        allowed_methods = ["GET", "HEAD", "OPTIONS", "PUT", "PATCH", "POST", "DELETE"]
        path_pattern = "/api/v1/parse_listing"
        cache_policy_id = local.no_caching_policy
        origin_request_policy_id = local.all_viewer
        lambda_function_association {
          event_type = "viewer-request"
          lambda_arn = aws_lambda_function.lambda_at_edge_check_auth_func.arn
        }
    }

    ordered_cache_behavior {
        target_origin_id = local.message_id 
        viewer_protocol_policy = "redirect-to-https"
        cached_methods = ["GET", "HEAD"]
        allowed_methods = ["GET", "HEAD", "OPTIONS", "PUT", "PATCH", "POST", "DELETE"]
        path_pattern = "/api/v1/message"
        cache_policy_id = local.no_caching_policy
        origin_request_policy_id = local.all_viewer_except_host
        lambda_function_association {
          event_type = "viewer-request"
          lambda_arn = aws_lambda_function.lambda_at_edge_check_auth_func.arn
        }
    }

    ordered_cache_behavior {
        target_origin_id = local.view_data_id 
        viewer_protocol_policy = "redirect-to-https"
        cached_methods = ["GET", "HEAD"]
        allowed_methods = ["GET", "HEAD", "OPTIONS", "PUT", "PATCH", "POST", "DELETE"]
        path_pattern = "/api/v1/view_data"
        cache_policy_id = local.no_caching_policy
        origin_request_policy_id = local.all_viewer_except_host
        lambda_function_association {
          event_type = "viewer-request"
          lambda_arn = aws_lambda_function.lambda_at_edge_check_auth_func.arn
        }
    }

    ordered_cache_behavior {
        target_origin_id = local.s3_origin_id
        viewer_protocol_policy = "redirect-to-https"
        cached_methods = ["GET", "HEAD"]
        allowed_methods = ["GET", "HEAD"]
        path_pattern = "/callback"
        cache_policy_id = local.no_caching_policy
        origin_request_policy_id = local.all_viewer
        lambda_function_association {
          event_type = "viewer-request"
          lambda_arn = aws_lambda_function.lambda_at_edge_check_auth_func.arn
        }
    }
    // Main Page
    ordered_cache_behavior {
        target_origin_id = local.s3_origin_id
        viewer_protocol_policy = "redirect-to-https"
        cached_methods = ["GET", "HEAD"]
        allowed_methods = ["GET", "HEAD"]
        path_pattern = "/"
        cache_policy_id = local.caching_optimized
        origin_request_policy_id = local.all_viewer
    }

    default_cache_behavior {
      allowed_methods = ["GET", "HEAD", "OPTIONS"]
      cached_methods = ["GET", "HEAD"]
      target_origin_id = local.s3_origin_id
      viewer_protocol_policy = "redirect-to-https"
      origin_request_policy_id = local.all_viewer_except_host
      cache_policy_id = local.caching_optimized // Caching Optimized, every other part of the S3 origin should be cached. The entire layout is the same, the data just isn't (lambda origin response)
    }

    restrictions {
      geo_restriction {
        locations = ["US", "CA"]
        restriction_type = "whitelist"
      }
    }

    viewer_certificate {
        acm_certificate_arn = data.aws_acm_certificate.issued_cert.arn
        ssl_support_method = "sni-only"
    }

    price_class = "PriceClass_100"
}