############################
# Blocks Cost Estimations Module (Step 1)
# Read-only access for cost analysis
############################


############################
# Data Sources
############################

data "aws_caller_identity" "current" {}
data "aws_region" "current" {}
data "aws_partition" "current" {}

# Always attempt to fetch org data - will fail gracefully on standalone accounts
# Use try() in locals to handle failures
data "aws_organizations_organization" "current" {}

############################
# Locals
############################

locals {
  account_id = data.aws_caller_identity.current.account_id
  region     = data.aws_region.current.region
  partition  = data.aws_partition.current.partition

  # Resource naming with customer_id suffix
  resource_suffix = var.customer_id

  ############################
  # Auto-Detection Logic
  ############################

  # 1. Check if this account belongs to an AWS Organization
  #    try() returns false if the org data source fails (standalone accounts)
  has_organization = try(data.aws_organizations_organization.current.id != null, false)

  # 2. Auto-detect if this is the management account
  #    Compare current account ID to the organization's master account ID
  detected_is_management = local.has_organization ? (
    local.account_id == try(data.aws_organizations_organization.current.master_account_id, "")
  ) : false

  # 3. Determine account type: management, member, or standalone
  detected_account_type = local.has_organization ? (
    local.detected_is_management ? "management" : "member"
  ) : "standalone"

  # 4. Final value based on detection
  is_management_account = local.detected_is_management

  # 5. Only deploy StackSet if management account
  deploy_stackset = local.is_management_account

  # 6. Organization details (only available for management accounts)
  organization_root_id = local.is_management_account && local.has_organization ? (
    try(data.aws_organizations_organization.current.roots[0].id, null)
  ) : null

  management_account_id = local.has_organization ? (
    try(data.aws_organizations_organization.current.master_account_id, null)
  ) : null

  ############################
  # Region Validation
  ############################

  # Validate region at plan time - must be us-east-1 for CUR/BCM exports
  # This creates a plan-time error if deployed to wrong region
  region_is_valid = local.region == "us-east-1"
  region_check = local.region_is_valid ? true : tobool(
    "ERROR: Must deploy to us-east-1. Current region: ${local.region}. CUR and Organizations APIs require us-east-1."
  )

  ############################
  # Common Configuration
  ############################

  # Common tags for all resources (merged with provider default_tags automatically)
  common_tags = {
    OwnedBy   = "Blocks.cloud"
    Purpose   = "CostEstimations"
    Module    = "blocks_cost_estimations"
    ManagedBy = "Terraform"
  }

  # Blocks customer access role ARN
  blocks_customer_access_role_arn = "arn:${local.partition}:iam::${var.blocks_account_id}:role/BlocksCustomerAccessRole"
}
