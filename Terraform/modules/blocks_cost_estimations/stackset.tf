############################
# CloudFormation StackSet for Member Accounts
# Deploys read-only IAM role to all organization member accounts
############################

# Note: StackSets trusted access must be enabled before creating the StackSet.
# This is handled by terraform_data.enable_stacksets_trusted_access in enable_stacksets.tf

resource "aws_cloudformation_stack_set" "cost_estimations" {
  count = local.is_management_account && local.deploy_stackset ? 1 : 0

  name             = "Blocks-CostEstimations-${var.customer_resource_id}"
  description      = "Blocks read-only IAM role for organization-wide cost analysis. Must remain in place for Blocks to function correctly."
  permission_model = "SERVICE_MANAGED"

  auto_deployment {
    enabled                          = false
    retain_stacks_on_account_removal = false
  }

  capabilities = ["CAPABILITY_NAMED_IAM"]
  call_as      = "SELF"

  parameters = {
    BlocksCustomerId = var.customer_resource_id
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
    organizational_unit_ids = length(var.target_ou_ids) > 0 ? var.target_ou_ids : [local.organization_root_id]
  }

  operation_preferences {
    # 100% tolerance: deploy the read role to every account in the OU rather than
    # stopping at the first account that fails. An account can fail for reasons
    # that are not fixable mid-apply (an SCP, a suspended account, an IAM name
    # collision), and partial org coverage is more useful than none. Failed
    # instances stay FAILED and visible in the StackSet's per-instance results.
    failure_tolerance_percentage = 100
    max_concurrent_percentage    = 100
    region_concurrency_type      = "PARALLEL"
    concurrency_mode             = "SOFT_FAILURE_TOLERANCE"
  }

  lifecycle {
    # operation_preferences is a per-operation argument: AWS does not store it and
    # UpdateStackInstances does not read it back, so a diff here reconciles nothing
    # in the real world. Acting on that diff actively breaks: for an OU-targeted
    # (SERVICE_MANAGED) instance the provider parses the resource ID
    # "<name>,<target>,<region>" and sends the middle component as Accounts, so
    # CloudFormation rejects the OU id against ^[0-9]{12}$ (aws provider 6.60.0,
    # BLO-4618). Create passes deployment_targets correctly, so new deployments
    # still get the tolerance configured above; only in-place changes are ignored.
    ignore_changes = [operation_preferences]
  }
}
