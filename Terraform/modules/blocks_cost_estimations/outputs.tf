############################
# Primary Outputs
# Used by examples and downstream modules
############################

output "read_role_arn" {
  description = "ARN of the BlocksEstimationsReadRole for cross-account access"
  value       = aws_iam_role.blocks_estimations_read_role.arn
}

output "read_role_name" {
  description = "Name of the BlocksEstimationsReadRole"
  value       = aws_iam_role.blocks_estimations_read_role.name
}

output "notifier_role_arn" {
  description = "ARN of the BlocksEstimationsNotifierRole for SQS notifications"
  value       = aws_iam_role.blocks_estimations_notifier_role.arn
}

output "stackset_id" {
  description = "ID of the deployed StackSet (empty if not management account or StackSet disabled)"
  value       = local.is_management_account && local.deploy_stackset ? aws_cloudformation_stack_set.cost_estimations[0].id : ""
}

output "customer_resource_id" {
  description = "Customer resource ID used for resource naming"
  value       = var.customer_resource_id
}

output "organization_root_id" {
  description = "Organization root ID (empty if not management account)"
  value       = local.organization_root_id != null ? local.organization_root_id : ""
}

output "management_account_id" {
  description = "Management account ID (empty if not in an organization)"
  value       = local.management_account_id != null ? local.management_account_id : ""
}

output "detected_account_type" {
  description = "Auto-detected account type: management, member, or standalone"
  value       = local.detected_account_type
}

############################
# Debugging Summary
# Contains all auto-detected values for verification
############################

output "auto_detection_summary" {
  description = "Summary of all auto-detected values for debugging and verification"
  value = {
    detected_account_type = local.detected_account_type
    has_organization      = local.has_organization
    is_management_account = local.is_management_account
    deploy_stackset       = local.deploy_stackset
    organization_root_id  = local.organization_root_id
    management_account_id = local.management_account_id
    current_account_id    = local.account_id
    current_region        = local.region
    region_is_valid       = local.region_is_valid
  }
}
