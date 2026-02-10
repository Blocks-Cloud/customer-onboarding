############################
# Blocks Cost Estimations - Example Usage
# Step 1: Read-Only Access for Cost Analysis
############################
#
# This example demonstrates how to deploy the blocks_cost_estimations module
# to grant Blocks.cloud read-only access for cost optimization analysis.
#
# Prerequisites:
#   - AWS CLI configured with credentials for an Organization management account
#   - Terraform >= 1.0
#   - AWS Organizations with 'All Features' enabled
#
# Usage:
#   1. Copy terraform.tfvars.example to terraform.tfvars
#   2. Fill in your values (customer_resource_id, external_id, blocks_account_id)
#   3. Run: terraform init && terraform plan && terraform apply
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
  region = "us-east-1" # Required - Organizations APIs only available in us-east-1

  default_tags {
    tags = {
      ManagedBy = "Terraform"
    }
  }
}

############################
# Blocks Cost Estimations Module
############################

module "blocks_cost_estimations" {
  # For local development, use relative path:
  source = "../../modules/blocks_cost_estimations"

  # For production, use Git source with version tag:
  # source = "github.com/Blocks-Cloud/customer-onboarding.git//Terraform/modules/blocks_cost_estimations?ref=v1.0.0"

  # Required variables - provided by Blocks
  customer_resource_id  = "example-customer"                                      # provided by blocks
  external_id           = "example-external-id"                                   # provided by blocks
  blocks_account_id     = "123456789012"                                          # provided by blocks
  stackset_template_url = "https://s3.amazonaws.com/example-bucket/template.yaml" # provided by blocks
}

output "deployment_summary" {
  description = "Summary of the deployment for Blocks onboarding"
  value = {
    customer_resource_id = module.blocks_cost_estimations.customer_resource_id
    read_role_arn        = module.blocks_cost_estimations.read_role_arn
    account_type         = module.blocks_cost_estimations.detected_account_type
    organization_root_id = module.blocks_cost_estimations.organization_root_id
  }
}