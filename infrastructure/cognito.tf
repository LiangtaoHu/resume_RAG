resource "aws_iam_role" "cognito_service_role" {
    name = "cognito-sns-role"
    assume_role_policy = jsonencode({
        Version = "2012-10-17"
        Statement = [{
            Effect = "Allow"
            Action = "sts:AssumeRole"
            Principal = { Service = "cognito-idp.amazonaws.com"}
            Condition = {
              StringEquals = {
                "sts:ExternalId" = var.SNS_external_ID
              }
            }
        }]
    })
}

data "aws_iam_policy_document" "cognito_sns_publish_statement" {
  statement {
    effect = "Allow"
    actions = ["sns:Publish"]
    resources = ["*"]
  }
}

// Cognito SNS role w/ trust policy to use SMS messaging 
resource "aws_iam_policy" "cognito_sns_publish_policy" {
  name = "sns-publish-policy"
  policy = data.aws_iam_policy_document.cognito_sns_publish_statement.json
}

resource "aws_iam_role_policy_attachment" "cognito_sns_publish_attachment" {
  role = aws_iam_role.cognito_service_role.name
  policy_arn =  aws_iam_policy.cognito_sns_publish_policy.arn
}

resource "aws_cognito_user_pool" "user_pool" {
    name = "client-users"
    alias_attributes = ["preferred_username", "email"]
    mfa_configuration = "OPTIONAL"

    account_recovery_setting {
      recovery_mechanism {
        name = "verified_email"
        priority = 1
      }
      recovery_mechanism {
        name = "verified_phone_number"
        priority = 2
      }
    }
    admin_create_user_config {
      allow_admin_create_user_only = false
      invite_message_template {
        email_message = "You are attempting to create a new account. Your username is {username} and your temporary password is {####}."
        email_subject = "Resume Optimizer - Account Intialization"
        sms_message = "You are attempting to create a new account for Resume Optimizer. Your username is {username} and your temporary login code is {####}."
      }
    }

    auto_verified_attributes = ["email"]
    user_attribute_update_settings {
        attributes_require_verification_before_update = ["email"]
    }

    // Ensures verified email
    email_configuration {
      email_sending_account = "COGNITO_DEFAULT" # Max of 50 emails a day, later set to SES, which will allow MFA for email
    }

    sms_configuration {
      // Used for MFA and confirming this is your phone during SMS user verification
      external_id = var.SNS_external_ID
      sns_caller_arn = aws_iam_role.cognito_service_role.arn
    }
}

resource "aws_cognito_user_pool_domain" "user_pool_domain" {
  domain = "resume-optimizer-domain"
  user_pool_id = aws_cognito_user_pool.user_pool.id
}

resource "aws_cognito_user_pool_client" "user_pool_client" {
  name = "resume-optimizer-client"
  user_pool_id = aws_cognito_user_pool.user_pool.id
  allowed_oauth_flows_user_pool_client = true
  callback_urls = [
    "https://${aws_cloudfront_distribution.cloudfront_distribution.domain_name}/callback" # TODO: Add a callback page to the S3 bucket to handle codes and exchange them for tokens!!
  ]
  allowed_oauth_flows = ["code"]
  allowed_oauth_scopes = ["openid", "email", "phone"]
  supported_identity_providers = ["COGNITO"]
  generate_secret = false
}