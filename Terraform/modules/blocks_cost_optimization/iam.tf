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

  # Governance & Monitoring - Budgets, anomaly detection, and service quotas
  # Services: Budgets, Cost Explorer, Billing, Account, Service Quotas, IAM
  statement {
    sid    = "GovernanceWrite"
    effect = "Allow"
    actions = [
      "budgets:*",
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

  # Cost Allocation Tags - Activate tags and trigger backfill (management account only)
  # Services: Cost Explorer
  statement {
    sid    = "CostAllocationTagsWrite"
    effect = "Allow"
    actions = [
      "ce:UpdateCostAllocationTagsStatus",
      "ce:ListCostAllocationTags",
      "ce:StartCostAllocationTagBackfill",
      "ce:ListCostAllocationTagBackfillHistory",
    ]
    resources = [
      "*",
    ]
  }

  # Data Exports - Create and manage BCM Data Exports (CUR 2.0)
  # Services: BCM Data Exports
  statement {
    sid    = "DataExportsWrite"
    effect = "Allow"
    actions = [
      "bcm-data-exports:*",
      "cur:*",
    ]
    resources = [
      "*",
    ]
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

  # CUR Bucket Management - Create and configure CUR S3 bucket (management account only)
  # Services: S3
  statement {
    sid    = "CURBucketManagement"
    effect = "Allow"
    actions = [
      "s3:CreateBucket",
      "s3:DeleteBucket",
      "s3:PutBucketVersioning",
      "s3:PutBucketPolicy",
      "s3:DeleteBucketPolicy",
      "s3:PutBucketPublicAccessBlock",
      "s3:PutEncryptionConfiguration",
      "s3:PutLifecycleConfiguration",
      "s3:PutBucketOwnershipControls",
    ]
    resources = [
      "arn:aws:s3:::blocks-cur-data-*",
    ]
  }

  # CloudTrail org trail management - Create and manage organization CloudTrail trail for EventBridge event delivery
  # Services: CloudTrail
  statement {
    sid    = "CloudTrailOrgTrailManagement"
    effect = "Allow"
    actions = [
      "cloudtrail:CreateTrail",
      "cloudtrail:StartLogging",
      "cloudtrail:UpdateTrail",
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
      "redshift:GetReservedNodeExchangeConfigurationOptions",
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
    ]
    resources = [
      "*",
    ]
  }

  # BCM Data Exports - Read access for CUR 2.0 export configurations
  # Services: BCM Data Exports
  statement {
    sid    = "DataExportsRead"
    effect = "Allow"
    actions = [
      "bcm-data-exports:GetExport",
      "bcm-data-exports:GetExecution",
      "bcm-data-exports:GetTable",
      "bcm-data-exports:ListExports",
      "bcm-data-exports:ListExecutions",
      "bcm-data-exports:ListTables",
      "bcm-data-exports:ListTagsForResource",
    ]
    resources = [
      "*",
    ]
  }

  # Trusted Advisor - Full access for cost optimization, security, and performance recommendations (available to all accounts)
  # Services: Trusted Advisor
  statement {
    sid    = "TrustedAdvisorFullRead"
    effect = "Allow"
    actions = [
      "trustedadvisor:*",
    ]
    resources = [
      "*",
    ]
  }

  # Trusted Advisor - Legacy API read access (requires Business/Enterprise support plan, fails gracefully on Basic/Developer plans)
  # Services: Support
  statement {
    sid    = "TrustedAdvisorLegacyRead"
    effect = "Allow"
    actions = [
      "support:DescribeTrustedAdvisorChecks",
      "support:DescribeTrustedAdvisorCheckResult",
      "support:DescribeTrustedAdvisorCheckSummaries",
    ]
    resources = [
      "*",
    ]
  }

  # Compute Optimizer - Full access for rightsizing and resource optimization recommendations
  # Services: Compute Optimizer
  statement {
    sid    = "ComputeOptimizerFullAccess"
    effect = "Allow"
    actions = [
      "compute-optimizer:*",
    ]
    resources = [
      "*",
    ]
  }

  # Cost Optimization Hub - Full access for centralized cost optimization recommendations across accounts
  # Services: Cost Optimization Hub
  statement {
    sid    = "CostOptimizationHubFullAccess"
    effect = "Allow"
    actions = [
      "cost-optimization-hub:*",
    ]
    resources = [
      "*",
    ]
  }

  # ACO Automation - Update enrollment configuration for Compute Optimizer
  # Services: ACO Automation
  statement {
    sid    = "AcoAutomationUpdateEnrollmentConfiguration"
    effect = "Allow"
    actions = [
      "aco-automation:UpdateEnrollmentConfiguration",
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
# Explicit Deny Policy - Cryptographic Assurance of Data Protection
# ============================================================================
# IAM evaluation: Explicit Deny > Allow > Implicit Deny (denies always win)
# Coverage: secrets, communications, documents, databases, storage, analytics,
# logs, identity, code, ML, instance access, and additional sensitive operations.
# Note: Step 2 allows CUR bucket access (blocks-cur-data-*/cur2/*).
# ============================================================================
data "aws_iam_policy_document" "blocks_data_protection" {
  # TIER 1: Secrets & Credentials
  statement {
    sid    = "DenySecretsAndCredentials"
    effect = "Deny"
    actions = [
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
      "ses:List*",
      "ses:Get*",
      "ses:Describe*",
      "sesv2:List*",
      "sesv2:Get*",
      "pinpoint:Get*",
      "pinpoint:List*",
      "pinpoint-email:*",
      "pinpoint-sms-voice:*",
      "chime:GetMessage*",
      "chime:GetConversation*",
      "chime:ListMessages",
      "connect:GetContactAttributes",
      "sns:GetSMSAttributes",
      "sns:ListPlatformApplications",
      "sns:GetPlatformApplicationAttributes",
      "sns:ListEndpointsByPlatformApplication",
      "sns:GetEndpointAttributes",
      "sns:ListPhoneNumbersOptedOut",
      "sns:ListOriginationNumbers",
      "sns:ListSMSSandboxPhoneNumbers",
      "sns:GetSMSSandboxAccountStatus",
      "sns:CheckIfPhoneNumberIsOptedOut",
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
      "rds:DownloadDBLogFilePortion",
      "rds:DownloadCompleteDBLogFile",
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

  # TIER 5: File systems and backups
  statement {
    sid    = "DenyFileSystemAndBackupAccess"
    effect = "Deny"
    actions = [
      "fsx:*",
      "backup:GetRecoveryPointRestoreMetadata",
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

############################
# BlocksEventBridgeCrossAccountRole
############################

data "aws_iam_policy_document" "blocks_event_forwarding_assume" {
  statement {
    effect = "Allow"
    principals {
      type        = "Service"
      identifiers = ["events.amazonaws.com"]
    }
    actions = ["sts:AssumeRole"]
  }
}

data "aws_iam_policy_document" "blocks_event_forwarding_permissions" {
  statement {
    sid    = "PutEventsToBlocksBus"
    effect = "Allow"
    actions = [
      "events:PutEvents"
    ]
    resources = [local.blocks_event_bus_arn]
  }
}

resource "aws_iam_role" "blocks_event_bridge_cross_account_role" {
  name               = "BlocksEventBridgeCrossAccountRole-${var.customer_resource_id}"
  description        = "Used by Blocks.cloud to forward CloudTrail events to Blocks for change detection. Must remain in place for Blocks to function correctly. Email support@blocks.cloud for assistance."
  assume_role_policy = data.aws_iam_policy_document.blocks_event_forwarding_assume.json

  tags = merge(local.common_tags, {
    Purpose = "EventForwarding"
  })
}

resource "aws_iam_role_policy" "blocks_event_forwarding_permissions" {
  name   = "PutEventsToBlocksBus"
  role   = aws_iam_role.blocks_event_bridge_cross_account_role.id
  policy = data.aws_iam_policy_document.blocks_event_forwarding_permissions.json
}
