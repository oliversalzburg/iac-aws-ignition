data "aws_caller_identity" "current" {}
locals {
  caller_identity_friendly_name = split("/", data.aws_caller_identity.current.arn)[1]
}

# In general, we don't even want IAM users to log into the AWS web console.
# So they shouldn't even have a password to begin with.
# If a password is assigned for whatever reason, it must be strong, and only
# be valid temporarily. Thus, any assigned password auto-expires after 30 days.
resource "aws_iam_account_password_policy" "this" {
  allow_users_to_change_password = true
  hard_expiry                    = true
  max_password_age               = 30 # days
  minimum_password_length        = 16
  password_reuse_prevention      = 0
  require_lowercase_characters   = true
  require_numbers                = true
  require_symbols                = true
  require_uppercase_characters   = true
}

# Data stored in S3 is not supposed to be accessible to the public.
# If you need to make data publicly available, offload it to CloudFront.
resource "aws_s3_account_public_access_block" "this" {
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_iam_group" "everyone" {
  name = "Everyone"
  path = "/"
}
resource "aws_iam_group" "owner" {
  name = "Owners"
  path = "/"
}
resource "aws_iam_group" "administrator" {
  name = "Administrators"
  path = "/"
}
resource "aws_iam_group" "auditor" {
  name = "Auditors"
  path = "/"
}
data "aws_iam_session_context" "caller" {
  arn = data.aws_caller_identity.current.arn
}
resource "aws_iam_user_group_membership" "caller" {
  user = local.caller_identity_friendly_name
  groups = [
    aws_iam_group.everyone.name,
    aws_iam_group.owner.name,
    aws_iam_group.administrator.name,
    # The caller is NOT an auditor.
  ]
}

# From https://repost.aws/knowledge-center/mfa-iam-user-aws-cli
data "aws_iam_policy_document" "enforce_mfa" {
  policy_id = "EnforceMFA"
  statement {
    sid    = "BlockMostAccessUnlessSignedInWithMFA"
    effect = "Deny"
    not_actions = [
      "iam:CreateVirtualMFADevice",
      "iam:DeleteVirtualMFADevice",
      "iam:ListVirtualMFADevices",
      "iam:EnableMFADevice",
      "iam:ResyncMFADevice",
      "iam:ListAccountAliases",
      "iam:ListUsers",
      "iam:ListSSHPublicKeys",
      "iam:ListAccessKeys",
      "iam:ListServiceSpecificCredentials",
      "iam:ListMFADevices",
      "iam:GetAccountSummary",
      "sts:GetSessionToken"
    ]
    resources = ["*"]
    condition {
      test     = "BoolIfExists"
      values   = ["false"]
      variable = "aws:MultiFactorAuthPresent"
    }
    condition {
      test     = "BoolIfExists"
      values   = ["false"]
      variable = "aws:ViaAWSService"
    }
  }
}
resource "aws_iam_policy" "enforce_mfa" {
  description = "Forces users to have MFA enabled."
  name        = "EnforceMFA"
  policy      = data.aws_iam_policy_document.enforce_mfa.json
}
resource "aws_iam_group_policy_attachment" "enforce_mfa" {
  group      = aws_iam_group.everyone.id
  policy_arn = aws_iam_policy.enforce_mfa.arn
}

output "caller_identity" {
  value = {
    account_id = data.aws_caller_identity.current.account_id
    arn        = data.aws_caller_identity.current.arn
    id         = data.aws_caller_identity.current.id
    user_id    = data.aws_caller_identity.current.user_id
    user_name  = local.caller_identity_friendly_name
  }
}
