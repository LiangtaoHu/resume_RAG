resource "aws_cognito_user_pool" "user_pool" {
    name = "user_pool"
    username_attributes = ["preferred_username"]
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

    email_configuration {
      
    }

    email_mfa_configuration {
      message = "MFA Sign in code: {####}"
      subject = "Resume Optimizer - Sign In MFA Code"
    }

    sms_configuration {
      // Used for MFA and confirming this is your phone during SMS user verification
    }
}