########################################
# IAM Role - Cross-Account Access.     #
########################################

data "aws_iam_policy_document" "blocks_read_role" {
  statement {
    effect = "Allow"
    principals {
      type        = "AWS"
      identifiers = ["arn:aws:iam::${var.blocks_external_account_id}:role/BlocksCustomerAccessRole"]
    }
    actions = ["sts:AssumeRole"]
    condition {
      test     = "StringEquals"
      variable = "sts:ExternalId"
      values   = [var.external_id]
    }
  }
}

resource "aws_iam_role" "blocks_read_role" {
  name                 = "BlocksReadRole"
  max_session_duration = 3600
  assume_role_policy   = data.aws_iam_policy_document.blocks_read_role.json
  tags                 = local.common_tags
}

resource "aws_iam_role_policy_attachment" "blocks_read_role" {
  for_each = toset([
    "arn:aws:iam::aws:policy/ComputeOptimizerReadOnlyAccess",
    "arn:aws:iam::aws:policy/AWSOrganizationsReadOnlyAccess",
    "arn:aws:iam::aws:policy/AWSSavingsPlansReadOnlyAccess",
    "arn:aws:iam::aws:policy/AWSResourceGroupsReadOnlyAccess"
  ])
  role       = aws_iam_role.blocks_read_role.name
  policy_arn = each.value
}

data "aws_iam_policy_document" "cost_reservations_read_only" {
  statement {
    sid    = "CostAndUsageReadOnly"
    effect = "Allow"
    actions = [
      "ce:Get*",
      "ce:List*",
      "ce:Describe*",
      "cost-optimization-hub:Get*",
      "cost-optimization-hub:List*",
      "cur:Get*",
      "cur:DescribeReportDefinitions",
      "bcm-data-exports:GetExport",
      "bcm-data-exports:ListExports"
    ]
    resources = ["*"]
  }

  statement {
    sid    = "PpaAndCreditsCheck"
    effect = "Allow"
    actions = [
      "billing:GetBillingData",
      "billing:GetBillingDetails",
      "billing:GetCredits"
    ]
    resources = ["*"]
  }

  statement {
    sid    = "ReservationsReadOnly"
    effect = "Allow"
    actions = [
      "elasticache:DescribeReserved*",
      "redshift:DescribeReserved*",
      "rds:DescribeReserved*",
      "ec2:DescribeReserved*"
    ]
    resources = ["*"]
  }


}

resource "aws_iam_role_policy" "cost_reservations_read_only" {
  name   = "BlocksCostAndReservationsReadPolicy"
  role   = aws_iam_role.blocks_read_role.id
  policy = data.aws_iam_policy_document.cost_reservations_read_only.json
}

data "aws_iam_policy_document" "savings_estimations_read_only" {
  statement {
    sid    = "ComputeAndScalingReadOnly"
    effect = "Allow"
    actions = [
      "ec2:Describe*",
      "ec2:Get*",
      "ec2:List*",
      "dlm:Get*",
      "elasticloadbalancing:Describe*",
      "autoscaling:Describe*",
      "autoscaling:Get*",
      "autoscaling:List*",
      "application-autoscaling:Describe*",
      "application-autoscaling:List*",
      "application-autoscaling:Get*",
      "autoscaling-plans:Describe*",
      "autoscaling-plans:Get*",
      "lambda:List*",
      "lambda:Get*",
      "batch:Get*",
      "batch:List*",
      "apprunner:ListServices",
      "apprunner:DescribeService",
      "apprunner:ListAutoScalingConfigurations",
      "apprunner:DescribeAutoScalingConfiguration",
      "apprunner:ListTagsForResource"
    ]
    resources = ["*"]
  }

  statement {
    sid    = "ContainersAndBuildReadOnly"
    effect = "Allow"
    actions = [
      "ecs:List*",
      "ecs:Describe*",
      "eks:List*",
      "eks:Describe*",
      "ecr:DescribeRepositories",
      "ecr:ListImages",
      "ecr:DescribeImages",
      "codebuild:ListProjects",
      "codebuild:BatchGetProjects",
      "codebuild:ListBuilds",
      "codebuild:ListBuildsForProject",
      "codebuild:ListTagsForResource",
      "codepipeline:GetPipeline",
      "codepipeline:ListPipelines",
      "codepipeline:ListTagsForResource"
    ]
    resources = ["*"]
  }

  statement {
    sid    = "DatabasesAndCachingReadOnly"
    effect = "Allow"
    actions = [
      "rds:Describe*",
      "rds:List*",
      "dynamodb:List*",
      "dynamodb:Describe*",
      "dax:DescribeClusters",
      "dax:ListTags",
      "dax:DescribeDefaultParameters",
      "dax:DescribeParameters",
      "redshift:Describe*",
      "redshift:Get*",
      "redshift:List*",
      "redshift-serverless:Describe*",
      "redshift-serverless:List*",
      "elasticache:Describe*",
      "elasticache:List*",
      "memorydb:Describe*",
      "memorydb:List*",
      "memorydb:ListTags",
      "dsql:Get*",
      "dsql:List*",
      "neptune:DescribeDBClusters",
      "neptune:DescribeDBInstances",
      "neptune:DescribeDBClusterSnapshots",
      "neptune:DescribeDBParameterGroups",
      "neptune:DescribeDBClusterParameterGroups",
      "neptune:ListTagsForResource",
      "neptune-graph:GetEngineStatus",
      "neptune-graph:GetGraphSummary",
      "neptune-db:GetEngineStatus",
      "neptune-db:GetGraphSummary"
    ]
    resources = ["*"]
  }

  statement {
    sid    = "StreamingAndAnalyticsReadOnly"
    effect = "Allow"
    actions = [
      "timestream:List*",
      "timestream:Describe*",
      "timestream:ListTagsForResource",
      "timestream-influxdb:Get*",
      "timestream-influxdb:List*",
      "kinesis:ListShards",
      "kinesis:ListStreamConsumers",
      "kinesis:ListStreams",
      "kinesis:DescribeLimits",
      "kinesis:DescribeStreamConsumer",
      "kinesis:DescribeStreamSummary",
      "kinesis:ListTagsForResource",
      "kinesisanalytics:ListApplications",
      "kinesisanalytics:DescribeApplication",
      "kinesisanalytics:ListTagsForResource",
      "firehose:ListDeliveryStreams",
      "firehose:DescribeDeliveryStream",
      "firehose:ListTagsForDeliveryStream"
    ]
    resources = ["*"]
  }

  statement {
    sid    = "DataPlatformsAndAiReadOnly"
    effect = "Allow"
    actions = [
      "sagemaker:Describe*",
      "sagemaker:List*",
      "sagemaker:Search",
      "Glue:Get*",
      "Glue:List*",
      "bedrock:GetProvisionedModelThroughput",
      "bedrock:ListProvisionedModelThroughputs",
      "airflow:ListEnvironments",
      "airflow:GetEnvironment",
      "airflow:ListTagsForResource"
    ]
    resources = ["*"]
  }

  statement {
    sid    = "StorageAndContentReadOnly"
    effect = "Allow"
    actions = [
      "s3:List*",
      "s3vectors:ListVectorBuckets",
      "s3:GetLifecycleConfiguration",
      "s3:GetBucketLocation",
      "s3:GetObjectRetention",
      "s3:GetBucketTagging",
      "fsx:Describe*",
      "fsx:List*",
      "elasticfilesystem:Describe*",
      "elasticfilesystem:List*",
      "backup:Describe*",
      "backup:Get*",
      "backup:List*"
    ]
    resources = ["*"]
  }

  statement {
    sid    = "NetworkAndEdgeReadOnly"
    effect = "Allow"
    actions = [
      "apigateway:GET",
      "es:Describe*",
      "es:List*",
      "es:Get*",
      "wafv2:ListWebACLs",
      "wafv2:GetWebACL",
      "wafv2:GetWebACLForResource",
      "wafv2:ListResourcesForWebACL",
      "wafv2:ListTagsForResource",
      "cloudfront:Get*",
      "cloudfront:List*"
    ]
    resources = ["*"]
  }

  statement {
    sid    = "EndUserServicesReadOnly"
    effect = "Allow"
    actions = [
      "workspaces:Describe*",
      "appstream:Describe*",
      "appstream:List*"
    ]
    resources = ["*"]
  }

  statement {
    sid    = "ObservabilityAndAdvisoryReadOnly"
    effect = "Allow"
    actions = [
      "cloudwatch:Describe*",
      "cloudwatch:Get*",
      "cloudwatch:List*",
      "oam:ListSinks",
      "logs:Describe*",
      "logs:Get*",
      "logs:List*",
      "grafana:ListWorkspaces",
      "grafana:DescribeWorkspace",
      "grafana:DescribeWorkspaceConfiguration",
      "grafana:ListTagsForResource",
      "trustedadvisor:Describe*",
      "trustedadvisor:Get*",
      "trustedadvisor:List*",
      "support:DescribeTrustedAdvisorChecks",
      "support:DescribeTrustedAdvisorCheckResult",
      "support:DescribeTrustedAdvisorCheckSummaries",
      "support:DescribeTrustedAdvisorCheckRefreshStatuses",
      "support:RefreshTrustedAdvisorCheck"
    ]
    resources = ["*"]
  }
}


resource "aws_iam_role_policy" "savings_estimations_read_only" {
  name   = "BlocksSavingsEstimationReadOnlyPolicy"
  role   = aws_iam_role.blocks_read_role.id
  policy = data.aws_iam_policy_document.savings_estimations_read_only.json
}

########################################
# Backfill Support Case Role           #
########################################

data "aws_iam_policy_document" "create_backfill_support_case_assume_role" {
  statement {
    effect = "Allow"
    principals {
      type        = "AWS"
      identifiers = ["arn:aws:iam::${var.blocks_external_account_id}:role/BlocksCustomerAccessRole"]
    }
    actions = ["sts:AssumeRole"]
  }
}

resource "aws_iam_role" "create_backfill_support_case" {
  name                 = "CreateBackfillSupportCaseRole"
  description          = "Used by Blocks.cloud to create a support case to backfill CUR 2.0 data"
  max_session_duration = 3600
  assume_role_policy   = data.aws_iam_policy_document.create_backfill_support_case_assume_role.json
  tags                 = local.common_tags
}

data "aws_iam_policy_document" "create_backfill_support_case_permissions" {
  statement {
    effect = "Allow"
    actions = [
      "support:CreateCase",
      "support:DescribeCases",
      "support:DescribeServices",
      "support:DescribeCommunications",
      "support:DescribeSeverityLevels",
      "support:DescribeCreateCaseOptions"
    ]
    resources = ["*"]
  }

  statement {
    sid       = "DenyAfterExpiryDate"
    effect    = "Deny"
    actions   = ["*"]
    resources = ["*"]
    condition {
      test     = "DateGreaterThan"
      variable = "aws:CurrentTime"
      values   = ["2026-03-31T23:59:59Z"]
    }
  }
}

resource "aws_iam_role_policy" "create_backfill_support_case_permissions" {
  name   = "CreateBackfillSupportCasePermissions"
  role   = aws_iam_role.create_backfill_support_case.id
  policy = data.aws_iam_policy_document.create_backfill_support_case_permissions.json
}

