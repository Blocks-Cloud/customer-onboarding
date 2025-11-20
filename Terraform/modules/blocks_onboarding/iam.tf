########################################
# IAM Role - Cross-Account Access.     #
########################################

data "aws_iam_policy_document" "blocks_read_role" {
  statement {
    effect = "Allow"
    principals {
      type        = "AWS"
      identifiers = ["arn:aws:iam::${var.blocks_external_account_id}:root"]
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
  name                 = "${data.aws_caller_identity.current.account_id}-Blocks-read-role"
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

data "aws_iam_policy_document" "cur_s3_read" {
  statement {
    sid    = "ListCurPrefix"
    effect = "Allow"
    actions = [
      "s3:ListBucket"
    ]
    resources = ["arn:aws:s3:::${local.blocks_resource_name}"]
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
    resources = ["arn:aws:s3:::${local.blocks_resource_name}/cur2/*"]
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
  role   = aws_iam_role.blocks_read_role.id
  policy = data.aws_iam_policy_document.cur_s3_read.json
}

data "aws_iam_policy_document" "cost_reservations_read_only" {
  statement {
    sid    = "CostReadOnly"
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

  statement {
    sid    = "StsWhoami"
    effect = "Allow"
    actions = [
      "sts:GetCallerIdentity"
    ]
    resources = ["*"]
  }
}

resource "aws_iam_role_policy" "cost_reservations_read_only" {
  name   = "${data.aws_caller_identity.current.account_id}-CostAndReservationsReadPolicy"
  role   = aws_iam_role.blocks_read_role.id
  policy = data.aws_iam_policy_document.cost_reservations_read_only.json
}

data "aws_iam_policy_document" "savings_estimations_read_only" {
  statement {
    sid    = "Ec2ReadOnly"
    effect = "Allow"
    actions = [
      "ec2:Describe*",
      "ec2:Get*",
      "ec2:List*",
      "dlm:Get*",
      "elasticloadbalancing:Describe*",
      "autoscaling:Describe*",
      "autoscaling:Get*",
      "autoscaling:List*"
    ]
    resources = ["*"]
  }

  statement {
    sid    = "LambdaReadOnly"
    effect = "Allow"
    actions = [
      "lambda:List*",
      "lambda:Get*"
    ]
    resources = ["*"]
  }

  statement {
    sid    = "ElastiCEcsEksEcrReadOnlycheReadOnly"
    effect = "Allow"
    actions = [
      "ecs:List*",
      "ecs:Describe*",
      "eks:List*",
      "eks:Describe*",
      "ecr:DescribeRepositories",
      "ecr:ListImages",
      "ecr:DescribeImages"
    ]
    resources = ["*"]
  }

  statement {
    sid    = "RdsReadOnly"
    effect = "Allow"
    actions = [
      "rds:Describe*",
      "rds:List*"
    ]
    resources = ["*"]
  }

  statement {
    sid    = "DynamoDbReadOnly"
    effect = "Allow"
    actions = [
      "dynamodb:List*",
      "dynamodb:Describe*"
    ]
    resources = ["*"]
  }

  statement {
    sid    = "DynamoDBAcceleratorReadOnly"
    effect = "Allow"
    actions = [
      "dax:DescribeClusters",
      "dax:ListTags",
      "dax:DescribeDefaultParameters",
      "dax:DescribeParameters"
    ]
    resources = ["*"]
  }

  statement {
    sid    = "RedshiftReadOnly"
    effect = "Allow"
    actions = [
      "redshift:Describe*",
      "redshift:Get*",
      "redshift:List*"
    ]
    resources = ["*"]
  }

  statement {
    sid    = "RedshiftServerlessReadOnly"
    effect = "Allow"
    actions = [
      "redshift-serverless:Describe*",
      "redshift-serverless:List*"
    ]
    resources = ["*"]
  }

  statement {
    sid    = "MemoryDBReadOnly"
    effect = "Allow"
    actions = [
      "memorydb:Describe*",
      "memorydb:List*",
      "memorydb:ListTags"
    ]
    resources = ["*"]
  }

  statement {
    sid    = "AuroraDSQLReadOnly"
    effect = "Allow"
    actions = [
      "dsql:Get*",
      "dsql:List*"
    ]
    resources = ["*"]
  }

  statement {
    sid    = "TimeStreamReadOnly"
    effect = "Allow"
    actions = [
      "timestream:ListDatabases",
      "timestream:ListTables",
      "timestream:DescribeDatabase",
      "timestream:DescribeTable",
      "timestream:ListTagsForResource",
      "timestream-influxdb:Get*",
      "timestream-influxdb:List*"
    ]
    resources = ["*"]
  }
  statement {
    sid    = "TrustedAdvisorReadOnly"
    effect = "Allow"
    actions = [
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

  statement {
    sid    = "ElastiCacheReadOnly"
    effect = "Allow"
    actions = [
      "elasticache:Describe*",
      "elasticache:List*"
    ]
    resources = ["*"]
  }

  statement {
    sid    = "S3ReadOnly"
    effect = "Allow"
    actions = [
      "s3:List*",
      "s3vectors:ListVectorBuckets",
      "s3:GetLifecycleConfiguration",
      "s3:GetBucketLocation",
      "s3:GetObjectRetention",
      "s3:GetBucketTagging"
    ]
    resources = ["*"]
  }

  statement {
    sid    = "CloudWatchReadOnly"
    effect = "Allow"
    actions = [
      "cloudwatch:Describe*",
      "cloudwatch:Get*",
      "cloudwatch:List*",
      "oam:ListSinks",
      "logs:Describe*",
      "logs:Get*",
      "logs:List*"
    ]
    resources = ["*"]
  }

  statement {
    sid    = "BackupReadOnly"
    effect = "Allow"
    actions = [
      "backup:Describe*",
      "backup:Get*",
      "backup:List*"
    ]
    resources = ["*"]
  }

  statement {
    sid    = "AppAutoScalingReadOnly"
    effect = "Allow"
    actions = [
      "application-autoscaling:Describe*",
      "application-autoscaling:List*",
      "application-autoscaling:Get*",
      "autoscaling-plans:Describe*",
      "autoscaling-plans:Get*"
    ]
    resources = ["*"]
  }

  statement {
    sid     = "ApiGwReadOnly"
    effect  = "Allow"
    actions = ["apigateway:GET"]
    resources = ["*"]
  }

  statement {
    sid    = "ElasticSearchReadOnly"
    effect = "Allow"
    actions = [
      "es:Describe*",
      "es:List*",
      "es:Get*"
    ]
    resources = ["*"]
  }

  statement {
    sid     = "WorkSpacesReadOnly"
    effect  = "Allow"
    actions = ["workspaces:Describe*"]
    resources = ["*"]
  }

  statement {
    sid    = "FsxReadOnly"
    effect = "Allow"
    actions = [
      "fsx:Describe*",
      "fsx:List*"
    ]
    resources = ["*"]
  }

  statement {
    sid    = "EfsReadOnly"
    effect = "Allow"
    actions = [
      "elasticfilesystem:Describe*",
      "elasticfilesystem:List*"
    ]
    resources = ["*"]
  }

  statement {
    sid    = "AppstreamReadOnly"
    effect = "Allow"
    actions = [
      "appstream:Describe*",
      "appstream:List*"
    ]
    resources = ["*"]
  }

  statement {
    sid    = "EmrReadOnly"
    effect = "Allow"
    actions = [
      "elasticmapreduce:Describe*",
      "elasticmapreduce:List*"
    ]
    resources = ["*"]
  }
  
  statement {
    sid    = "SageMakerReadOnly"
    effect = "Allow"
    actions = [
      "sagemaker:Describe*",
      "sagemaker:List*",
      "sagemaker:Search"
    ]
    resources = ["*"]
  }

  statement {
    sid    = "GlueReadOnly"
    effect = "Allow"
    actions = [
      "Glue:Get*",
      "Glue:List*"
    ]
    resources = ["*"]
  }

  statement {
    sid    = "BedrockReadOnly"
    effect = "Allow"
    actions = [
      "bedrock:GetProvisionedModelThroughput",
      "bedrock:ListProvisionedModelThroughputs"
    ]
    resources = ["*"]
  }

  statement {
    sid    = "CloudFrontReadOnly"
    effect = "Allow"
    actions = [
      "cloudfront:Get*",
      "cloudfront:List*"
    ]
    resources = ["*"]
  }

  statement {
    sid    = "ApprunnerReadOnly"
    effect = "Allow"
    actions = [
      "apprunner:ListServices",
      "apprunner:DescribeService",
      "apprunner:ListAutoScalingConfigurations",
      "apprunner:DescribeAutoScalingConfiguration",
      "apprunner:ListTagsForResource"
    ]
    resources = ["*"]
  }

  statement {
    sid    = "BatchReadOnly"
    effect = "Allow"
    actions = [
      "batch:Get*",
      "batch:List*"
    ]
    resources = ["*"]
  }

  statement {
    sid    = "CodeBuildReadOnly"
    effect = "Allow"
    actions = [
      "codebuild:ListProjects",
      "codebuild:BatchGetProjects",
      "codebuild:ListBuilds",
      "codebuild:ListBuildsForProject",
      "codebuild:ListTagsForResource"
    ]
    resources = ["*"]
  }

  statement {
    sid    = "CodePipelineReadOnly"
    effect = "Allow"
    actions = [
      "codepipeline:GetPipeline",
      "codepipeline:ListPipelines",
      "codepipeline:ListTagsForResource"
    ]
    resources = ["*"]
  }

  statement {
    sid    = "KinesisReadOnly"
    effect = "Allow"
    actions = [
      "kinesis:ListShards",
      "kinesis:ListStreamConsumers",
      "kinesis:ListStreams",
      "kinesis:DescribeLimits",
      "kinesis:DescribeStreamConsumer",
      "kinesis:DescribeStreamSummary",
      "kinesis:ListTagsForResource"
    ]
    resources = ["*"]
  }

  statement {
    sid    = "KinesisAnalyticsReadOnly"
    effect = "Allow"
    actions = [
      "kinesisanalytics:ListApplications",
      "kinesisanalytics:DescribeApplication",
      "kinesisanalytics:ListTagsForResource"
    ]
    resources = ["*"]
  }

  statement {
    sid    = "FirhoseReadOnly"
    effect = "Allow"
    actions = [
      "firehose:ListDeliveryStreams",
      "firehose:DescribeDeliveryStream",
      "firehose:ListTagsForDeliveryStream"
    ]
    resources = ["*"]
  }

  statement {
    sid    = "GrafanaReadOnly"
    effect = "Allow"
    actions = [
      "grafana:ListWorkspaces",
      "grafana:DescribeWorkspace",
      "grafana:DescribeWorkspaceConfiguration",
      "grafana:ListTagsForResource"
    ]
    resources = ["*"]
  }

  statement {
    sid    = "AirflowReadOnly"
    effect = "Allow"
    actions = [
      "airflow:ListEnvironments",
      "airflow:GetEnvironment",
      "airflow:ListTagsForResource"
    ]
    resources = ["*"]
  }

  statement {
    sid    = "NeptuneReadOnly"
    effect = "Allow"
    actions = [
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
    sid    = "WafReadOnly"
    effect = "Allow"
    actions = [
      "wafv2:ListWebACLs",
      "wafv2:GetWebACL",
      "wafv2:GetWebACLForResource",
      "wafv2:ListResourcesForWebACL",
      "wafv2:ListTagsForResource"
    ]
    resources = ["*"]
  }
}


resource "aws_iam_role_policy" "savings_estimations_read_only" {
  name = "${data.aws_caller_identity.current.account_id}-SavingsEstimationReadOnlyPolicy"
  role   = aws_iam_role.blocks_read_role.id
  policy = data.aws_iam_policy_document.savings_estimations_read_only.json
}
