resource "aws_s3_bucket" "resume_bucket" {
    bucket = "liangtaohu-resume-bucket"
}

resource "aws_s3_bucket" "website_bucket" {
    bucket = "liangtaohu-website-bucket"
}

data "aws_iam_policy_document" "bucket_cloudfront_read_statement" {
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
    policy = data.aws_iam_policy_document.bucket_cloudfront_read_statement.json
}