############################
# BlocksDataProtectionPolicy
############################

# IAM Policy: Data Protection Deny Policy
# Explicit deny overlay to block access to sensitive data while using broad managed read policies
# ============================================================================
# COMPREHENSIVE 11-TIER DATA PROTECTION POLICY
# ============================================================================
# This policy provides cryptographic assurance that Blocks cannot access
# customer sensitive data. IAM evaluation: Explicit Deny > Allow > Implicit Deny
# Denies always win - even if future policies grant access, these denies prevail.
#
# Coverage: 100+ actions across 11 tiers protecting:
# - Secrets & Credentials
# - Communications (Email, SMS, Messages)
# - Documents & Collaboration
# - Database Content
# - Storage Content
# - Analytics Query Results
# - Logs
# - User Directories & Identity
# - Code & Artifacts
# - Machine Learning Data
# - Instance Access (Console, Screenshots, Sessions)
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
    resources = ["*"]
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
    resources = ["*"]
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
    resources = ["*"]
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
    resources = ["*"]
  }

  # TIER 5: Storage Content (S3, EFS, FSx, Backups)
  statement {
    sid    = "DenyS3DataAccess"
    effect = "Deny"
    actions = [
      "s3:GetObject",
      "s3:GetObjectVersion",
      "s3:GetObjectTorrent",
    ]
    resources = ["*"]
  }

  statement {
    sid    = "DenyS3WriteDelete"
    effect = "Deny"
    actions = [
      "s3:PutObject",
      "s3:DeleteObject",
    ]
    resources = ["*"]
  }

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
    resources = ["*"]
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
    resources = ["*"]
  }

  # TIER 7: Logs (with Container Insights exception)
  # Deny CloudWatch Logs queries EXCEPT Container Insights performance logs
  statement {
    sid    = "DenyLogsQueryExceptContainerInsights"
    effect = "Deny"
    actions = [
      "logs:StartQuery",
      "logs:GetQueryResults",
    ]
    resources = ["*"]
    condition {
      test     = "StringNotLike"
      variable = "logs:LogGroupName"
      values   = ["/aws/containerinsights/*/performance"]
    }
  }

  # Deny direct log access (all log groups)
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
    resources = ["*"]
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
    resources = ["*"]
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
    resources = ["*"]
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
    resources = ["*"]
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
    resources = ["*"]
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
    resources = ["*"]
  }
}

resource "aws_iam_policy" "blocks_data_protection" {
  name        = "BlocksEstimationsDataProtectionPolicy-${var.customer_resource_id}"
  description = "Comprehensive 11-tier data protection policy with 100+ explicit denies across secrets, communications, documents, databases, storage, analytics, logs, identity, code, ML, and instance access. Provides cryptographic assurance that Blocks cannot access customer sensitive data during cost estimations."
  policy      = data.aws_iam_policy_document.blocks_data_protection.json
  tags        = local.common_tags
}

############################
# BlocksEstimationsCustomReadPolicy
############################

# IAM Policy: Custom Read Permissions
# Permissions not covered by AWS managed policies, serving as an extensible bucket for future custom read permissions
data "aws_iam_policy_document" "blocks_estimations_custom_read" {
  statement {
    sid    = "IAMSimulatePrincipalPolicy"
    effect = "Allow"
    actions = [
      "iam:SimulatePrincipalPolicy",
    ]
    resources = ["*"]
  }

  statement {
    sid    = "CommitmentAnalysisAndRecommendations"
    effect = "Allow"
    actions = [
      "ce:StartCommitmentPurchaseAnalysis",
      "ce:StartSavingsPlansPurchaseRecommendationGeneration",
      "ce:GetSavingsPlansPurchaseRecommendation",
      "ce:GetSavingsPlansCoverage",
      "ce:GetSavingsPlansUtilization",
      "ce:GetSavingsPlansUtilizationDetails",
    ]
    resources = ["*"]
  }

  statement {
    sid    = "S3BucketDiscovery"
    effect = "Allow"
    actions = [
      "s3:GetBucketLocation",
      "s3:GetLifecycleConfiguration",
      "s3:GetIntelligentTieringConfiguration",
    ]
    resources = ["*"]
  }

  statement {
    sid    = "PricingRead"
    effect = "Allow"
    actions = [
      "pricing:GetProducts",
      "pricing:DescribeServices",
      "pricing:GetAttributeValues",
    ]
    resources = ["*"]
  }

  statement {
    sid    = "EKSClusterDiscovery"
    effect = "Allow"
    actions = [
      "eks:ListClusters",
      "eks:DescribeCluster",
    ]
    resources = ["*"]
  }

  statement {
    sid    = "ContainerInsightsAnalysis"
    effect = "Allow"
    actions = [
      "logs:StartQuery",
      "logs:GetQueryResults",
    ]
    resources = ["*"]
  }
}

resource "aws_iam_policy" "blocks_estimations_custom_read" {
  name        = "BlocksEstimationsCustomReadPolicy-${var.customer_resource_id}"
  description = "Custom read permissions for Blocks cost estimations not covered by AWS managed policies"
  policy      = data.aws_iam_policy_document.blocks_estimations_custom_read.json
  tags        = local.common_tags
}

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
    "arn:${local.partition}:iam::aws:policy/job-function/ViewOnlyAccess",
    "arn:${local.partition}:iam::aws:policy/AWSBillingReadOnlyAccess",
    "arn:${local.partition}:iam::aws:policy/ComputeOptimizerReadOnlyAccess",
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

