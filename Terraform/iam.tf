############################
# IAM Role - Cross-Account Access
############################

data "aws_iam_policy_document" "assume_role" {
  statement {
    effect = "Allow"
    principals {
      type        = "AWS"
      identifiers = ["arn:aws:iam::${var.external_account_id}:root"]
    }
    actions = ["sts:AssumeRole"]
    condition {
      test     = "StringEquals"
      variable = "sts:ExternalId"
      values   = [var.external_id]
    }
  }
}

resource "aws_iam_role" "blocks_billing_read_role" {
  name                 = "${local.export_name}-billing-read-role"
  max_session_duration = 3600
  assume_role_policy   = data.aws_iam_policy_document.assume_role.json
  tags                 = local.common_tags
}

# Managed Policies
resource "aws_iam_role_policy_attachment" "billing_read_managed" {
  for_each = toset([
    "arn:aws:iam::aws:policy/AWSBillingReadOnlyAccess",
    "arn:aws:iam::aws:policy/AWSBudgetsReadOnlyAccess",
    "arn:aws:iam::aws:policy/ServiceQuotasReadOnlyAccess",
    "arn:aws:iam::aws:policy/ComputeOptimizerReadOnlyAccess",
    "arn:aws:iam::aws:policy/AWSOrganizationsReadOnlyAccess",
    "arn:aws:iam::aws:policy/ResourceGroupsandTagEditorReadOnlyAccess"
  ])
  role       = aws_iam_role.blocks_billing_read_role.name
  policy_arn = each.value
}

# S3 CUR Read Access
data "aws_iam_policy_document" "cur_s3_read" {
  statement {
    sid    = "ListCurPrefix"
    effect = "Allow"
    actions = [
      "s3:ListBucket"
    ]
    resources = ["arn:aws:s3:::${local.cur_bucket_name}"]
    condition {
      test     = "StringLike"
      variable = "s3:prefix"
      values   = ["cur2/*"]
    }
  }

  statement {
    sid    = "ReadCurObjects"
    effect = "Allow"
    actions = [
      "s3:GetObject"
    ]
    resources = ["arn:aws:s3:::${local.cur_bucket_name}/cur2/*"]
  }

  dynamic "statement" {
    for_each = var.kms_key_arn != "" ? [1] : []
    content {
      sid    = "CurKmsDecrypt"
      effect = "Allow"
      actions = [
        "kms:Decrypt",
        "kms:DescribeKey"
      ]
      resources = [var.kms_key_arn]
    }
  }
}

resource "aws_iam_role_policy" "cur_s3_read" {
  name   = "CurS3Read"
  role   = aws_iam_role.blocks_billing_read_role.id
  policy = data.aws_iam_policy_document.cur_s3_read.json
}

# Cost Explorer & Billing
data "aws_iam_policy_document" "billing_services" {
  statement {
    sid    = "CostExplorerRead"
    effect = "Allow"
    actions = [
      "ce:Get*",
      "ce:List*",
      "ce:Describe*"
    ]
    resources = ["*"]
  }

  statement {
    sid    = "SavingsPlansRead"
    effect = "Allow"
    actions = [
      "savingsplans:Describe*",
      "savingsplans:List*"
    ]
    resources = ["*"]
  }

  statement {
    sid    = "TrustedAdvisorRead"
    effect = "Allow"
    actions = [
      "support:DescribeTrustedAdvisorChecks",
      "support:DescribeTrustedAdvisorCheckResult",
      "support:DescribeTrustedAdvisorCheckSummaries",
      "support:DescribeTrustedAdvisorCheckRefreshStatuses",
      "support:RefreshTrustedAdvisorCheck"
    ]
    resources = ["*"]
  }

  statement {
    sid    = "PricingRead"
    effect = "Allow"
    actions = [
      "pricing:GetProducts",
      "pricing:DescribeServices",
      "pricing:GetAttributeValues"
    ]
    resources = ["*"]
  }

  statement {
    sid    = "AccountMetadata"
    effect = "Allow"
    actions = [
      "account:ListRegions",
      "account:GetAlternateContact",
      "account:GetContactInformation",
      "account:ListAlternateContacts",
      "sts:GetCallerIdentity"
    ]
    resources = ["*"]
  }
}

resource "aws_iam_role_policy" "billing_services" {
  name   = "BillingServices"
  role   = aws_iam_role.blocks_billing_read_role.id
  policy = data.aws_iam_policy_document.billing_services.json
}

# AWS Services Read Access
data "aws_iam_policy_document" "service_reads" {
  statement {
    sid    = "Compute"
    effect = "Allow"
    actions = [
      "ec2:Describe*",
      "ec2:Get*",
      "ec2:SearchTransitGatewayRoutes",
      "elasticloadbalancing:Describe*",
      "autoscaling:Describe*",
      "lambda:List*",
      "lambda:Get*"
    ]
    resources = ["*"]
  }

  statement {
    sid    = "Databases"
    effect = "Allow"
    actions = [
      "rds:Describe*",
      "rds:List*",
      "elasticache:Describe*",
      "elasticache:List*",
      "redshift:Describe*",
      "redshift:List*",
      "redshift:ViewQueriesInConsole",
      "dynamodb:List*",
      "dynamodb:Describe*"
    ]
    resources = ["*"]
  }

  statement {
    sid    = "Containers"
    effect = "Allow"
    actions = [
      "ecs:List*",
      "ecs:Describe*",
      "eks:List*",
      "eks:Describe*"
    ]
    resources = ["*"]
  }

  statement {
    sid    = "Monitoring"
    effect = "Allow"
    actions = [
      "cloudwatch:Describe*",
      "cloudwatch:Get*",
      "cloudwatch:List*",
      "logs:Describe*",
      "logs:Get*",
      "logs:List*",
      "logs:StartQuery",
      "logs:StopQuery",
      "logs:TestMetricFilter",
      "logs:FilterLogEvents"
    ]
    resources = ["*"]
  }

  statement {
    sid    = "Infrastructure"
    effect = "Allow"
    actions = [
      "cloudformation:Describe*",
      "cloudformation:List*",
      "cloudformation:Get*",
      "cloudformation:DetectStackDrift",
      "cloudformation:DetectStackResourceDrift",
      "ssm:Describe*",
      "ssm:Get*",
      "ssm:List*",
      "config:Describe*",
      "config:Get*",
      "config:List*",
      "config:Select*",
      "config:BatchGet*"
    ]
    resources = ["*"]
  }

  // candidate to be removed
  statement {
    sid    = "Networking"
    effect = "Allow"
    actions = [
      "cloudfront:Get*",
      "cloudfront:List*",
      "route53:Get*",
      "route53:List*",
      "route53domains:Get*",
      "route53domains:List*",
      "directconnect:Describe*"
    ]
    resources = ["*"]
  }

  statement {
    sid    = "Storage"
    effect = "Allow"
    actions = [
      "elasticfilesystem:Describe*",
      "elasticfilesystem:List*",
      "fsx:Describe*",
      "fsx:List*",
      "storagegateway:Describe*",
      "storagegateway:List*",
      "backup:Describe*",
      "backup:Get*",
      "backup:List*"
    ]
    resources = ["*"]
  }

  statement {
    sid    = "Analytics"
    effect = "Allow"
    actions = [
      "glue:Get*",
      "glue:List*",
      "glue:BatchGet*",
      "athena:Get*",
      "athena:List*",
      "athena:BatchGet*",
      "elasticmapreduce:Describe*",
      "elasticmapreduce:List*",
      "elasticmapreduce:View*",
      "elasticmapreduce:Get*",
      "kinesis:Describe*",
      "kinesis:List*",
      "firehose:Describe*",
      "firehose:List*",
      "kinesisanalytics:Describe*",
      "kinesisanalytics:List*"
    ]
    resources = ["*"]
  }

  statement {
    sid    = "MachineLearning"
    effect = "Allow"
    actions = [
      "sagemaker:Describe*",
      "sagemaker:List*",
      "sagemaker:Get*",
      "es:Describe*",
      "es:List*",
      "es:Get*"
    ]
    resources = ["*"]
  }

  statement {
    sid    = "Applications"
    effect = "Allow"
    actions = [
      "apigateway:Get",
      "states:Describe*",
      "states:List*",
      "states:Get*",
      "elasticbeanstalk:Describe*",
      "elasticbeanstalk:List*",
      "sns:Get*",
      "sns:List*",
      "sqs:Get*",
      "sqs:List*"
    ]
    resources = ["*"]
  }

  // candidate to be removed
  statement {
    sid    = "EndUserComputing"
    effect = "Allow"
    actions = [
      "workspaces:Describe*",
      "appstream:Describe*",
      "appstream:List*"
    ]
    resources = ["*"]
  }

  statement {
    sid    = "MiscServices"
    effect = "Allow"
    actions = [
      "license-manager:Get*",
      "license-manager:List*",
      "health:Describe*",
      "application-autoscaling:Describe*",
      "transfer:Describe*",
      "transfer:List*"
    ]
    resources = ["*"]
  }
}

resource "aws_iam_role_policy" "service_reads" {
  name   = "AWSServiceReads"
  role   = aws_iam_role.blocks_billing_read_role.id
  policy = data.aws_iam_policy_document.service_reads.json
}
