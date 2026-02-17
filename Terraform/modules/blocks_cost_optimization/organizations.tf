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

  depends_on = [terraform_data.enable_org_services]

  provisioner "local-exec" {
    command = "echo 'Waiting for SCP policy type propagation...' && sleep 10"
  }
}

# Policy Document
data "aws_iam_policy_document" "savings_plans_deny" {
  statement {
    sid    = "DenySavingsPlansWriteExceptBlocksRoleAndOU"
    effect = "Deny"

    actions = [
      "savingsplans:CreateSavingsPlan",
      "savingsplans:DeleteQueuedSavingsPlan",
      "savingsplans:ReturnSavingsPlan",
      "savingsplans:TagResource",
      "savingsplans:UntagResource"
    ]

    resources = ["*"]

    # Deny unless principal is BlocksExecutionRole OR in BlocksOptimization OU
    # Both conditions must be false for deny to apply (AND logic)
    # Result: allowed if EITHER condition matches (OR exemption)
    condition {
      test     = "ArnNotLike"
      variable = "aws:PrincipalArn"
      values   = ["arn:${local.partition}:iam::*:role/BlocksExecutionRole-${var.customer_resource_id}"]
    }

    condition {
      test     = "ForAllValues:StringNotLike"
      variable = "aws:PrincipalOrgPaths"
      values   = ["o-*/r-*/${aws_organizations_organizational_unit.blocks_optimization[0].id}/*"]
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
# Only BlocksExecutionRole exempted (service-linked roles blocked for resource creation)
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
      "iam:CreateAccessKey",
      "iam:CreateRole",
      "iam:PutRolePolicy",
      "iam:AttachRolePolicy"
    ]
    resources = ["*"]
    condition {
      test     = "ArnNotLike"
      variable = "aws:PrincipalArn"
      values = [
        "arn:${local.partition}:iam::*:role/BlocksExecutionRole-${var.customer_resource_id}",
        "arn:${local.partition}:iam::*:role/aws-service-role/*"
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
      "lambda:CreateFunction",
      "s3:CreateBucket",
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
