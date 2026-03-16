############################
# IAM Role Outputs
############################

output "execution_role_arn" {
  description = "ARN of the BlocksExecutionRole for cost optimization actions"
  value       = aws_iam_role.blocks_execution_role.arn
}

output "execution_role_name" {
  description = "Name of the BlocksExecutionRole"
  value       = aws_iam_role.blocks_execution_role.name
}

output "read_role_arn" {
  description = "ARN of the BlocksReadRole for read-only cost analysis"
  value       = aws_iam_role.blocks_read_role.arn
}

output "read_role_name" {
  description = "Name of the BlocksReadRole"
  value       = aws_iam_role.blocks_read_role.name
}

output "majortom_read_role_arn" {
  description = "ARN of the MajorTomReadRole for AI read-only access"
  value       = aws_iam_role.majortom_read_role.arn
}

############################
# Organization Outputs
############################

output "account_type" {
  description = "Type of AWS account: management (Step 2 always runs on management)"
  value       = "management"
}

output "organization_root_id" {
  description = "Organization root ID for StackSet deployment"
  value       = local.organization_root_id
}

output "management_account_id" {
  description = "AWS Organizations management account ID"
  value       = local.management_account_id
}

############################
# StackSet Outputs
############################

output "stackset_id" {
  description = "ID of the CloudFormation StackSet for member accounts"
  value       = local.is_management_account ? aws_cloudformation_stack_set.cost_optimization[0].id : null
}

output "stackset_name" {
  description = "Name of the CloudFormation StackSet"
  value       = local.is_management_account ? aws_cloudformation_stack_set.cost_optimization[0].name : null
}

############################
# EventBridge Forwarding Outputs
############################

output "event_forwarding_role_arn" {
  description = "ARN of the BlocksEventBridgeCrossAccountRole for event forwarding"
  value       = aws_iam_role.blocks_event_bridge_cross_account_role.arn
}

output "cloudtrail_forwarding_rule_arn" {
  description = "ARN of the blocks-cloudtrail-forwarding EventBridge rule (management account, us-east-1)"
  value       = aws_cloudwatch_event_rule.blocks_cloudtrail_forwarding.arn
}

output "event_forwarding_stackset_id" {
  description = "ID of the EventForwarding StackSet for multi-region deployment"
  value       = local.is_management_account ? aws_cloudformation_stack_set.event_forwarding[0].id : null
}

############################
# SCP Policy Outputs
############################

output "savings_plans_scp_id" {
  description = "ID of the Savings Plans deny SCP policy"
  value       = local.is_management_account ? aws_organizations_policy.savings_plans_deny[0].id : null
}

output "savings_plans_scp_arn" {
  description = "ARN of the Savings Plans deny SCP policy"
  value       = local.is_management_account ? aws_organizations_policy.savings_plans_deny[0].arn : null
}

output "governance_scp_id" {
  description = "ID of the Blocks Governance deny SCP policy (attached to BlocksOptimization OU)"
  value       = local.is_management_account ? aws_organizations_policy.blocks_governance[0].id : null
}

output "governance_scp_arn" {
  description = "ARN of the Blocks Governance deny SCP policy"
  value       = local.is_management_account ? aws_organizations_policy.blocks_governance[0].arn : null
}

############################
# Organizational Unit Outputs
############################

output "blocks_optimization_ou_id" {
  description = "Organizational Unit ID for Blocks-managed accounts (exempted from Savings Plans SCP)"
  value       = local.is_management_account ? aws_organizations_organizational_unit.blocks_optimization[0].id : null
}

output "blocks_optimization_ou_arn" {
  description = "ARN of the Blocks Optimization OU"
  value       = local.is_management_account ? aws_organizations_organizational_unit.blocks_optimization[0].arn : null
}
