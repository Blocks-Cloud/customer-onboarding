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
# BlocksBaseReadPolicy (Shared Read)
############################

data "aws_iam_policy_document" "blocks_base_read" {
  # Cost Explorer - Read access
  # Services: Cost Explorer
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

  # Cost Optimization Hub - Full read access
  # Services: Cost Optimization Hub
  statement {
    sid    = "CostOptimizationHubRead"
    effect = "Allow"
    actions = [
      "cost-optimization-hub:Get*",
      "cost-optimization-hub:List*"
    ]
    resources = ["*"]
  }

  # Pricing API - Full read access
  # Services: Pricing
  statement {
    sid    = "PricingRead"
    effect = "Allow"
    actions = [
      "pricing:Get*",
      "pricing:DescribeServices",
      "pricing:ListPriceLists"
    ]
    resources = ["*"]
  }

  # CloudWatch - Full read access
  # Services: CloudWatch
  statement {
    sid    = "CloudWatchRead"
    effect = "Allow"
    actions = [
      "cloudwatch:Describe*",
      "cloudwatch:Get*",
      "cloudwatch:List*"
    ]
    resources = ["*"]
  }

  # CloudWatch Logs - Basic read access
  # Services: CloudWatch Logs
  statement {
    sid    = "CloudWatchLogsRead"
    effect = "Allow"
    actions = [
      "logs:Describe*",
      "logs:List*"
    ]
    resources = ["*"]
  }

  # IAM Policy Simulation - Read access
  # Services: IAM
  statement {
    sid    = "IamPolicySimulationRead"
    effect = "Allow"
    actions = [
      "iam:SimulatePrincipalPolicy"
    ]
    resources = ["*"]
  }
}

resource "aws_iam_policy" "blocks_base_read" {
  name        = "BlocksBaseReadPolicy-${var.customer_id}"
  description = "Shared read-only permissions for all Blocks roles - Cost Explorer, CloudWatch, Pricing. Must remain in place for Blocks to function correctly."
  policy      = data.aws_iam_policy_document.blocks_base_read.json
  tags        = local.common_tags
}

############################
# BlocksCostOptimizationWritePolicy
############################

data "aws_iam_policy_document" "blocks_cost_optimization_write" {
  # Reserved Instance Purchases
  # Allows Blocks to purchase, modify, and exchange Reserved Instances
  # across AWS services to optimize costs based on your usage patterns
  # Services: EC2, RDS, ElastiCache, Redshift, OpenSearch, MemoryDB
  statement {
    sid    = "SavingsPlansAndRIsWrite"
    effect = "Allow"
    actions = [
      "ec2:PurchaseReservedInstancesOffering",
      "ec2:ModifyReservedInstances",
      "ec2:AcceptReservedInstancesExchangeQuote",
      "ec2:DeleteQueuedReservedInstances",
      "rds:PurchaseReservedDBInstancesOffering",
      "elasticache:PurchaseReservedCacheNodesOffering",
      "redshift:PurchaseReservedNodeOffering",
      "es:PurchaseReservedInstanceOffering",
      "memorydb:PurchaseReservedNodesOffering"
    ]
    resources = ["*"]
  }

  # Organization Management
  # Allows Blocks to manage organization structure, create accounts, create OUs,
  # and enable AWS service integrations for cost optimization workflows
  # Services: Organizations
  statement {
    sid    = "OrgManagementWrite"
    effect = "Allow"
    actions = [
      "organizations:MoveAccount",
      "organizations:CreateAccount",
      "organizations:CreateOrganizationalUnit",
      "organizations:ListRoots",
      "organizations:ListOrganizationalUnitsForParent",
      "organizations:ListParents",
      "organizations:TagResource",
      "organizations:UntagResource",
      "organizations:AcceptHandshake",
      "organizations:EnableAWSServiceAccess"
    ]
    resources = ["*"]
  }

  # Account Transfer Operations
  # Required for commitment service to move accounts between organizations
  # Services: Organizations
  statement {
    sid    = "AccountTransferOperations"
    effect = "Allow"
    actions = [
      "organizations:InviteAccountToOrganization",
      "organizations:DescribeHandshake",
      "organizations:ListHandshakesForOrganization",
      "organizations:CancelHandshake",
      "organizations:DescribeOrganization"
    ]
    resources = ["*"]
  }

  # Governance & Monitoring
  # Services: Budgets, Cost Explorer, Billing, Account, Service Quotas
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
      "billing:GetBillingData",
      "billing:GetBillingDetails",
      "account:GetContactInformation",
      "servicequotas:RequestServiceQuotaIncrease"
    ]
    resources = ["*"]
  }

  # SNS Write for Anomaly Detection Subscriptions
  # Services: SNS
  statement {
    sid    = "SNSAnomalyDetectionSubscriptionsWrite"
    effect = "Allow"
    actions = [
      "sns:*"
    ]
    resources = ["arn:${local.partition}:sns:*:${local.account_id}:Blocks*"]
  }

  # CloudWatch Write for Alarms
  # Services: CloudWatch
  statement {
    sid    = "CloudWatchWrite"
    effect = "Allow"
    actions = [
      "cloudwatch:PutMetricAlarm",
      "cloudwatch:DeleteAlarms",
      "cloudwatch:EnableAlarmActions",
      "cloudwatch:DisableAlarmActions"
    ]
    resources = ["arn:${local.partition}:cloudwatch:*:${local.account_id}:alarm:Blocks-*"]
  }

  # EventBridge Management
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
      "events:PutEvents"
    ]
    resources = [
      "arn:${local.partition}:events:*:*:rule/Blocks*",
      "arn:${local.partition}:events:*:*:event-bus/Blocks*"
    ]
  }

  # Compute Optimizer
  # Services: Compute Optimizer
  statement {
    sid    = "ComputeOptimizerWrite"
    effect = "Allow"
    actions = [
      "compute-optimizer:*"
    ]
    resources = ["*"]
  }

  # Cost Optimization Hub Opt-In
  # Services: IAM, Cost Optimization Hub
  statement {
    sid    = "CostOptimizationHubOptIn"
    effect = "Allow"
    actions = [
      "iam:CreateServiceLinkedRole"
    ]
    resources = ["arn:aws:iam::*:role/aws-service-role/cost-optimization-hub.bcm.amazonaws.com/AWSServiceRoleForCostOptimizationHub"]
    condition {
      test     = "StringLike"
      variable = "iam:AWSServiceName"
      values   = ["cost-optimization-hub.bcm.amazonaws.com"]
    }
  }

  statement {
    sid    = "CostOptimizationHubPolicy"
    effect = "Allow"
    actions = [
      "iam:PutRolePolicy"
    ]
    resources = ["arn:aws:iam::*:role/aws-service-role/cost-optimization-hub.bcm.amazonaws.com/AWSServiceRoleForCostOptimizationHub"]
  }

  statement {
    sid    = "CostOptimizationHubUpdateStatus"
    effect = "Allow"
    actions = [
      "cost-optimization-hub:UpdateEnrollmentStatus"
    ]
    resources = ["*"]
  }
}

resource "aws_iam_policy" "blocks_cost_optimization_write" {
  name        = "BlocksCostOptimizationWritePolicy-${var.customer_id}"
  description = "Used by Blocks.cloud. Must remain in place for Blocks to function correctly. Email support@blocks.cloud for assistance. Grants execution permissions for cost optimization actions including purchasing Savings Plans, RIs, and managing accounts."
  policy      = data.aws_iam_policy_document.blocks_cost_optimization_write.json
  tags        = local.common_tags
}

############################
# BlocksCostOptimizationReadPolicy
############################

data "aws_iam_policy_document" "blocks_cost_optimization_read" {
  # Cost Explorer extras (beyond base policy)
  # Services: Cost Explorer
  statement {
    sid    = "CostExplorerExtras"
    effect = "Allow"
    actions = [
      "ce:StartCommitmentPurchaseAnalysis",
      "ce:StartSavingsPlansPurchaseRecommendationGeneration"
    ]
    resources = ["*"]
  }

  # CUR/Data Exports - Read access (management account only)
  # Services: Cost and Usage Report
  statement {
    sid    = "CURDataExportsRead"
    effect = "Allow"
    actions = [
      "cur:Get*",
      "cur:Describe*",
      "cur:DescribeReportDefinitions"
    ]
    resources = ["*"]
  }

  # Invoicing - Read access for invoice profiles and summaries
  # Services: AWS Invoicing
  statement {
    sid    = "InvoicingRead"
    effect = "Allow"
    actions = [
      "invoicing:BatchGetInvoiceProfile",
      "invoicing:ListInvoiceSummaries",
      "invoicing:GetInvoicePdf",
      "invoicing:ListInvoiceUnits",
      "invoicing:GetInvoiceUnit"
    ]
    resources = ["*"]
  }

  # Tax Settings - Read access for tax registration info
  # Services: AWS Tax Settings
  statement {
    sid    = "TaxRead"
    effect = "Allow"
    actions = [
      "tax:GetTaxRegistration",
      "tax:ListTaxRegistrations"
    ]
    resources = ["*"]
  }

  # IAM Identity Center ReadOnly
  # Services: IAM Identity Center (SSO)
  statement {
    sid    = "IamIdentityCenterReadOnly"
    effect = "Allow"
    actions = [
      "sso:ListInstances"
    ]
    resources = ["*"]
  }

  # Compute, scaling, and load balancing
  # Services: EC2, Auto Scaling, Application Auto Scaling, ELB, Lambda
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
      "application-autoscaling:Describe*",
      "application-autoscaling:List*",
      "application-autoscaling:Get*",
      "autoscaling-plans:Describe*",
      "autoscaling-plans:Get*",
      "lambda:List*",
      "lambda:GetFunctionConfiguration"
    ]
    resources = ["*"]
  }

  # Containers, orchestration, and build/deploy
  # Services: ECS, EKS, ECR
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
      "ecr:DescribeImages"
    ]
    resources = ["*"]
  }

  # Databases and caching
  # Services: RDS, DynamoDB, DAX, Redshift, Redshift Serverless, ElastiCache, MemoryDB, Aurora DSQL
  statement {
    sid    = "DatabasesAndCachingReadOnly"
    effect = "Allow"
    actions = [
      "rds:Describe*",
      "rds:List*",
      "dsql:Get*",
      "dsql:List*",
      "dynamodb:List*",
      "dynamodb:Describe*",
      "redshift:Describe*",
      "redshift:Get*",
      "redshift:List*",
      "redshift-serverless:Describe*",
      "redshift-serverless:List*",
      "elasticache:Describe*",
      "elasticache:List*",
      "memorydb:Describe*",
      "memorydb:List*"
    ]
    resources = ["*"]
  }

  # Storage, backup, and content delivery
  # Services: S3 (metadata only), FSx, EFS, Backup
  statement {
    sid    = "StorageAndContentReadOnly"
    effect = "Allow"
    actions = [
      "s3:ListAllMyBuckets",
      "s3:ListBucketVersions",
      "s3vectors:ListVectorBuckets",
      "s3:GetLifecycleConfiguration",
      "s3:GetBucketLocation",
      "s3:GetBucketVersioning",
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

  # End-user compute and application streaming
  # Services: WorkSpaces, AppStream
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

  # Observability extras (CloudWatch and Logs are in BlocksBaseReadPolicy)
  # Services: CloudWatch OAM, Config
  statement {
    sid    = "ObservabilityExtras"
    effect = "Allow"
    actions = [
      "oam:ListSinks",
      "config:Describe*",
      "config:Get*",
      "config:List*"
    ]
    resources = ["*"]
  }

  # Network
  statement {
    sid    = "NetworkAndEdgeReadOnly"
    effect = "Allow"
    actions = [
      "wafv2:List*"
    ]
    resources = ["*"]
  }

  # CloudTrail Read Access
  # Services: CloudTrail
  statement {
    sid    = "CloudTrailReadAccess"
    effect = "Allow"
    actions = [
      "cloudtrail:LookupEvents",
      "cloudtrail:Describe*",
      "cloudtrail:Get*",
      "cloudtrail:List*"
    ]
    resources = ["*"]
  }

  # Systems Manager Automation
  # Services: Systems Manager
  statement {
    sid    = "SSMAutomationRead"
    effect = "Allow"
    actions = [
      "ssm:DescribeAutomationStepExecutions",
      "ssm:DescribeAutomationExecutions"
    ]
    resources = ["*"]
  }

  # CloudFormation Stack Read Access
  # Services: CloudFormation
  statement {
    sid    = "CloudFormationStackReadAccess"
    effect = "Allow"
    actions = [
      "cloudformation:DescribeStacks",
      "cloudformation:DescribeStackEvents",
      "cloudformation:ListStacks"
    ]
    resources = ["*"]
  }
}

resource "aws_iam_policy" "blocks_cost_optimization_read" {
  name        = "BlocksCostOptimizationReadPolicy-${var.customer_id}"
  description = "Used by Blocks.cloud. Must remain in place for Blocks to function correctly. Email support@blocks.cloud for assistance. Read-only access to compute, storage, database, and infrastructure services for savings analysis."
  policy      = data.aws_iam_policy_document.blocks_cost_optimization_read.json
  tags        = local.common_tags
}

############################
# MajorTomReadPolicy
############################

data "aws_iam_policy_document" "majortom_read" {
  # Cloud Control API Read
  # Services: Cloud Control API
  statement {
    sid    = "CloudControlAPIRead"
    effect = "Allow"
    actions = [
      "cloudcontrol:GetResource",
      "cloudcontrol:ListResources",
      "cloudcontrol:GetResourceRequestStatus"
    ]
    resources = ["*"]
  }

  # CloudFormation Schema Read
  # Services: CloudFormation
  statement {
    sid    = "CloudFormationSchemaRead"
    effect = "Allow"
    actions = [
      "cloudformation:DescribeType",
      "cloudformation:DescribeGeneratedTemplate",
      "cloudformation:GetGeneratedTemplate",
      "cloudformation:ListGeneratedTemplates"
    ]
    resources = ["*"]
  }

  # CloudWatch Logs extras (beyond base policy)
  # Services: CloudWatch Logs
  statement {
    sid    = "CloudWatchLogsExtras"
    effect = "Allow"
    actions = [
      "logs:StartQuery",
      "logs:GetQueryResults",
      "logs:StopQuery",
      "logs:GetLogEvents",
      "logs:FilterLogEvents"
    ]
    resources = ["*"]
  }

  # CloudTrail
  # Services: CloudTrail
  statement {
    sid    = "CloudTrailRead"
    effect = "Allow"
    actions = [
      "cloudtrail:LookupEvents",
      "cloudtrail:DescribeTrails",
      "cloudtrail:GetTrail",
      "cloudtrail:GetTrailStatus",
      "cloudtrail:ListTrails",
      "cloudtrail:GetEventSelectors",
      "cloudtrail:GetInsightSelectors"
    ]
    resources = ["*"]
  }

  # CloudTrail Lake
  # Services: CloudTrail
  statement {
    sid    = "CloudTrailLakeRead"
    effect = "Allow"
    actions = [
      "cloudtrail:ListEventDataStores",
      "cloudtrail:GetEventDataStore",
      "cloudtrail:StartQuery",
      "cloudtrail:DescribeQuery",
      "cloudtrail:GetQueryResults",
      "cloudtrail:ListQueries"
    ]
    resources = ["*"]
  }

  # Budgets
  # Services: Budgets
  statement {
    sid    = "BudgetsRead"
    effect = "Allow"
    actions = [
      "budgets:ViewBudget",
      "budgets:DescribeBudget",
      "budgets:DescribeBudgets"
    ]
    resources = ["*"]
  }

  # Free Tier
  # Services: Free Tier
  statement {
    sid    = "FreeTierRead"
    effect = "Allow"
    actions = [
      "freetier:GetFreeTierUsage"
    ]
    resources = ["*"]
  }

  # Pricing Calculator
  # Services: BCM Pricing Calculator
  statement {
    sid    = "PricingCalculatorRead"
    effect = "Allow"
    actions = [
      "bcm-pricing-calculator:GetPreferences",
      "bcm-pricing-calculator:GetWorkloadEstimate",
      "bcm-pricing-calculator:ListWorkloadEstimateUsage",
      "bcm-pricing-calculator:ListWorkloadEstimates"
    ]
    resources = ["*"]
  }
}

resource "aws_iam_policy" "majortom_read" {
  name        = "MajorTomReadPolicy-${var.customer_id}"
  description = "MajorTom AI read permissions for Cloud Control API, CloudTrail, and cost analysis. Must remain in place for MajorTom to function correctly."
  policy      = data.aws_iam_policy_document.majortom_read.json
  tags        = local.common_tags
}

############################
# IAM Roles
############################

############################
# BlocksExecutionRole
############################

resource "aws_iam_role" "blocks_execution_role" {
  name                 = "BlocksExecutionRole-${var.customer_id}"
  description          = "Used by Blocks.cloud to execute cost optimization actions. Must remain in place for Blocks to function correctly. Email support@blocks.cloud for assistance."
  max_session_duration = 3600
  assume_role_policy   = data.aws_iam_policy_document.blocks_cross_account_trust.json

  tags = merge(local.common_tags, {
    Purpose = "CostOptimization"
  })
}

resource "aws_iam_role_policy_attachment" "blocks_execution_base_read" {
  role       = aws_iam_role.blocks_execution_role.name
  policy_arn = aws_iam_policy.blocks_base_read.arn
}

resource "aws_iam_role_policy_attachment" "blocks_execution_write" {
  role       = aws_iam_role.blocks_execution_role.name
  policy_arn = aws_iam_policy.blocks_cost_optimization_write.arn
}

resource "aws_iam_role_policy_attachment" "blocks_execution_read" {
  role       = aws_iam_role.blocks_execution_role.name
  policy_arn = aws_iam_policy.blocks_cost_optimization_read.arn
}

resource "aws_iam_role_policy_attachment" "blocks_execution_managed" {
  for_each = toset([
    "arn:${local.partition}:iam::aws:policy/AWSSavingsPlansFullAccess",
    "arn:${local.partition}:iam::aws:policy/ComputeOptimizerReadOnlyAccess",
    "arn:${local.partition}:iam::aws:policy/AWSOrganizationsReadOnlyAccess",
    "arn:${local.partition}:iam::aws:policy/AWSResourceGroupsReadOnlyAccess",
    "arn:${local.partition}:iam::aws:policy/AWSSecurityHubReadOnlyAccess"
  ])
  role       = aws_iam_role.blocks_execution_role.name
  policy_arn = each.value
}

############################
# BlocksReadRole
############################

resource "aws_iam_role" "blocks_read_role" {
  name                 = "BlocksReadRole-${var.customer_id}"
  description          = "Read-only role for Blocks.cloud cost analysis and monitoring. Must remain in place for Blocks to function correctly. Email support@blocks.cloud for assistance."
  max_session_duration = 3600
  assume_role_policy   = data.aws_iam_policy_document.blocks_cross_account_trust.json

  tags = merge(local.common_tags, {
    Purpose  = "CostOptimization"
    RoleType = "ReadOnly"
  })
}

resource "aws_iam_role_policy_attachment" "blocks_read_base" {
  role       = aws_iam_role.blocks_read_role.name
  policy_arn = aws_iam_policy.blocks_base_read.arn
}

resource "aws_iam_role_policy_attachment" "blocks_read_optimization" {
  role       = aws_iam_role.blocks_read_role.name
  policy_arn = aws_iam_policy.blocks_cost_optimization_read.arn
}

resource "aws_iam_role_policy_attachment" "blocks_read_managed" {
  for_each = toset([
    "arn:${local.partition}:iam::aws:policy/AWSSavingsPlansReadOnlyAccess",
    "arn:${local.partition}:iam::aws:policy/ComputeOptimizerReadOnlyAccess",
    "arn:${local.partition}:iam::aws:policy/AWSOrganizationsReadOnlyAccess",
    "arn:${local.partition}:iam::aws:policy/AWSResourceGroupsReadOnlyAccess",
    "arn:${local.partition}:iam::aws:policy/AWSSecurityHubReadOnlyAccess"
  ])
  role       = aws_iam_role.blocks_read_role.name
  policy_arn = each.value
}

############################
# MajorTomReadRole
############################

resource "aws_iam_role" "majortom_read_role" {
  name                 = "MajorTomReadRole-${var.customer_id}"
  description          = "Read-only AI role for Blocks.cloud cost analysis and monitoring. Must remain in place for MajorTom to function correctly."
  max_session_duration = 3600
  assume_role_policy   = data.aws_iam_policy_document.blocks_cross_account_trust.json

  tags = merge(local.common_tags, {
    Purpose  = "CostOptimization"
    RoleType = "AI-ReadOnly"
  })
}

resource "aws_iam_role_policy_attachment" "majortom_read_base" {
  role       = aws_iam_role.majortom_read_role.name
  policy_arn = aws_iam_policy.blocks_base_read.arn
}

resource "aws_iam_role_policy_attachment" "majortom_read_custom" {
  role       = aws_iam_role.majortom_read_role.name
  policy_arn = aws_iam_policy.majortom_read.arn
}

resource "aws_iam_role_policy_attachment" "majortom_read_managed" {
  role       = aws_iam_role.majortom_read_role.name
  policy_arn = "arn:${local.partition}:iam::aws:policy/ComputeOptimizerReadOnlyAccess"
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
  name               = "BlocksOptimizationNotifierRole-${var.customer_id}"
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
