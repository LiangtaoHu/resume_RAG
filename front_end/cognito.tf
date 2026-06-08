resource "aws_iam_role" "CognitoSNSRole" {
  name = "CognitoSMSRole"
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = {
      Action = "sts:AssumeRole"
      Effect = "Allow"
      Sid = ""
      Principal = {
        Service = "cognito-idp.amazonaws.com"
      }
      Condition = {
        "StringEquals" = {
          "sts:ExternalId": var.SNS_external_ID
        }
      }
    }
  })
}

data "aws_iam_policy_document" "SNS_policy_doc" {
  statement {
    effect = "Allow"
    actions = ["sns:Publish"]
    resources = ["*"]
  }
}

resource "aws_iam_policy" "SNS_policy" {
  name = "sns-policy"
  description = "A policy to allow sns messages to be published"
  policy = data.aws_iam_policy_document.SNS_policy_doc.json
}

resource "aws_iam_role_policy_attachment" "attach_SNS_policy" {
  role = aws_iam_role.CognitoSNSRole.name
  policy_arn = aws_iam_policy.SNS_policy.arn
}

resource "aws_cognito_user_pool" "user_pool" {
    name = "user_pool"
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
        sms_message = "You are attempting to create a new account for Resume Optimizer. Your username is {username} and your temporary password is {####}."
      }
    }

    auto_verified_attributes = ["email", "phone_number"]

    // Ensures verified email
    email_configuration {
      email_sending_account = "COGNITO_DEFAULT" # Max of 50 emails a day, later set to SES, which will allow MFA for email
    }

    sms_configuration {
      // Used for MFA and confirming this is your phone during SMS user verification
      external_id = var.SNS_external_ID
      sns_caller_arn = aws_iam_role.CognitoSNSRole.arn
    }
}

resource "aws_cognito_user_pool_domain" "alb_cog_domain" {
  domain = "alb-cog-domain"
  user_pool_id = aws_cognito_user_pool.user_pool.id
}

resource "aws_cognito_user_pool_client" "alb_cog_client" {
  name = "alb-cog-client"
  user_pool_id = aws_cognito_user_pool.user_pool.id
  allowed_oauth_flows_user_pool_client = true
  callback_urls = [var.alb_domain_name]
  allowed_oauth_flows = ["code"]
  allowed_oauth_scopes = ["openid", "email", "phone"]
  supported_identity_providers = ["COGNITO"]
  generate_secret = true
}