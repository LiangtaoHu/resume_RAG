// Static Hosting + CloudFront distribution
// Bucket is split into /web/.. and /resumes/{user_id}

resource "aws_s3_bucket" "resume_opt_bucket" {
    bucket = "liangtaohu-resume-opt-bucket"
}
