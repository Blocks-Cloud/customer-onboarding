############################
# S3 Bucket Outputs
############################

output "cur_bucket_name" {
  description = "Name of the S3 bucket storing CUR 2.0 data"
  value       = aws_s3_bucket.cur_bucket.id
}

output "cur_bucket_arn" {
  description = "ARN of the S3 bucket storing CUR 2.0 data"
  value       = aws_s3_bucket.cur_bucket.arn
}

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
# BCM Export Outputs
############################

output "bcm_export_arn" {
  description = "ARN of the BCM Data Export (CUR 2.0)"
  value       = aws_bcmdataexports_export.cur2.arn
}
