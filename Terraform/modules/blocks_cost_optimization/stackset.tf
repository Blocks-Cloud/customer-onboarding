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
    BlocksCustomerId  = var.customer_resource_id
    BlocksAccountId   = var.blocks_account_id
    ExternalId        = var.external_id
    BlocksEventBusArn = local.blocks_event_bus_arn
  }

  auto_deployment {
    enabled                          = true
    retain_stacks_on_account_removal = false
  }

  operation_preferences {
    # 100% tolerance: attempt every account instead of aborting on the first
    # failure. Matches Blocks-CostOptimization.yaml's SubAccountStackSet.
    failure_tolerance_percentage = 100
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
    # 100% tolerance: deploy to every account in the OU rather than stopping at
    # the first account that fails. Failed instances stay FAILED and visible in
    # the StackSet's per-instance results; terraform apply itself succeeds.
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

    precondition {
      condition     = length(var.target_ou_ids) > 0 || local.organization_root_id != null
      error_message = "Either target_ou_ids must be provided or organization root ID must be available (management account)."
    }
  }
}

############################
# StackSet for EventBridge Forwarding (Multi-Region)
############################
# Deploys EventBridge rules to forward CloudTrail management write events
# across all default AWS regions in member accounts.

locals {
  # All default (non-opt-in) AWS commercial regions
  all_default_regions = [
    "us-east-1",
    "us-east-2",
    "us-west-1",
    "us-west-2",
    "ca-central-1",
    "eu-central-1",
    "eu-north-1",
    "eu-west-1",
    "eu-west-2",
    "eu-west-3",
    "ap-northeast-1",
    "ap-northeast-2",
    "ap-northeast-3",
    "ap-south-1",
    "ap-southeast-1",
    "ap-southeast-2",
    "sa-east-1",
  ]
}

resource "aws_cloudformation_stack_set" "event_forwarding" {
  count = local.is_management_account ? 1 : 0

  name             = "Blocks-EventForwarding-${var.customer_resource_id}"
  description      = "Deploys EventBridge rules to forward CloudTrail management write events to Blocks across all regions. Must remain in place for Blocks to function correctly."
  permission_model = "SERVICE_MANAGED"

  capabilities = ["CAPABILITY_NAMED_IAM"]

  template_url = var.event_forwarding_template_url

  parameters = {
    BlocksCustomerId  = var.customer_resource_id
    BlocksEventBusArn = local.blocks_event_bus_arn
  }

  auto_deployment {
    enabled                          = true
    retain_stacks_on_account_removal = false
  }

  operation_preferences {
    # 100% tolerance: a customer SCP may block EventBridge rule creation in some
    # regions; let those instances stay FAILED (skipped) instead of failing the op.
    failure_tolerance_percentage = 100
    max_concurrent_percentage    = 100
    region_concurrency_type      = "PARALLEL"
  }

  call_as = "SELF"

  tags = merge(local.common_tags, {
    TemplateVersion = var.template_version
  })

  lifecycle {
    ignore_changes = [
      administration_role_arn,
    ]
  }
}

resource "aws_cloudformation_stack_instances" "event_forwarding" {
  count = local.is_management_account ? 1 : 0

  stack_set_name = aws_cloudformation_stack_set.event_forwarding[0].name
  regions        = local.all_default_regions

  # Ensure IAM role exists in member accounts before deploying EventBridge rules
  depends_on = [aws_cloudformation_stack_set_instance.cost_optimization]

  deployment_targets {
    organizational_unit_ids = length(var.target_ou_ids) > 0 ? var.target_ou_ids : [local.organization_root_id]
  }

  operation_preferences {
    # 100% tolerance: a customer SCP may block EventBridge rule creation in some
    # regions; let those instances stay FAILED (skipped) instead of failing the op.
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

    precondition {
      condition     = length(var.target_ou_ids) > 0 || local.organization_root_id != null
      error_message = "Either target_ou_ids must be provided or organization root ID must be available (management account)."
    }
  }
}
