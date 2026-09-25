############################
# Organizational Unit for Blocks Optimization
############################

resource "aws_organizations_organizational_unit" "blocks_optimization" {
  count = local.is_management_account ? 1 : 0

  name      = "BlocksOptimization-${var.customer_resource_id}"
  parent_id = local.organization_root_id

  tags = merge(local.common_tags, {
    Purpose   = "CostOptimization"
    ManagedBy = "Terraform"
  })
}

############################
# Service Control Policy - Savings Plans Restriction
############################

# Timing barrier - ensures SCP policy type is fully propagated before creating policy
resource "terraform_data" "scp_policy_type_ready" {
  count = local.is_management_account ? 1 : 0

  depends_on = [terraform_data.enable_org_services[0]]

  provisioner "local-exec" {
    command = "echo 'Waiting for SCP policy type propagation...' && sleep 10"
  }
}

# Policy Document
data "aws_iam_policy_document" "savings_plans_deny" {
  # Deny if NOT using BlocksExecutionRole (regardless of OU)
  statement {
    sid    = "DenySavingsPlansIfNotUsingBlocksRole"
    effect = "Deny"

    actions = [
      "savingsplans:CreateSavingsPlan",
      "savingsplans:DeleteQueuedSavingsPlan",
      "savingsplans:ReturnSavingsPlan",
      "savingsplans:TagResource",
      "savingsplans:UntagResource"
    ]

    resources = ["*"]

    condition {
      test     = "ArnNotLike"
      variable = "aws:PrincipalArn"
      values   = ["arn:${local.partition}:iam::*:role/BlocksExecutionRole-${var.customer_resource_id}"]
    }
  }

  # Deny if NOT in BlocksOptimization OU (regardless of role)
  statement {
    sid    = "DenySavingsPlansIfNotInBlocksOU"
    effect = "Deny"

    actions = [
      "savingsplans:CreateSavingsPlan",
      "savingsplans:DeleteQueuedSavingsPlan",
      "savingsplans:ReturnSavingsPlan",
      "savingsplans:TagResource",
      "savingsplans:UntagResource"
    ]

    resources = ["*"]

    condition {
      test     = "ForAllValues:StringNotLike"
      variable = "aws:PrincipalOrgPaths"
      values = [
        "o-*/r-*/${aws_organizations_organizational_unit.blocks_optimization[0].id}/*",
        "o-*/r-*/${aws_organizations_organizational_unit.blocks_optimization[0].id}/"
      ]
    }
  }
}

# SCP Resource
resource "aws_organizations_policy" "savings_plans_deny" {
  count = local.is_management_account ? 1 : 0

  name        = "BlocksSavingsPlansDenyPolicy-${var.customer_resource_id}"
  description = "Denies Savings Plans write operations except BlocksExecutionRole and accounts in BlocksOptimization OU. Must remain in place for Blocks to function correctly."
  type        = "SERVICE_CONTROL_POLICY"
  content     = data.aws_iam_policy_document.savings_plans_deny.json

  tags = merge(local.common_tags, {
    Purpose = "SecurityControl"
  })

  # Ensure SCP policy type is enabled, propagated, and OU exists before creating policy
  depends_on = [
    terraform_data.scp_policy_type_ready,
    aws_organizations_organizational_unit.blocks_optimization
  ]
}

# SCP Attachment to Organization Root (applies to all accounts)
resource "aws_organizations_policy_attachment" "savings_plans_deny_root" {
  count = local.is_management_account ? 1 : 0

  policy_id = aws_organizations_policy.savings_plans_deny[0].id
  target_id = local.organization_root_id

  depends_on = [aws_organizations_organizational_unit.blocks_optimization]
}

############################
# Enhanced Governance SCP - BlocksOptimization OU
############################

# Complete lockdown policy - denies resource creation and org actions
# BlocksExecutionRole, AWS service-linked roles, and BlocksPoolAccountTransferRole exempted
# Service-linked roles retain IAM operation access only
data "aws_iam_policy_document" "blocks_governance_deny" {
  # Critical governance controls
  statement {
    sid    = "DenyOrgAndAccountActions"
    effect = "Deny"
    actions = [
      "organizations:LeaveOrganization",
      "organizations:RemoveAccountFromOrganization",
      "account:CloseAccount",
      "account:EnableRegion",
      "account:DisableRegion",
      "iam:CreateUser",
      "iam:CreateAccessKey"
    ]
    resources = ["*"]
    condition {
      test     = "ArnNotLike"
      variable = "aws:PrincipalArn"
      values = [
        "arn:${local.partition}:iam::*:role/BlocksExecutionRole-${var.customer_resource_id}",
        "arn:${local.partition}:iam::*:role/aws-service-role/*",
        "arn:${local.partition}:iam::*:role/BlocksPoolAccountTransferRole"
      ]
    }
  }

  # Resource creation restrictions
  statement {
    sid    = "DenyResourceCreation"
    effect = "Deny"
    actions = [
      "ec2:RunInstances",
      "ec2:CreateVpc",
      "ec2:CreateSubnet",
      "ec2:CreateVolume",
      "ec2:CreateSecurityGroup",
      "lambda:CreateFunction",
      "rds:CreateDBInstance",
      "rds:CreateDBCluster",
      "dynamodb:CreateTable",
      "ecs:CreateCluster",
      "eks:CreateCluster",
      "cloudwatch:PutMetricAlarm",
      "sns:CreateTopic",
      "sqs:CreateQueue"
    ]
    resources = ["*"]
    condition {
      test     = "ArnNotLike"
      variable = "aws:PrincipalArn"
      values = [
        "arn:${local.partition}:iam::*:role/BlocksExecutionRole-${var.customer_resource_id}"
      ]
    }
  }

  # S3 bucket creation with CUR bucket exception
  statement {
    sid    = "DenyS3BucketCreationExceptCUR"
    effect = "Deny"
    actions = [
      "s3:CreateBucket"
    ]
    resources = ["*"]
    condition {
      test     = "ArnNotLike"
      variable = "aws:PrincipalArn"
      values = [
        "arn:${local.partition}:iam::*:role/BlocksExecutionRole-${var.customer_resource_id}"
      ]
    }
    condition {
      test     = "ArnNotLike"
      variable = "aws:ResourceArn"
      values = [
        "arn:aws:s3:::blocks-cur-data-*"
      ]
    }
  }

  # Security service protection
  statement {
    sid    = "DenySecurityTampering"
    effect = "Deny"
    actions = [
      "guardduty:DeleteDetector",
      "config:DeleteConfigRule",
      "config:StopConfigurationRecorder",
      "cloudtrail:DeleteTrail",
      "cloudtrail:StopLogging",
      "securityhub:DisableSecurityHub"
    ]
    resources = ["*"]
    condition {
      test     = "ArnNotLike"
      variable = "aws:PrincipalArn"
      values = [
        "arn:${local.partition}:iam::*:role/BlocksExecutionRole-${var.customer_resource_id}"
      ]
    }
  }
}

# SCP Resource
resource "aws_organizations_policy" "blocks_governance" {
  count = local.is_management_account ? 1 : 0

  name        = "BlocksGovernanceDenyPolicy-${var.customer_resource_id}"
  description = "Complete account lockdown for BlocksOptimization OU. Only BlocksExecutionRole can create resources or manage IAM. AWS services and users are blocked. Managed by Blocks.cloud."
  type        = "SERVICE_CONTROL_POLICY"
  content     = data.aws_iam_policy_document.blocks_governance_deny.json

  tags = merge(local.common_tags, {
    Purpose = "GovernanceControl"
  })

  depends_on = [
    terraform_data.scp_policy_type_ready,
    aws_organizations_organizational_unit.blocks_optimization
  ]
}

# SCP Attachment to BlocksOptimization OU (NOT root!)
resource "aws_organizations_policy_attachment" "blocks_governance_ou" {
  count = local.is_management_account ? 1 : 0

  policy_id = aws_organizations_policy.blocks_governance[0].id
  target_id = aws_organizations_organizational_unit.blocks_optimization[0].id

  depends_on = [aws_organizations_organizational_unit.blocks_optimization]
}

############################
# Blocks-managed accounts
# The 4 accounts Blocks buys commitments in (3 Compute Savings Plans, 1 Database Savings
# Plan), created inside the customer org under the BlocksOptimization OU so the
# governance SCP applies from the first second. Terraform state makes this idempotent.
############################

locals {
  # name => { purpose tag, short email suffix }. AWS caps account emails at 64 chars.
  blocks_managed_accounts = {
    "Blocks-Compute-1-${var.customer_resource_id}"  = { purpose = "ComputeSavingsPlans", slug = "bc1" }
    "Blocks-Compute-2-${var.customer_resource_id}"  = { purpose = "ComputeSavingsPlans", slug = "bc2" }
    "Blocks-Compute-3-${var.customer_resource_id}"  = { purpose = "ComputeSavingsPlans", slug = "bc3" }
    "Blocks-Database-1-${var.customer_resource_id}" = { purpose = "DatabaseSavingsPlans", slug = "bd1" }
  }

  # Customer-owned root email: plus-address the management account's root email so the
  # customer receives every root mail and holds the root credentials.
  # ponytail: plus-addressing is not supported by every mail provider, and AWS caps
  # emails at 64 chars; pass managed_account_root_emails to override per account.
  mgmt_root_email_local  = split("+", split("@", data.aws_organizations_organization.current.master_account_email)[0])[0]
  mgmt_root_email_domain = split("@", data.aws_organizations_organization.current.master_account_email)[1]
  blocks_managed_account_emails = {
    for name, a in local.blocks_managed_accounts :
    name => lookup(var.managed_account_root_emails, name, "${local.mgmt_root_email_local}+${a.slug}-${lower(var.customer_resource_id)}@${local.mgmt_root_email_domain}")
  }
}

resource "aws_organizations_account" "blocks_managed" {
  for_each = local.is_management_account ? local.blocks_managed_accounts : {}

  name                       = each.key
  email                      = local.blocks_managed_account_emails[each.key]
  parent_id                  = aws_organizations_organizational_unit.blocks_optimization[0].id
  iam_user_access_to_billing = "DENY"
  # Accounts hold live commitments; a customer destroy only forgets them (they stay in the org).
  # Internal/sandbox deployments close them so CI does not leak accounts into the sandbox quota.
  close_on_deletion = var.internal

  tags = merge(local.common_tags, {
    Purpose                  = each.value.purpose
    BlocksCustomerResourceId = var.customer_resource_id
  })

  lifecycle {
    precondition {
      condition     = length(local.blocks_managed_account_emails[each.key]) <= 64
      error_message = "Root email for ${each.key} exceeds AWS's 64-character limit; set managed_account_root_emails[\"${each.key}\"]."
    }
    # AWS does not allow changing these after creation.
    ignore_changes = [email, iam_user_access_to_billing, role_name]
  }

  depends_on = [aws_organizations_policy_attachment.blocks_governance_ou]
}
