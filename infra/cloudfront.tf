// Static S3 hosting + CloudFront distribution.
// Lambdas are fronted by the HTTP API in api_gateway.tf and reached from
// CloudFront via the api-gateway-origin. Lambda@Edge check_auth was removed —
// authn is delegated to the API Gateway JWT authorizer.

locals {
  s3_origin_id    = "static-s3-origin"
  api_gw_origin_id = "api-gateway-origin"
  my_domain       = "customdomain.com"
}

// TODO: Create ACM Certificate
data "aws_acm_certificate" "issued_cert" {
  domain   = "*.${local.my_domain}"
  statuses = ["ISSUED"]
}

resource "aws_s3_bucket" "website_bucket" {
  bucket = "liangtaohu-website-bucket"
}

data "aws_iam_policy_document" "allow_CloudFront_Read" {
  statement {
    principals {
      type        = "Service"
      identifiers = ["cloudfront.amazonaws.com"]
    }
    actions   = ["s3:GetObject"]
    resources = ["${aws_s3_bucket.website_bucket.arn}/*"]
    condition {
      test     = "StringEquals"
      variable = "AWS:SourceArn"
      values   = [aws_cloudfront_distribution.cloudfront_distribution.arn]
    }
  }
}

resource "aws_s3_bucket_policy" "website_bucket_policy" {
  bucket = aws_s3_bucket.website_bucket.id
  policy = data.aws_iam_policy_document.allow_CloudFront_Read.json
}

resource "aws_cloudfront_origin_access_control" "cloudfront_oac" {
  name                              = "cloudfront_oac"
  origin_access_control_origin_type = "s3"
  signing_behavior                  = "always"
  signing_protocol                  = "sigv4"
}

resource "aws_cloudfront_distribution" "cloudfront_distribution" {
  aliases = [local.my_domain]

  // Static Website Bucket origin
  origin {
    domain_name              = aws_s3_bucket.website_bucket.bucket_regional_domain_name
    origin_access_control_id = aws_cloudfront_origin_access_control.cloudfront_oac.id
    origin_id                = local.s3_origin_id
  }

  // API Gateway origin — handles all /api/v1/* traffic with the native JWT authorizer.
  origin {
    domain_name = replace(aws_apigatewayv2_api.resume_optimizer_api.api_endpoint, "https://", "")
    origin_id   = local.api_gw_origin_id
    custom_origin_config {
      origin_protocol_policy = "https-only"
      origin_ssl_protocols    = ["TLSv1.2"]
      http_port               = 80
      https_port              = 443
    }
  }

  enabled             = true
  default_root_object = "index.html"

  ordered_cache_behavior {
    target_origin_id       = local.api_gw_origin_id
    viewer_protocol_policy = "redirect-to-https"
    cached_methods         = ["GET", "HEAD"]
    allowed_methods        = ["GET", "HEAD", "OPTIONS"]
    path_pattern           = "/api/v1/upload_resume"
    cache_policy_id        = "4135ea2d-6df8-44a3-9df3-4b5a84be39ad"
    origin_request_policy_id = "b689b0a8-53d0-40ab-baf2-68738e2966ac"
  }

  ordered_cache_behavior {
    target_origin_id       = local.api_gw_origin_id
    viewer_protocol_policy = "redirect-to-https"
    cached_methods         = ["GET", "HEAD"]
    allowed_methods        = ["GET", "HEAD", "OPTIONS", "PUT", "PATCH", "POST", "DELETE"]
    path_pattern           = "/api/v1/parse_listing"
    cache_policy_id        = "4135ea2d-6df8-44a3-9df3-4b5a84be39ad"
    origin_request_policy_id = "b689b0a8-53d0-40ab-baf2-68738e2966ac"
  }

  ordered_cache_behavior {
    target_origin_id       = local.api_gw_origin_id
    viewer_protocol_policy = "redirect-to-https"
    cached_methods         = ["GET", "HEAD"]
    allowed_methods        = ["GET", "HEAD", "OPTIONS", "PUT", "PATCH", "POST", "DELETE"]
    path_pattern           = "/api/v1/message"
    cache_policy_id        = "4135ea2d-6df8-44a3-9df3-4b5a84be39ad"
    origin_request_policy_id = "b689b0a8-53d0-40ab-baf2-68738e2966ac"
  }

  ordered_cache_behavior {
    target_origin_id       = local.api_gw_origin_id
    viewer_protocol_policy = "redirect-to-https"
    cached_methods         = ["GET", "HEAD"]
    allowed_methods        = ["GET", "HEAD", "OPTIONS", "PUT", "PATCH", "POST", "DELETE"]
    path_pattern           = "/api/v1/view_data"
    cache_policy_id        = "4135ea2d-6df8-44a3-9df3-4b5a84be39ad"
    origin_request_policy_id = "b689b0a8-53d0-40ab-baf2-68738e2966ac"
  }

  ordered_cache_behavior {
    target_origin_id       = local.s3_origin_id
    viewer_protocol_policy = "redirect-to-https"
    cached_methods         = ["GET", "HEAD"]
    allowed_methods        = ["GET", "HEAD"]
    path_pattern           = "/callback"
    cache_policy_id        = "4135ea2d-6df8-44a3-9df3-4b5a84be39ad"
    origin_request_policy_id = "216adef6-5c7f-47e4-b989-5492eafa07d3"
    lambda_function_association {
      event_type = "viewer-request"
      lambda_arn = var.parse_auth_ARN
    }
  }

  ordered_cache_behavior {
    target_origin_id       = local.s3_origin_id
    viewer_protocol_policy = "redirect-to-https"
    cached_methods         = ["GET", "HEAD"]
    allowed_methods        = ["GET", "HEAD"]
    path_pattern           = "/"
    cache_policy_id        = "658327ea-f89d-4fab-a63d-7e88639e58f6"
    origin_request_policy_id = "216adef6-5c7f-47e4-b989-5492eafa07d3"
  }

  default_cache_behavior {
    allowed_methods         = ["GET", "HEAD", "OPTIONS"]
    cached_methods          = ["GET", "HEAD"]
    target_origin_id        = local.s3_origin_id
    viewer_protocol_policy  = "redirect-to-https"
    origin_request_policy_id = "b689b0a8-53d0-40ab-baf2-68738e2966ac"
    cache_policy_id         = "658327ea-f89d-4fab-a63d-7e88639e58f6"
  }

  // SPA fallback: any 403/404 from S3 (deep links such as /dashboard, /chats, …)
  // is rewritten to /index.html so the React app can take over routing client-side.
  custom_error_response {
    error_code         = 403
    response_code      = 200
    response_page_path = "/index.html"
  }
  custom_error_response {
    error_code         = 404
    response_code      = 200
    response_page_path = "/index.html"
  }

  restrictions {
    geo_restriction {
      locations       = ["US", "CA"]
      restriction_type = "whitelist"
    }
  }

  viewer_certificate {
    acm_certificate_arn = aws_acm_certificate.cert.arn
    ssl_support_method  = "sni-only"
  }

  price_class = "PriceClass_100"
}