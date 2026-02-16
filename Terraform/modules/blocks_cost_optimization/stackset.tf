############################
# StackSet for Member Accounts
############################
# Deploys Blocks IAM roles to all member accounts for organization-wide
# cost analysis and optimization.
#


resource "aws_cloudformation_stack_set" "cost_optimization" {
  count = local.is_management_account ? 1 : 0

  name             = "Blocks-CostOptimization-${var.customer_resource_id}"
  description      = "Deploys Blocks IAM roles to all member accounts for organization-wide cost analysis and optimization. Must remain in place for Blocks to function correctly."
  permission_model = "SERVICE_MANAGED"

  capabilities = ["CAPABILITY_NAMED_IAM"]

  # Use template URL - the SubAccounts template is hosted externally
  template_url = var.stackset_template_url

  parameters = {
    BlocksCustomerId = var.customer_resource_id
    BlocksAccountId  = var.blocks_account_id
    ExternalId       = var.external_id
  }

  auto_deployment {
    enabled                          = true
    retain_stacks_on_account_removal = false
  }

  operation_preferences {
    failure_tolerance_percentage = 0
    max_concurrent_percentage    = 100
    region_concurrency_type      = "PARALLEL"
  }

  # Match CloudFormation behavior: CallAs: SELF
  call_as = "SELF"

  # Ensure SCP is applied before deploying roles to member accounts
  depends_on = [
    aws_organizations_policy_attachment.savings_plans_deny_root
  ]

  tags = merge(local.common_tags, {
    TemplateVersion = var.template_version
  })

  lifecycle {
    ignore_changes = [
      administration_role_arn,
    ]
  }
}

resource "aws_cloudformation_stack_set_instance" "cost_optimization" {
  count = local.is_management_account ? 1 : 0

  stack_set_name            = aws_cloudformation_stack_set.cost_optimization[0].name
  stack_set_instance_region = "us-east-1"

  deployment_targets {
    organizational_unit_ids = length(var.target_ou_ids) > 0 ? var.target_ou_ids : [local.organization_root_id]
  }

  operation_preferences {
    failure_tolerance_percentage = 0
    max_concurrent_percentage    = 100
    region_concurrency_type      = "PARALLEL"
    concurrency_mode             = "SOFT_FAILURE_TOLERANCE"
  }

  lifecycle {
    precondition {
      condition     = length(var.target_ou_ids) > 0 || local.organization_root_id != null
      error_message = "Either target_ou_ids must be provided or organization root ID must be available (management account)."
    }
  }
}
