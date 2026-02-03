############################
# IAM Managed Policy: Cost Optimization Read Permissions
############################

resource "aws_iam_policy" "blocks_savings_estimation_read_only" {
  name        = "BlocksSavingsEstimationReadOnlyPolicy-${var.customer_id}"
  description = "Used by Blocks.cloud. Must remain in place for Blocks to function correctly. Email support@blocks.cloud for assistance. Read-only access to configuration and usage data across compute, storage, database, and monitoring services for savings analysis."
  tags        = local.common_tags

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      # Cost and usage analytics APIs
      # Services: Cost Explorer, Cost Optimization Hub
      {
        Sid    = "CostAndUsageReadOnly"
        Effect = "Allow"
        Action = [
          "ce:Get*",
          "ce:List*",
          "ce:Describe*",
          "ce:StartCommitmentPurchaseAnalysis",
          "ce:StartSavingsPlansPurchaseRecommendationGeneration",
          "cost-optimization-hub:Get*",
          "cost-optimization-hub:List*",
          "pricing:GetProducts",
          "pricing:DescribeServices",
          "pricing:GetAttributeValues"
        ]
        Resource = "*"
      },
      # Compute, scaling, and load balancing
      # Services: EC2, Auto Scaling, Application Auto Scaling, ELB, Lambda
      {
        Sid    = "ComputeAndScalingReadOnly"
        Effect = "Allow"
        Action = [
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
        Resource = "*"
      },
      # Containers, orchestration, and build/deploy
      # Services: ECS, EKS, ECR
      {
        Sid    = "ContainersAndBuildReadOnly"
        Effect = "Allow"
        Action = [
          "ecs:List*",
          "ecs:Describe*",
          "eks:List*",
          "eks:Describe*",
          "ecr:DescribeRepositories",
          "ecr:ListImages",
          "ecr:DescribeImages"
        ]
        Resource = "*"
      },
      # Databases and caching
      # Services: RDS, DynamoDB, DAX, Redshift, Redshift Serverless, ElastiCache, MemoryDB, Aurora DSQL
      {
        Sid    = "DatabasesAndCachingReadOnly"
        Effect = "Allow"
        Action = [
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
        Resource = "*"
      },
      # Storage, backup, and content delivery
      # Services: S3 (metadata only), FSx, EFS, Backup
      {
        Sid    = "StorageAndContentReadOnly"
        Effect = "Allow"
        Action = [
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
        Resource = "*"
      },
      # End-user compute and application streaming
      # Services: WorkSpaces, AppStream
      {
        Sid    = "EndUserServicesReadOnly"
        Effect = "Allow"
        Action = [
          "workspaces:Describe*",
          "appstream:Describe*",
          "appstream:List*"
        ]
        Resource = "*"
      },
      # Monitoring, observability
      # Services: CloudWatch, CloudWatch Logs
      {
        Sid    = "ObservabilityReadOnly"
        Effect = "Allow"
        Action = [
          "cloudwatch:Describe*",
          "cloudwatch:Get*",
          "cloudwatch:List*",
          "oam:ListSinks",
          "logs:Describe*",
          "logs:List*",
          "config:Describe*",
          "config:Get*",
          "config:List*"
        ]
        Resource = "*"
      },
      # Network and Edge
      {
        Sid    = "NetworkAndEdgeReadOnly"
        Effect = "Allow"
        Action = [
          "wafv2:List*"
        ]
        Resource = "*"
      }
    ]
  })
}

############################
# IAM Role: Blocks Estimations Read Role
# Cross-account role assumed by Blocks for cost analysis
############################

resource "aws_iam_role" "blocks_estimations_read_role" {
  name                 = "BlocksEstimationsReadRole-${var.customer_id}"
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
resource "aws_iam_role_policy_attachment" "blocks_estimations_read_role_custom_policy" {
  role       = aws_iam_role.blocks_estimations_read_role.name
  policy_arn = aws_iam_policy.blocks_savings_estimation_read_only.arn
}

resource "aws_iam_role_policy_attachment" "blocks_estimations_read_role_compute_optimizer" {
  role       = aws_iam_role.blocks_estimations_read_role.name
  policy_arn = "arn:${local.partition}:iam::aws:policy/ComputeOptimizerReadOnlyAccess"
}

resource "aws_iam_role_policy_attachment" "blocks_estimations_read_role_organizations" {
  role       = aws_iam_role.blocks_estimations_read_role.name
  policy_arn = "arn:${local.partition}:iam::aws:policy/AWSOrganizationsReadOnlyAccess"
}

resource "aws_iam_role_policy_attachment" "blocks_estimations_read_role_account_management" {
  role       = aws_iam_role.blocks_estimations_read_role.name
  policy_arn = "arn:${local.partition}:iam::aws:policy/AWSAccountManagementReadOnlyAccess"
}

resource "aws_iam_role_policy_attachment" "blocks_estimations_read_role_savings_plans" {
  role       = aws_iam_role.blocks_estimations_read_role.name
  policy_arn = "arn:${local.partition}:iam::aws:policy/AWSSavingsPlansReadOnlyAccess"
}

resource "aws_iam_role_policy_attachment" "blocks_estimations_read_role_resource_groups" {
  role       = aws_iam_role.blocks_estimations_read_role.name
  policy_arn = "arn:${local.partition}:iam::aws:policy/AWSResourceGroupsReadOnlyAccess"
}

############################
# IAM Role: Blocks Estimations Notifier Role
# Used to send notifications to Blocks SQS queue
############################

resource "aws_iam_role" "blocks_estimations_notifier_role" {
  name        = "BlocksEstimationsNotifierRole-${var.customer_id}"
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
  name = "BlocksEstimationsNotifierPolicy-${var.customer_id}"
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

