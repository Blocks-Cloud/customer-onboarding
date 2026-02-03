############################
# CloudFormation StackSet for Member Accounts
# Deploys read-only IAM role to all organization member accounts
############################

# Note: StackSets trusted access must be enabled before creating the StackSet.
# This is handled by terraform_data.enable_stacksets_trusted_access in enable_stacksets.tf

resource "aws_cloudformation_stack_set" "cost_estimations" {
  count = local.is_management_account && local.deploy_stackset ? 1 : 0

  name             = "Blocks-CostEstimations-${var.customer_id}"
  description      = "Blocks read-only IAM role for organization-wide cost analysis. Must remain in place for Blocks to function correctly."
  permission_model = "SERVICE_MANAGED"

  auto_deployment {
    enabled                          = true
    retain_stacks_on_account_removal = false
  }

  capabilities = ["CAPABILITY_NAMED_IAM"]
  call_as      = "SELF"

  parameters = {
    BlocksCustomerId = var.customer_id
    BlocksAccountId  = var.blocks_account_id
    ExternalId       = var.external_id
  }

  template_url = var.stackset_template_url

  depends_on = [terraform_data.enable_stacksets_trusted_access]

  tags = local.common_tags

  lifecycle {
    ignore_changes = [administration_role_arn]
  }
}

# StackSet instances - deploy to all accounts in the organization root
resource "aws_cloudformation_stack_set_instance" "cost_estimations" {
  count = local.is_management_account && local.deploy_stackset ? 1 : 0

  stack_set_name            = aws_cloudformation_stack_set.cost_estimations[0].name
  stack_set_instance_region = "us-east-1"
  call_as                   = "SELF"

  deployment_targets {
    organizational_unit_ids = [local.organization_root_id]
  }

  operation_preferences {
    failure_tolerance_percentage = 0
    max_concurrent_percentage    = 100
    region_concurrency_type      = "PARALLEL"
    concurrency_mode             = "SOFT_FAILURE_TOLERANCE"
  }
}
