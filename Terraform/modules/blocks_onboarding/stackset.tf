resource "aws_cloudformation_stack_set" "blocks" {
  name        = var.stack_set_name
  description = var.stack_set_description

  permission_model = "SERVICE_MANAGED"
  call_as          = "SELF"

  capabilities = ["CAPABILITY_NAMED_IAM"]

  auto_deployment {
    retain_stacks_on_account_removal = var.retain_stacks_on_account_removal
    enabled                          = var.auto_deployment_enabled
  }

  operation_preferences {
    failure_tolerance_count = try(var.failure_tolerance_count, null)
    max_concurrent_count    = try(var.max_concurrent_count, null)
    region_concurrency_type = try(var.region_concurrency_type, null)
  }

  parameters = {
    BlocksExternalAccountId = var.blocks_external_account_id
    ExternalId              = var.external_id
  }

  template_url = var.template_url

  lifecycle {
    ignore_changes = [
      administration_role_arn,
      parameters,
    ]
  }

  tags = {
    TemplateVersion = var.template_version
  }

}

resource "aws_cloudformation_stack_instances" "blocks" {

  deployment_targets {
    organizational_unit_ids = [data.aws_organizations_organization.current.roots[0].id]
  }

  operation_preferences {
    failure_tolerance_count = try(var.failure_tolerance_count, null)
    max_concurrent_count    = try(var.max_concurrent_count, null)
    region_concurrency_type = try(var.region_concurrency_type, null)
  }

  stack_set_name = aws_cloudformation_stack_set.blocks.name
}

data "aws_organizations_organization" "current" {}


