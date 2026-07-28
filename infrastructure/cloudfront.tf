// Static Hosting + CloudFront distribution
locals {
    s3_origin_id = "static-s3-origin"
    api_gateway_origin_id = "api-gateway-origin"
    my_domain = "resumeoptimizerapp.com"

    no_caching_policy = "4135ea2d-6df8-44a3-9df3-4b5a84be39ad"
    all_viewer_except_host = "b689b0a8-53d0-40ab-baf2-68738e2966ac"
    caching_optimized = "658327ea-f89d-4fab-a63d-7e88639e58f6"
}

// TODO: Create ACM Certificate 
# data "aws_acm_certificate" "issued_cert" {

#     statuses = ["ISSUED"]
# }

resource "aws_cloudfront_origin_access_control" "cloudfront_oac" {
    name = "cloudfront_oac"
    origin_access_control_origin_type = "s3"
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

    // API Gateway
    origin {
      domain_name = "${aws_api_gateway_rest_api.rest_api.id}.execute-api.${data.aws_region.curr_region.region}.amazonaws.com"
      origin_id = local.api_gateway_origin_id
      custom_origin_config {
        http_port = 80
        https_port = 443
        origin_protocol_policy = "https-only"
        origin_ssl_protocols = ["TLSv1.2"]
      }
    }

    // API Gateway
    ordered_cache_behavior {
      target_origin_id = local.api_gateway_origin_id
      viewer_protocol_policy = "https-only"
      cached_methods = ["GET", "HEAD"]
      allowed_methods = ["GET", "HEAD", "OPTIONS", "PUT", "POST", "PATCH", "DELETE"]
      path_pattern = "/api/*"
      cache_policy_id = local.no_caching_policy
      origin_request_policy_id = local.all_viewer_except_host
    }

    // S3 Static Website
    default_cache_behavior {
      allowed_methods = ["GET", "HEAD", "OPTIONS"]
      cached_methods = ["GET", "HEAD"]
      target_origin_id = local.s3_origin_id
      viewer_protocol_policy = "redirect-to-https"
      origin_request_policy_id = ""
      cache_policy_id = local.caching_optimized 
    }

    enabled = true
    default_root_object = "index.html"
    
    restrictions {
      geo_restriction {
        locations = ["US", "CA"]
        restriction_type = "whitelist"
      }
    }

    viewer_certificate {
        acm_certificate_arn = "arn:aws:acm:us-east-1:273354655761:certificate/053d7964-88f7-4a24-8354-3d52ed3f0c79"
        ssl_support_method = "sni-only"
    }

    price_class = "PriceClass_100"
}