// Cognito User Pool, Client, and Hosted UI domain.
// All authentication for the app is delegated to this User Pool — both via the
// Hosted UI (SPA sign-in flow) and via the JWT authorizer in api_gateway.tf.

resource "aws_iam_role" "cognito_sns_role" {
  name                 = "CognitoSNSRole"
  assume_role_policy   = data.aws_iam_policy_document.cognito_trust_policy.json
}

data "aws_iam_policy_document" "cognito_trust_policy" {
  statement {
    actions = ["sts:AssumeRole"]
    effect  = "Allow"
    principals {
      type        = "Service"
      identifiers = ["cognito-idp.amazonaws.com"]
    }
    condition {
      test     = "StringEquals"
      variable = "sts:ExternalId"
      values   = [var.SNS_external_ID]
    }
  }
}

data "aws_iam_policy_document" "sns_publish_policy_doc" {
  statement {
    effect    = "Allow"
    actions   = ["sns:Publish"]
    resources = ["*"]
  }
}

resource "aws_iam_role_policy" "attach_SNS_policy" {
  name   = "CognitoSNSPublishPolicy"
  role   = aws_iam_role.cognito_sns_role.id
  policy = data.aws_iam_policy_document.sns_publish_policy_doc.json
}

resource "aws_cognito_user_pool" "user_pool" {
  name             = "client-users"
  alias_attributes = ["preferred_username", "email"]
  mfa_configuration = "OPTIONAL"

  account_recovery_setting {
    recovery_mechanism {
      name     = "verified_email"
      priority = 1
    }
    recovery_mechanism {
      name     = "verified_phone_number"
      priority = 2
    }
  }

  admin_create_user_config {
    allow_admin_create_user_only = false
    invite_message_template {
      email_message = "You are attempting to create a new account. Your username is {username} and your temporary password is {####}."
      email_subject = "Resume Optimizer - Account Intialization"
      sms_message   = "You are attempting to create a new account for Resume Optimizer. Your username is {username} and your temporary login code is {####}."
    }
  }

  auto_verified_attributes = ["email"]
  user_attribute_update_settings {
    attributes_require_verification_before_update = ["email"]
  }

  email_configuration {
    email_sending_account = "COGNITO_DEFAULT"
  }

  sms_configuration {
    external_id    = var.SNS_external_ID
    sns_caller_arn = aws_iam_role.cognito_sns_role.arn
  }
}

resource "aws_cognito_user_pool_domain" "user_pool_domain" {
  domain       = "resume-optimizer-domain"
  user_pool_id = aws_cognito_user_pool.user_pool.id
}

resource "aws_cognito_user_pool_client" "user_pool_client" {
  name                                 = "resume-optimizer-client"
  user_pool_id                         = aws_cognito_user_pool.user_pool.id
  allowed_oauth_flows_user_pool_client = true
  callback_urls = [
    "https://${var.cloudfront_domain_name}/callback"
  ]
  allowed_oauth_flows        = ["code"]
  allowed_oauth_scopes       = ["openid", "email", "phone"]
  supported_identity_providers = ["COGNITO"]
  generate_secret              = false
}