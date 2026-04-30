# ==== BEGIN GENERATED IAM POLICIES ====
# Source: iam-policies/policies/
# DO NOT EDIT MANUALLY

############################
# BlocksEstimationsCustomReadPolicy
############################

# IAM Policy: Custom Read Permissions for Cost Estimations
# Custom read permissions for Blocks cost estimations not covered by AWS managed policies
# Note: Most read permissions come from AWS managed policies attached to the role; the statements below add read actions not covered by those managed policies.
data "aws_iam_policy_document" "blocks_estimations_custom_read" {
  # IAM - Policy simulation for access analysis
  # Services: IAM
  statement {
    sid    = "IamPolicySimulationRead"
    effect = "Allow"
    actions = [
      "iam:SimulatePrincipalPolicy",
    ]
    resources = [
      "*",
    ]
  }

  # Cost Explorer - Combined commitment analysis for BlocksEstimationsCustomReadPolicy
  # Services: Cost Explorer
  statement {
    sid    = "CommitmentAnalysisAndRecommendations"
    effect = "Allow"
    actions = [
      "ce:StartCommitmentPurchaseAnalysis",
      "ce:ListCommitmentPurchaseAnalyses",
      "ce:StartSavingsPlansPurchaseRecommendationGeneration",
      "ce:ListSavingsPlansPurchaseRecommendationGeneration",
      "ce:GetSavingsPlansPurchaseRecommendation",
      "ce:GetSavingsPlansCoverage",
      "ce:GetSavingsPlansUtilization",
      "ce:GetSavingsPlansUtilizationDetails",
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
      "s3:GetBucketLogging",
    ]
    resources = [
      "*",
    ]
  }

  # OpenSearch/Elasticsearch - Domain discovery for cost analysis (es: prefix covers all managed domains)
  # Services: Amazon OpenSearch Service
  statement {
    sid    = "OpenSearchDomainDiscovery"
    effect = "Allow"
    actions = [
      "es:DescribeDomain",
      "es:DescribeDomains",
      "es:DescribeDomainConfig",
      "es:ListDomainNames",
      "es:ListTags",
    ]
    resources = [
      "*",
    ]
  }

  # Pricing API - Full read access for cost calculations
  # Services: Pricing
  statement {
    sid    = "PricingRead"
    effect = "Allow"
    actions = [
      "pricing:Get*",
      "pricing:DescribeServices",
      "pricing:ListPriceLists",
    ]
    resources = [
      "*",
    ]
  }

  # EKS - Cluster discovery for rightsizing analysis
  # Services: EKS
  statement {
    sid    = "EKSClusterDiscovery"
    effect = "Allow"
    actions = [
      "eks:ListClusters",
      "eks:DescribeCluster",
    ]
    resources = [
      "*",
    ]
  }

  # ECR - Lifecycle policy discovery for container cost analysis
  # Services: ECR
  statement {
    sid    = "ECRLifecyclePolicyDiscovery"
    effect = "Allow"
    actions = [
      "ecr:GetLifecyclePolicy",
    ]
    resources = [
      "*",
    ]
  }

  # ELB - Listener rule discovery for load balancer analysis
  # Services: Elastic Load Balancing
  statement {
    sid    = "LoadBalancerRulesDiscovery"
    effect = "Allow"
    actions = [
      "elasticloadbalancing:DescribeRules",
    ]
    resources = [
      "*",
    ]
  }

  # CloudWatch Logs Insights - Container Insights performance log queries only (restricted by data protection policy)
  # Services: CloudWatch Logs
  statement {
    sid    = "ContainerInsightsAnalysis"
    effect = "Allow"
    actions = [
      "logs:StartQuery",
      "logs:GetQueryResults",
    ]
    resources = [
      "*",
    ]
  }

  # CloudFormation - Stack event and resource discovery for deployment debugging
  # Services: CloudFormation
  statement {
    sid    = "CloudFormationDeploymentDiscovery"
    effect = "Allow"
    actions = [
      "cloudformation:DescribeStackEvents",
      "cloudformation:DescribeStackResources",
    ]
    resources = [
      "*",
    ]
  }

  # Trusted Advisor - Read-only access (Get/List) for cost optimization recommendations
  # Services: Trusted Advisor
  statement {
    sid    = "TrustedAdvisorReadOnly"
    effect = "Allow"
    actions = [
      "trustedadvisor:Get*",
      "trustedadvisor:List*",
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

  # Compute Optimizer - Get-only read access for rightsizing and resource optimization recommendations
  # Services: Compute Optimizer
  statement {
    sid    = "ComputeOptimizerGetRead"
    effect = "Allow"
    actions = [
      "compute-optimizer:Get*",
    ]
    resources = [
      "*",
    ]
  }

  # Cost Optimization Hub - Read-only access (Get/List) for centralized cost optimization recommendations
  # Services: Cost Optimization Hub
  statement {
    sid    = "CostOptimizationHubReadOnly"
    effect = "Allow"
    actions = [
      "cost-optimization-hub:Get*",
      "cost-optimization-hub:List*",
    ]
    resources = [
      "*",
    ]
  }

  # Application Auto Scaling - Scalable targets and scaling policy discovery for rightsizing analysis
  # Services: Application Auto Scaling
  statement {
    sid    = "ApplicationAutoScalingDiscovery"
    effect = "Allow"
    actions = [
      "application-autoscaling:DescribeScalableTargets",
      "application-autoscaling:DescribeScalingPolicies",
    ]
    resources = [
      "*",
    ]
  }

  # AWS Backup - Read backup plan rules (retention, cold-storage transitions), backup selections, and vault access policies for cost optimization analysis.
  # Services: AWS Backup
  statement {
    sid    = "BackupPlanAndVaultDiscovery"
    effect = "Allow"
    actions = [
      "backup:GetBackupPlan",
      "backup:GetBackupSelection",
      "backup:GetBackupVaultAccessPolicy",
    ]
    resources = [
      "*",
    ]
  }

}

resource "aws_iam_policy" "blocks_estimations_custom_read" {
  name        = "BlocksEstimationsCustomReadPolicy-${var.customer_resource_id}"
  description = "Custom read permissions for Blocks cost estimations not covered by AWS managed policies"
  policy      = data.aws_iam_policy_document.blocks_estimations_custom_read.json
  tags        = local.common_tags
}

############################
# BlocksEstimationsDataProtectionPolicy
############################

# ============================================================================
# IAM Managed Policy: Data Protection Policy (Step 1 - Cost Estimations)
# Explicit Deny Policy - Cryptographic Assurance of Data Protection
# ============================================================================
# IAM evaluation: Explicit Deny > Allow > Implicit Deny (denies always win)
# Coverage: secrets, communications, documents, databases, storage, analytics,
# logs, identity, code, ML, instance access, and additional sensitive operations.
# Note: Step 1 has no S3 CUR exception (CUR access lives in Step 2 only).
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

  # TIER 5: Storage Content (Complete S3 deny - no CUR exception in Step 1)
  statement {
    sid    = "DenyS3DataAccess"
    effect = "Deny"
    actions = [
      "s3:GetObject",
      "s3:GetObjectVersion",
      "s3:GetObjectTorrent",
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
  name        = "BlocksEstimationsDataProtectionPolicy-${var.customer_resource_id}"
  description = "Comprehensive 11-tier data protection policy with 100+ explicit denies across secrets, communications, documents, databases, storage, analytics, logs, identity, code, ML, and instance access. Provides cryptographic assurance that Blocks cannot access customer sensitive data during cost estimations."
  policy      = data.aws_iam_policy_document.blocks_data_protection.json
  tags        = local.common_tags
}

# ==== END GENERATED IAM POLICIES ====

############################
# IAM Role: Blocks Estimations Read Role
# Cross-account role assumed by Blocks for cost analysis
############################

resource "aws_iam_role" "blocks_estimations_read_role" {
  name                 = "BlocksEstimationsReadRole-${var.customer_resource_id}"
  description          = "Used by Blocks.cloud to analyze cost savings. Must remain in place for Blocks to function correctly. Email support@blocks.cloud for assistance."
  max_session_duration = 3600
  tags = merge(local.common_tags, {
    Purpose = "CostAnalysis"
  })

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Principal = {
          AWS = local.blocks_customer_access_role_arn
        }
        Action = "sts:AssumeRole"
        Condition = {
          StringEquals = {
            "sts:ExternalId" = var.external_id
          }
        }
      },
      {
        Effect = "Allow"
        Principal = {
          AWS = local.blocks_customer_access_role_arn
        }
        Action = "sts:TagSession"
      }
    ]
  })
}

# Policy attachments for BlocksEstimationsReadRole
resource "aws_iam_role_policy_attachment" "blocks_estimations_read_role_data_protection" {
  role       = aws_iam_role.blocks_estimations_read_role.name
  policy_arn = aws_iam_policy.blocks_data_protection.arn
}

resource "aws_iam_role_policy_attachment" "blocks_estimations_read_role_custom_read" {
  role       = aws_iam_role.blocks_estimations_read_role.name
  policy_arn = aws_iam_policy.blocks_estimations_custom_read.arn
}

resource "aws_iam_role_policy_attachment" "blocks_estimations_read_role_managed" {
  for_each = toset([
    "arn:${local.partition}:iam::aws:policy/ReadOnlyAccess",
    "arn:${local.partition}:iam::aws:policy/AWSBillingReadOnlyAccess",
    "arn:${local.partition}:iam::aws:policy/AWSOrganizationsReadOnlyAccess",
    "arn:${local.partition}:iam::aws:policy/AWSAccountManagementReadOnlyAccess",
    "arn:${local.partition}:iam::aws:policy/AWSSavingsPlansReadOnlyAccess",
  ])
  role       = aws_iam_role.blocks_estimations_read_role.name
  policy_arn = each.value
}

############################
# IAM Role: Blocks Estimations Notifier Role
# Used to send notifications to Blocks SQS queue
############################

resource "aws_iam_role" "blocks_estimations_notifier_role" {
  name        = "BlocksEstimationsNotifierRole-${var.customer_resource_id}"
  description = "Used by Blocks.cloud to send deployment notifications. Must remain in place for Blocks to function correctly."

  # Allow the Terraform runner (current user/role) to assume this role
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Principal = {
          AWS = "arn:${local.partition}:iam::${local.account_id}:root"
        }
        Action = "sts:AssumeRole"
      }
    ]
  })

  tags = merge(local.common_tags, {
    Purpose = "Onboarding"
  })
}

resource "aws_iam_role_policy" "blocks_estimations_notifier_policy" {
  name = "BlocksEstimationsNotifierPolicy-${var.customer_resource_id}"
  role = aws_iam_role.blocks_estimations_notifier_role.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid      = "AllowSendMessageToBlocksQueue"
        Effect   = "Allow"
        Action   = "sqs:SendMessage"
        Resource = "arn:${local.partition}:sqs:us-east-1:${var.blocks_account_id}:Blocks-Onboarding-Queue"
      }
    ]
  })
}

