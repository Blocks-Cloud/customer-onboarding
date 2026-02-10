############################
# Blocks Cost Optimization - Example Usage
# Step 2: Read+Write Access for Cost Optimization
############################
#
# This example demonstrates how to deploy the blocks_cost_optimization module
# to grant Blocks.cloud full access for active cost optimization.
#
# Prerequisites:
#   - AWS CLI configured with credentials for an Organization MANAGEMENT account
#   - Terraform >= 1.0
#   - AWS Organizations with 'All Features' enabled
#   - Region MUST be us-east-1 (CUR exports only available here)
#
#
# IMPORTANT: This module can ONLY be deployed to an AWS Organizations management account!
#
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
# Provider Configuration
############################

provider "aws" {
  region = "us-east-1" # REQUIRED - CUR exports and BCM only available in us-east-1

  default_tags {
    tags = {
      ManagedBy = "Terraform"
    }
  }
}

############################
# Blocks Cost Optimization Module
############################

module "blocks_cost_optimization" {
  # For local development, use relative path:
  source = "../../modules/blocks_cost_optimization"

  # For production, use Git source with version tag:
  # source = "github.com/Blocks-Cloud/customer-onboarding.git//Terraform/modules/blocks_cost_optimization?ref=v1.0.0"

  # Required variables - provided by Blocks
  customer_resource_id  = "example-customer"                                      # provided by blocks
  external_id           = "example-external-id"                                   # provided by blocks
  blocks_account_id     = "123456789012"                                          # provided by blocks
  stackset_template_url = "https://s3.amazonaws.com/example-bucket/template.yaml" # provided by blocks

  # Optional variables
  enable_cost_allocation_backfill = false
}

output "deployment_summary" {
  description = "Summary of the deployment for Blocks onboarding - share this with Blocks"
  value = {
    execution_role_arn     = module.blocks_cost_optimization.execution_role_arn
    read_role_arn          = module.blocks_cost_optimization.read_role_arn
    majortom_read_role_arn = module.blocks_cost_optimization.majortom_read_role_arn
    cur_bucket_arn         = module.blocks_cost_optimization.cur_bucket_arn
    bcm_export_arn         = module.blocks_cost_optimization.bcm_export_arn
    organization_root_id   = module.blocks_cost_optimization.organization_root_id
    management_account_id  = module.blocks_cost_optimization.management_account_id
    status                 = "Step 2 Complete - Blocks now has full access for cost optimization"
  }
}