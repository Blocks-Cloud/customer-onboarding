############################
# Blocks Cost Optimization Module (Step 2)
# Read + Write access for cost optimization
############################

terraform {
  required_version = ">= 1.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = ">= 5.0"
    }
  }
}

############################
# Data Sources
############################

data "aws_caller_identity" "current" {}
data "aws_region" "current" {}
data "aws_partition" "current" {}

# Organization data - required for Step 2 (management account only)
data "aws_organizations_organization" "current" {}

############################
# Locals
############################

locals {
  account_id = data.aws_caller_identity.current.account_id
  region     = data.aws_region.current.id
  partition  = data.aws_partition.current.partition

  # Resource naming with customer_resource_id suffix
  resource_suffix = var.customer_resource_id

  ############################
  # Account Type Detection
  ############################

  # Organization details
  has_organization = try(data.aws_organizations_organization.current.id != null, false)

  # Step 2 MUST be deployed from management account
  is_management_account = local.has_organization ? (
    local.account_id == try(data.aws_organizations_organization.current.master_account_id, "")
  ) : false

  # Organization root ID (for StackSet deployment)
  organization_root_id = local.is_management_account ? (
    try(data.aws_organizations_organization.current.roots[0].id, null)
  ) : null

  management_account_id = local.has_organization ? (
    try(data.aws_organizations_organization.current.master_account_id, null)
  ) : null

  ############################
  # Validation
  ############################

  # Step 2 requires management account
  management_account_check = local.is_management_account ? true : tobool(
    "ERROR: Step 2 (Cost Optimization) must be deployed from the AWS Organizations management account. Current account ${local.account_id} is not the management account."
  )

  # Region must be us-east-1
  region_is_valid = local.region == "us-east-1"
  region_check = local.region_is_valid ? true : tobool(
    "ERROR: Must deploy to us-east-1. Current region: ${local.region}. CUR/BCM exports and Organizations APIs require us-east-1."
  )

  ############################
  # Resource Naming
  ############################

  # S3 bucket for CUR data
  cur_bucket_name = "blocks-cur-data-${var.customer_resource_id}"

  # Blocks SQS queue ARN
  blocks_sqs_arn = "arn:${local.partition}:sqs:us-east-1:${var.blocks_account_id}:Blocks-Onboarding-Queue"

  # Blocks customer access role ARN
  blocks_customer_access_role_arn = "arn:${local.partition}:iam::${var.blocks_account_id}:role/BlocksCustomerAccessRole"

  # Blocks EventBridge bus ARN (eu-central-1 for runbook forwarding)
  blocks_event_bus_arn = "arn:${local.partition}:events:eu-central-1:${var.blocks_account_id}:event-bus/blocks-customer-events"

  ############################
  # Common Tags
  ############################

  common_tags = merge(
    var.default_tags,
    {
      OwnedBy   = "Blocks.cloud"
      Purpose   = "CostOptimization"
      Module    = "blocks_cost_optimization"
      ManagedBy = "Terraform"
    }
  )
}

############################
# Validation Checks
############################
# This resource forces evaluation of validation locals at plan time

resource "terraform_data" "validation" {
  input = {
    management_account_check = local.management_account_check
    region_check             = local.region_check
  }
}
