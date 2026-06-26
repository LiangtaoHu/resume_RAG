variable resume_bucket {
    type = string
    description = "Bucket name for Resume bucket"
}

variable resume_bucket_arn {
    type = string
    description = "Bucket arn for Resume bucket"
}

variable region_name {
    type = string
    description = "Region where lambda for S3 trigger should be"
}

variable dynamo_db_name {
    type = string
    description = "Name of Dynamo Database"
}

variable dynamo_db_arn {
    type = string
    description = "ARN of Dynamo Database"
}