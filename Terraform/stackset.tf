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

  template_url = var.template_url

}

resource "aws_cloudformation_stack_set_instance" "blocks" {

  deployment_targets {
    organizational_unit_ids = [data.aws_organizations_organization.current.roots[0].id]
  }

  operation_preferences {
    failure_tolerance_percentage = try(var.failure_tolerance_percentage, null)
    max_concurrent_percentage    = try(var.max_concurrent_percentage, null)
    region_concurrency_type      = try(var.region_concurrency_type, null)
  }
  
  region = var.aws_region

  stack_set_name = aws_cloudformation_stack_set.blocks.name
}

data "aws_organizations_organization" "current" {}
