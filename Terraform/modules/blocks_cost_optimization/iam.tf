############################
# IAM Policies - Step 2 Cost Optimization
############################

############################
# Cross-Account Trust Policy (Shared)
############################

data "aws_iam_policy_document" "blocks_cross_account_trust" {
  statement {
    effect = "Allow"
    principals {
      type        = "AWS"
      identifiers = [local.blocks_customer_access_role_arn]
    }
    actions = ["sts:AssumeRole"]
    condition {
      test     = "StringEquals"
      variable = "sts:ExternalId"
      values   = [var.external_id]
    }
  }
  statement {
    effect = "Allow"
    principals {
      type        = "AWS"
      identifiers = [local.blocks_customer_access_role_arn]
    }
    actions = ["sts:TagSession"]
  }
}

############################
# BlocksCostOptimizationWritePolicy
############################

# ==== BEGIN GENERATED IAM POLICIES ====
# Source: iam-policies/policies/
# DO NOT EDIT MANUALLY

############################
# BlocksCostOptimizationWritePolicy
############################

# IAM Policy: Cost Optimization Write Permissions
# Grants Blocks execution permissions for purchasing RIs/Savings Plans,
# managing budgets, alarms, Cost Optimization Hub enrollment, and AWS Organizations management
data "aws_iam_policy_document" "blocks_cost_optimization_write" {
  # Reserved Instance Purchases - Allows purchasing, modifying, and exchanging RIs
  # Services: EC2, RDS, ElastiCache, Redshift, OpenSearch, MemoryDB, DynamoDB, CloudFront, MediaConvert, MediaConnect, SageMaker
  statement {
    sid    = "SavingsPlansAndRIsWrite"
    effect = "Allow"
    actions = [
      "ec2:PurchaseReservedInstancesOffering",
      "ec2:ModifyReservedInstances",
      "ec2:AcceptReservedInstancesExchangeQuote",
      "ec2:DeleteQueuedReservedInstances",
      "ec2:PurchaseHostReservation",
      "rds:PurchaseReservedDBInstancesOffering",
      "elasticache:PurchaseReservedCacheNodesOffering",
      "redshift:PurchaseReservedNodeOffering",
      "redshift:AcceptReservedNodeExchange",
      "es:PurchaseReservedInstanceOffering",
      "memorydb:PurchaseReservedNodesOffering",
      "dynamodb:PurchaseReservedCapacityOfferings",
      "cloudfront:CreateSavingsPlan",
      "ec2:PurchaseCapacityBlock",
      "mediaconvert:CreateQueue",
      "mediaconvert:UpdateQueue",
      "mediaconnect:PurchaseOffering",
      "sagemaker:CreateTrainingPlan",
    ]
    resources = [
      "*",
    ]
  }

  # Organization Management - Manage organization structure and service integrations
  # Services: Organizations
  statement {
    sid    = "OrgManagementWrite"
    effect = "Allow"
    actions = [
      "organizations:MoveAccount",
      "organizations:TagResource",
      "organizations:UntagResource",
      "organizations:AcceptHandshake",
      "organizations:EnableAWSServiceAccess",
      "organizations:CreateOrganizationalUnit",
      "organizations:ListRoots",
      "organizations:ListOrganizationalUnitsForParent",
      "organizations:ListParents",
    ]
    resources = [
      "*",
    ]
  }

  # Account Transfer - Required for commitment service to move accounts between organizations
  # Services: Organizations
  statement {
    sid    = "AccountTransferOperations"
    effect = "Allow"
    actions = [
      "organizations:InviteAccountToOrganization",
      "organizations:DescribeHandshake",
      "organizations:ListHandshakesForOrganization",
      "organizations:CancelHandshake",
      "organizations:DescribeOrganization",
    ]
    resources = [
      "*",
    ]
  }

  # Governance & Monitoring - Budgets, cost tags, anomaly detection, and service quotas
  # Services: Budgets, Cost Explorer, Billing, Account, Service Quotas, IAM
  statement {
    sid    = "GovernanceWrite"
    effect = "Allow"
    actions = [
      "budgets:*",
      "ce:UpdateCostAllocationTagsStatus",
      "ce:CreateAnomalyMonitor",
      "ce:CreateAnomalySubscription",
      "ce:UpdateAnomalyMonitor",
      "ce:UpdateAnomalySubscription",
      "ce:StartCommitmentPurchaseAnalysis",
      "ce:StartSavingsPlansPurchaseRecommendationGeneration",
      "servicequotas:RequestServiceQuotaIncrease",
      "servicequotas:GetServiceQuota",
      "servicequotas:ListServiceQuotas",
      "servicequotas:GetRequestedServiceQuotaChange",
      "servicequotas:ListRequestedServiceQuotaChangeHistory",
      "servicequotas:GetAWSDefaultServiceQuota",
      "servicequotas:ListAWSDefaultServiceQuotas",
      "iam:SimulatePrincipalPolicy",
    ]
    resources = [
      "*",
    ]
  }

  # Service Quotas - Create service-linked role for Service Quotas functionality
  # Services: IAM
  statement {
    sid    = "ServiceQuotasServiceLinkedRole"
    effect = "Allow"
    actions = [
      "iam:CreateServiceLinkedRole",
    ]
    resources = [
      "arn:aws:iam::*:role/aws-service-role/servicequotas.amazonaws.com/*",
    ]
    condition {
      test     = "StringEquals"
      variable = "iam:AWSServiceName"
      values   = ["servicequotas.amazonaws.com"]
    }
  }

  # SNS - Write access for Blocks-prefixed topics (anomaly detection subscriptions)
  # Services: SNS
  statement {
    sid    = "SNSAnomalyDetectionSubscriptionsWrite"
    effect = "Allow"
    actions = [
      "sns:*",
    ]
    resources = [
      "arn:${local.partition}:sns:*:${local.account_id}:Blocks*",
    ]
  }

  # CloudWatch Alarms - Create and manage Blocks-prefixed alarms only
  # Services: CloudWatch
  statement {
    sid    = "CloudWatchWrite"
    effect = "Allow"
    actions = [
      "cloudwatch:PutMetricAlarm",
      "cloudwatch:DeleteAlarms",
      "cloudwatch:EnableAlarmActions",
      "cloudwatch:DisableAlarmActions",
    ]
    resources = [
      "arn:${local.partition}:cloudwatch:*:${local.account_id}:alarm:Blocks-*",
    ]
  }

  # EventBridge - Write access for Blocks-prefixed rules and event buses
  # Services: EventBridge
  statement {
    sid    = "EventBridgeWrite"
    effect = "Allow"
    actions = [
      "events:PutRule",
      "events:PutTargets",
      "events:DeleteRule",
      "events:RemoveTargets",
      "events:CreateEventBus",
      "events:DeleteEventBus",
      "events:PutEvents",
    ]
    resources = [
      "arn:${local.partition}:events:*:*:rule/Blocks*",
      "arn:${local.partition}:events:*:*:event-bus/Blocks*",
    ]
  }

  # Compute Optimizer - Full write access for optimization recommendations
  # Services: Compute Optimizer
  statement {
    sid    = "ComputeOptimizerWrite"
    effect = "Allow"
    actions = [
      "compute-optimizer:*",
    ]
    resources = [
      "*",
    ]
  }

  # Cost Optimization Hub - Create service-linked role for opt-in
  # Services: IAM, Cost Optimization Hub
  statement {
    sid    = "CostOptimizationHubOptIn"
    effect = "Allow"
    actions = [
      "iam:CreateServiceLinkedRole",
    ]
    resources = [
      "arn:aws:iam::*:role/aws-service-role/cost-optimization-hub.bcm.amazonaws.com/AWSServiceRoleForCostOptimizationHub",
    ]
    condition {
      test     = "StringLike"
      variable = "iam:AWSServiceName"
      values   = ["cost-optimization-hub.bcm.amazonaws.com"]
    }
  }

  # Cost Optimization Hub - Update service-linked role policy
  # Services: IAM
  statement {
    sid    = "CostOptimizationHubPolicy"
    effect = "Allow"
    actions = [
      "iam:PutRolePolicy",
    ]
    resources = [
      "arn:aws:iam::*:role/aws-service-role/cost-optimization-hub.bcm.amazonaws.com/AWSServiceRoleForCostOptimizationHub",
    ]
  }

  # Cost Optimization Hub - Update enrollment status
  # Services: Cost Optimization Hub
  statement {
    sid    = "CostOptimizationHubUpdateStatus"
    effect = "Allow"
    actions = [
      "cost-optimization-hub:UpdateEnrollmentStatus",
    ]
    resources = [
      "*",
    ]
  }

}

resource "aws_iam_policy" "blocks_cost_optimization_write" {
  name        = "BlocksCostOptimizationWritePolicy-${var.customer_resource_id}"
  description = "Used by Blocks.cloud. Must remain in place for Blocks to function correctly. Email support@blocks.cloud for assistance. Grants execution permissions for cost optimization actions including purchasing Savings Plans, RIs, and managing accounts."
  policy      = data.aws_iam_policy_document.blocks_cost_optimization_write.json
  tags        = local.common_tags
}

############################
# BlocksCustomReadPolicy
############################

# IAM Policy: Custom Read Permissions
# Custom read permissions for Blocks cost optimization not covered by AWS managed policies
# Note: Most read permissions come from AWS managed policies (ReadOnlyAccess, etc.)
data "aws_iam_policy_document" "blocks_custom_read" {
  # Invoicing & Tax - Combined read access for BlocksCustomReadPolicy
  # Services: AWS Invoicing, AWS Tax Settings
  statement {
    sid    = "InvoicingTaxRead"
    effect = "Allow"
    actions = [
      "invoicing:BatchGetInvoiceProfile",
      "tax:GetTaxRegistration",
      "taxsettings:Get*",
      "taxsettings:List*",
    ]
    resources = [
      "*",
    ]
  }

  # Commitment purchases - Read access for RI and Savings Plans analysis
  # Services: Cost Explorer, Redshift, CloudFront, SageMaker
  statement {
    sid    = "CommitmentReads"
    effect = "Allow"
    actions = [
      "redshift:GetReservedNodeExchangeOfferings",
      "redshift:GetReservedNodeExchangeConfigurationOptions",
      "cloudfront:ListSavingsPlans",
      "cloudfront:GetSavingsPlan",
      "cloudfront:ListRateCards",
      "cloudfront:ListUsages",
      "ce:GetCommitmentPurchaseAnalysis",
      "ce:ListCommitmentPurchaseAnalyses",
      "sagemaker:SearchTrainingPlanOfferings",
    ]
    resources = [
      "*",
    ]
  }

  # Savings Plans - Trigger and retrieve purchase recommendations
  # Services: Cost Explorer
  statement {
    sid    = "SavingsPlansRecommendationGeneration"
    effect = "Allow"
    actions = [
      "ce:StartSavingsPlansPurchaseRecommendationGeneration",
      "ce:ListSavingsPlansPurchaseRecommendationGeneration",
      "ce:GetSavingsPlansPurchaseRecommendation",
    ]
    resources = [
      "*",
    ]
  }

  # S3 - Bucket configuration discovery for cost optimization
  # Services: S3
  statement {
    sid    = "S3BucketDiscovery"
    effect = "Allow"
    actions = [
      "s3:GetBucketLocation",
      "s3:GetLifecycleConfiguration",
      "s3:GetIntelligentTieringConfiguration",
    ]
    resources = [
      "*",
    ]
  }

}

resource "aws_iam_policy" "blocks_custom_read" {
  name        = "BlocksCustomReadPolicy-${var.customer_resource_id}"
  description = "Custom read permissions for Blocks cost optimization not covered by AWS managed policies"
  policy      = data.aws_iam_policy_document.blocks_custom_read.json
  tags        = local.common_tags
}

############################
# BlocksDataProtectionPolicy
############################

# ============================================================================
# IAM Managed Policy: Data Protection Policy (Step 2 - Cost Optimization)
# 11-Tier Explicit Deny Policy - Cryptographic Assurance of Data Protection
# ============================================================================
# IAM evaluation: Explicit Deny > Allow > Implicit Deny (denies always win)
# Coverage: 100+ actions across 11 tiers protecting secrets, communications,
# documents, databases, storage, analytics, logs, identity, code, ML, and instance access
# Note: Step 2 allows CUR bucket access (blocks-cur-data-*/cur2/*)
# ============================================================================
data "aws_iam_policy_document" "blocks_data_protection" {
  # TIER 1: Secrets & Credentials
  statement {
    sid    = "DenySecretsAndCredentials"
    effect = "Deny"
    actions = [
      "secretsmanager:GetSecretValue",
      "secretsmanager:GetResourcePolicy",
      "secretsmanager:DescribeSecret",
      "ssm:GetParameter",
      "ssm:GetParameters",
      "ssm:GetParameterHistory",
      "ssm:GetParametersByPath",
      "acm-pca:GetCertificate",
      "acm-pca:GetCertificateAuthorityCertificate",
      "kms:Decrypt",
      "kms:Encrypt",
      "kms:GenerateDataKey",
      "kms:ReEncrypt*",
    ]
    resources = [
      "*",
    ]
  }

  # TIER 2: Communications (Emails, Messages, SMS)
  statement {
    sid    = "DenyCommunicationsData"
    effect = "Deny"
    actions = [
      "workmail:*",
      "ses:GetMessage",
      "ses:GetEmailIdentity",
      "ses:GetEmailTemplate",
      "chime:GetMessage*",
      "chime:GetConversation*",
      "chime:ListMessages",
      "connect:GetContactAttributes",
      "connect:GetContactRecording",
      "pinpoint:GetEmailTemplate",
      "pinpoint:GetSmsTemplate",
      "sns:GetSMSAttributes",
    ]
    resources = [
      "*",
    ]
  }

  # TIER 3: Documents & Collaboration
  statement {
    sid    = "DenyDocumentsAccess"
    effect = "Deny"
    actions = [
      "workdocs:GetDocument",
      "workdocs:GetDocumentVersion",
      "workdocs:DownloadDocumentVersion",
      "workspaces:DescribeWorkspacesConnectionStatus",
      "workspaces:DescribeWorkspaceSnapshots",
    ]
    resources = [
      "*",
    ]
  }

  # TIER 4: Database Content
  statement {
    sid    = "DenyDatabaseContentAccess"
    effect = "Deny"
    actions = [
      "dynamodb:GetItem",
      "dynamodb:BatchGetItem",
      "dynamodb:Query",
      "dynamodb:Scan",
      "dynamodb:GetRecords",
      "dynamodb:GetShardIterator",
      "rds-data:ExecuteStatement",
      "rds-data:BatchExecuteStatement",
      "rds:DownloadDBLogFilePortion",
      "rds:DownloadCompleteDBLogFile",
      "neptune-db:*",
      "timestream:Select",
      "timestream:SelectValues",
      "qldb:SendCommand",
      "qldb:ExecuteStatement",
      "redshift:GetClusterCredentials",
      "redshift:ExecuteQuery",
      "redshift-data:ExecuteStatement",
      "redshift-data:GetStatementResult",
    ]
    resources = [
      "*",
    ]
  }

  # TIER 5: Storage Content - S3 with CUR exception
  statement {
    sid    = "DenyS3DataAccessExceptCURBucket"
    effect = "Deny"
    actions = [
      "s3:GetObject",
      "s3:GetObjectVersion",
      "s3:GetObjectTorrent",
    ]
    resources = [
      "*",
    ]
    condition {
      test     = "ArnNotLike"
      variable = "aws:ResourceArn"
      values   = ["arn:aws:s3:::blocks-cur-data-*/cur2/*"]
    }
  }

  # Deny all S3 write/delete operations
  statement {
    sid    = "DenyS3WriteDelete"
    effect = "Deny"
    actions = [
      "s3:PutObject",
      "s3:DeleteObject",
    ]
    resources = [
      "*",
    ]
  }

  # TIER 5: File systems and backups
  statement {
    sid    = "DenyFileSystemAndBackupAccess"
    effect = "Deny"
    actions = [
      "elasticfilesystem:ClientMount",
      "elasticfilesystem:ClientWrite",
      "elasticfilesystem:ClientRootAccess",
      "fsx:*",
      "backup:GetRecoveryPointRestoreMetadata",
      "backup:StartRestoreJob",
    ]
    resources = [
      "*",
    ]
  }

  # TIER 6: Analytics Query Results
  statement {
    sid    = "DenyAnalyticsQueryResults"
    effect = "Deny"
    actions = [
      "athena:GetQueryResults",
      "athena:GetQueryResultsStream",
      "quicksight:GetDashboard",
      "quicksight:GetDataSet",
      "glue:GetTable",
      "glue:GetPartition",
      "glue:GetPartitions",
    ]
    resources = [
      "*",
    ]
  }

  # TIER 7: Logs (with Container Insights exception)
  statement {
    sid    = "DenyLogsQueryExceptContainerInsights"
    effect = "Deny"
    actions = [
      "logs:StartQuery",
      "logs:GetQueryResults",
    ]
    resources = [
      "*",
    ]
    condition {
      test     = "StringNotLike"
      variable = "logs:LogGroupName"
      values   = ["/aws/containerinsights/*/performance"]
    }
  }

  # Deny direct log access
  statement {
    sid    = "DenyLogEventsAccess"
    effect = "Deny"
    actions = [
      "logs:GetLogEvents",
      "logs:FilterLogEvents",
      "logs:GetLogRecord",
      "cloudtrail:LookupEvents",
      "cloudtrail:GetQueryResults",
    ]
    resources = [
      "*",
    ]
  }

  # TIER 8: User Directories & Identity
  statement {
    sid    = "DenyUserDirectoryAccess"
    effect = "Deny"
    actions = [
      "cognito-identity:*",
      "cognito-idp:*",
      "cognito-sync:*",
      "ds:DescribeUsers",
      "iam:GetSSHPublicKey",
      "iam:GetServiceSpecificCredential",
      "iam:GetLoginProfile",
    ]
    resources = [
      "*",
    ]
  }

  # TIER 9: Code & Artifacts
  statement {
    sid    = "DenyCodeAccess"
    effect = "Deny"
    actions = [
      "codecommit:GetFile",
      "codecommit:GetFolder",
      "codecommit:GetBlob",
      "codecommit:GitPull",
      "codeartifact:GetPackageVersionAsset",
      "codeartifact:ReadFromRepository",
      "ecr:BatchGetImage",
      "ecr:GetDownloadUrlForLayer",
    ]
    resources = [
      "*",
    ]
  }

  # TIER 10: Machine Learning Data
  statement {
    sid    = "DenyMachineLearningData"
    effect = "Deny"
    actions = [
      "sagemaker:DescribeModelPackage",
      "sagemaker:DescribeTrainingJob",
      "rekognition:DetectFaces",
      "rekognition:SearchFaces*",
      "comprehend:DetectPiiEntities",
    ]
    resources = [
      "*",
    ]
  }

  # TIER 11: Instance Access
  statement {
    sid    = "DenyInstanceAccess"
    effect = "Deny"
    actions = [
      "ec2:GetConsoleOutput",
      "ec2:GetConsoleScreenshot",
      "ec2:GetPasswordData",
      "ssm:StartSession",
    ]
    resources = [
      "*",
    ]
  }

  # Additional sensitive operations
  statement {
    sid    = "DenyOtherSensitiveOperations"
    effect = "Deny"
    actions = [
      "lambda:InvokeFunction",
      "sqs:ReceiveMessage",
      "kinesis:GetRecords",
    ]
    resources = [
      "*",
    ]
  }

}

resource "aws_iam_policy" "blocks_data_protection" {
  name        = "BlocksDataProtectionPolicy-${var.customer_resource_id}"
  description = "Comprehensive 11-tier data protection policy with 100+ explicit denies across secrets, communications, documents, databases, storage, analytics, logs, identity, code, ML, and instance access. Provides cryptographic assurance that Blocks cannot access customer sensitive data."
  policy      = data.aws_iam_policy_document.blocks_data_protection.json
  tags        = local.common_tags
}

# ==== END GENERATED IAM POLICIES ====

############################
# IAM Roles
############################

############################
# BlocksExecutionRole
############################

resource "aws_iam_role" "blocks_execution_role" {
  name                 = "BlocksExecutionRole-${var.customer_resource_id}"
  description          = "Used by Blocks.cloud to execute cost optimization actions. Must remain in place for Blocks to function correctly. Email support@blocks.cloud for assistance."
  max_session_duration = 3600
  assume_role_policy   = data.aws_iam_policy_document.blocks_cross_account_trust.json

  tags = merge(local.common_tags, {
    Purpose = "CostOptimization"
  })
}

# Write permissions for cost optimization actions
resource "aws_iam_role_policy_attachment" "blocks_execution_write" {
  role       = aws_iam_role.blocks_execution_role.name
  policy_arn = aws_iam_policy.blocks_cost_optimization_write.arn
}

# Read permissions - using AWS managed policies for broad coverage
resource "aws_iam_role_policy_attachment" "blocks_execution_data_protection" {
  role       = aws_iam_role.blocks_execution_role.name
  policy_arn = aws_iam_policy.blocks_data_protection.arn
}

resource "aws_iam_role_policy_attachment" "blocks_execution_managed" {
  for_each = toset([
    "arn:${local.partition}:iam::aws:policy/ReadOnlyAccess",
    "arn:${local.partition}:iam::aws:policy/AWSSavingsPlansFullAccess",
    "arn:${local.partition}:iam::aws:policy/AWSBillingReadOnlyAccess",
    # Additional AWS managed policies not covered by ReadOnlyAccess
    "arn:${local.partition}:iam::aws:policy/ComputeOptimizerReadOnlyAccess",
    "arn:${local.partition}:iam::aws:policy/AWSOrganizationsReadOnlyAccess",
    "arn:${local.partition}:iam::aws:policy/SecurityAudit"
  ])
  role       = aws_iam_role.blocks_execution_role.name
  policy_arn = each.value
}

resource "aws_iam_role_policy_attachment" "blocks_execution_custom" {
  role       = aws_iam_role.blocks_execution_role.name
  policy_arn = aws_iam_policy.blocks_custom_read.arn
}

############################
# BlocksReadRole
############################

resource "aws_iam_role" "blocks_read_role" {
  name                 = "BlocksReadRole-${var.customer_resource_id}"
  description          = "Read-only role for Blocks.cloud cost analysis and monitoring. Must remain in place for Blocks to function correctly. Email support@blocks.cloud for assistance."
  max_session_duration = 3600
  assume_role_policy   = data.aws_iam_policy_document.blocks_cross_account_trust.json

  tags = merge(local.common_tags, {
    Purpose  = "CostOptimization"
    RoleType = "ReadOnly"
  })
}

# Read permissions - using AWS managed policies for broad coverage
resource "aws_iam_role_policy_attachment" "blocks_read_data_protection" {
  role       = aws_iam_role.blocks_read_role.name
  policy_arn = aws_iam_policy.blocks_data_protection.arn
}

resource "aws_iam_role_policy_attachment" "blocks_read_managed" {
  for_each = toset([
    "arn:${local.partition}:iam::aws:policy/ReadOnlyAccess",
    "arn:${local.partition}:iam::aws:policy/AWSBillingReadOnlyAccess",
    # Additional AWS managed policies not covered by ReadOnlyAccess
    "arn:${local.partition}:iam::aws:policy/AWSSavingsPlansReadOnlyAccess",
    "arn:${local.partition}:iam::aws:policy/ComputeOptimizerReadOnlyAccess",
    "arn:${local.partition}:iam::aws:policy/AWSOrganizationsReadOnlyAccess",
    "arn:${local.partition}:iam::aws:policy/SecurityAudit"
  ])
  role       = aws_iam_role.blocks_read_role.name
  policy_arn = each.value
}

resource "aws_iam_role_policy_attachment" "blocks_read_custom" {
  role       = aws_iam_role.blocks_read_role.name
  policy_arn = aws_iam_policy.blocks_custom_read.arn
}

############################
# MajorTomReadRole
############################

resource "aws_iam_role" "majortom_read_role" {
  name                 = "MajorTomReadRole-${var.customer_resource_id}"
  description          = "Read-only AI role for Blocks.cloud cost analysis and monitoring. Must remain in place for MajorTom to function correctly."
  max_session_duration = 3600
  assume_role_policy   = data.aws_iam_policy_document.blocks_cross_account_trust.json

  tags = merge(local.common_tags, {
    Purpose  = "CostOptimization"
    RoleType = "AI-ReadOnly"
  })
}

resource "aws_iam_role_policy_attachment" "majortom_read_data_protection" {
  role       = aws_iam_role.majortom_read_role.name
  policy_arn = aws_iam_policy.blocks_data_protection.arn
}

resource "aws_iam_role_policy_attachment" "majortom_read_managed" {
  for_each = toset([
    "arn:${local.partition}:iam::aws:policy/ReadOnlyAccess",
    "arn:${local.partition}:iam::aws:policy/AWSBillingReadOnlyAccess",
    # Additional AWS managed policies not covered by ReadOnlyAccess
    "arn:${local.partition}:iam::aws:policy/AWSSavingsPlansReadOnlyAccess",
    "arn:${local.partition}:iam::aws:policy/ComputeOptimizerReadOnlyAccess",
    "arn:${local.partition}:iam::aws:policy/AWSOrganizationsReadOnlyAccess",
    "arn:${local.partition}:iam::aws:policy/SecurityAudit"
  ])
  role       = aws_iam_role.majortom_read_role.name
  policy_arn = each.value
}

resource "aws_iam_role_policy_attachment" "majortom_read_blocks_custom" {
  role       = aws_iam_role.majortom_read_role.name
  policy_arn = aws_iam_policy.blocks_custom_read.arn
}

############################
# BlocksOptimizationNotifierRole
############################

data "aws_iam_policy_document" "blocks_notifier_assume" {
  # Allow EventBridge to assume this role for event-based notifications
  statement {
    effect = "Allow"
    principals {
      type        = "Service"
      identifiers = ["events.amazonaws.com"]
    }
    actions = ["sts:AssumeRole"]
  }

  # Allow the current account to assume this role (for Terraform local-exec notifications)
  statement {
    effect = "Allow"
    principals {
      type        = "AWS"
      identifiers = ["arn:${local.partition}:iam::${local.account_id}:root"]
    }
    actions = ["sts:AssumeRole"]
  }
}

data "aws_iam_policy_document" "blocks_notifier_permissions" {
  statement {
    sid    = "SendToBlocksSQS"
    effect = "Allow"
    actions = [
      "sqs:SendMessage"
    ]
    resources = [local.blocks_sqs_arn]
  }
}

resource "aws_iam_role" "blocks_optimization_notifier_role" {
  name               = "BlocksOptimizationNotifierRole-${var.customer_resource_id}"
  description        = "Used by Blocks.cloud to notify about deployment events. Must remain in place for Blocks to function correctly. Email support@blocks.cloud for assistance."
  assume_role_policy = data.aws_iam_policy_document.blocks_notifier_assume.json

  tags = merge(local.common_tags, {
    Purpose = "EventNotification"
  })
}

resource "aws_iam_role_policy" "blocks_notifier_permissions" {
  name   = "SendToBlocksSQS"
  role   = aws_iam_role.blocks_optimization_notifier_role.id
  policy = data.aws_iam_policy_document.blocks_notifier_permissions.json
}
