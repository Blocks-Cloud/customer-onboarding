############################
# Blocks GCP Cost Estimations - Example Usage
# Step 1: Read-Only Access for Cost Analysis
############################
#
# This example demonstrates how to deploy the blocks_gcp_estimations module
# to grant Blocks.cloud read-only access for cost optimization analysis.
#
# Prerequisites:
#   - gcloud CLI authenticated with IAM admin on the target project, folder,
#     or organization (folder/org scopes need org-level IAM admin: custom
#     roles are created at the org)
#   - Terraform >= 1.3
#
# Usage:
#   1. Fill in your values below (customer id + AWS account id are provided
#      by Blocks; scope/project/folder/org are your deployment choice)
#   2. Run: terraform init && terraform plan && terraform apply
#   3. Paste the outputs into the Blocks dashboard
#
############################

terraform {
  required_version = ">= 1.3"

  required_providers {
    google = {
      source  = "hashicorp/google"
      version = ">= 5.0"
    }
  }
}

provider "google" {
  project = "my-gcp-project" # project hosting the pool + service account
}

module "blocks_gcp_estimations" {
  # For local development, use relative path:
  source = "../../modules/blocks_gcp_estimations"

  # For production, use Git source with version tag:
  # source = "github.com/Blocks-Cloud/customer-onboarding.git//Terraform/modules/blocks_gcp_estimations?ref=v1.0.0"

  # Required variables - provided by Blocks
  customer_resource_id   = "00000000-0000-0000-0000-000000000000" # provided by blocks (a UUID)
  scanner_aws_account_id = "123456789012"                         # provided by blocks
  # Blocks' shared scanner identity your WIF provider trusts (provided by Blocks):
  scanner_pod_role_arn  = "arn:aws:sts::123456789012:assumed-role/BlocksGcpScannerPod/"
  scanner_pod_role_name = "BlocksGcpScannerPod"
  # Per-customer resource names Blocks derives (provided by Blocks; defaults exist):
  # wif_pool_id     = "blocks-scanner-pool"
  # wif_provider_id = "aws-blocks"
  # scanner_sa_name = "blocks-scanner"

  # Your deployment choices
  project_id = "my-gcp-project"
  scope      = "project" # project | folder | org
  # folder_id = "123456789"  # required when scope = folder
  # org_id    = "987654321"  # required when scope = folder or org
}

output "deployment_summary" {
  description = "Summary of the deployment for Blocks onboarding — paste into the Blocks dashboard"
  value = {
    customer_resource_id  = module.blocks_gcp_estimations.customer_resource_id
    service_account_email = module.blocks_gcp_estimations.service_account_email
    wif_audience          = module.blocks_gcp_estimations.wif_audience
    scope                 = module.blocks_gcp_estimations.scope
  }
}
