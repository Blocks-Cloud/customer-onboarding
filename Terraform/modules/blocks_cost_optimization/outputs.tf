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

############################
# External Event Conductor
############################

output "external_event_bus_arn" {
  description = "ARN of the External Event Conductor EventBridge bus"
  value       = aws_cloudwatch_event_bus.external_event_conductor.arn
}

output "external_event_bus_name" {
  description = "Name of the External Event Conductor EventBridge bus"
  value       = aws_cloudwatch_event_bus.external_event_conductor.name
}

############################
# Terraform State File ETL Worker
############################

output "tf_state_etl_worker_lambda_arn" {
  description = "ARN of the Terraform State File ETL Worker Lambda"
  value       = aws_lambda_function.tf_state_etl_worker.arn
}

output "tf_state_etl_worker_role_arn" {
  description = "ARN of the Terraform State File ETL Worker Lambda execution role"
  value       = aws_iam_role.tf_state_etl_worker.arn
}

output "tf_state_etl_worker_config_parameter" {
  description = "SSM Parameter name for ETL Worker config"
  value       = aws_ssm_parameter.tf_state_etl_worker_config.name
}

############################
# Loopback Communication
############################

output "loopback_prep_worker_lambda_arn" {
  description = "ARN of the Loopback Communication Prep Worker Lambda"
  value       = aws_lambda_function.loopback_prep_worker.arn
}

output "loopback_prep_worker_role_arn" {
  description = "ARN of the Loopback Communication Prep Worker Lambda execution role"
  value       = aws_iam_role.loopback_prep_worker.arn
}

output "loopback_worker_lambda_arn" {
  description = "ARN of the Loopback Communication Worker Lambda"
  value       = aws_lambda_function.loopback_worker.arn
}

output "loopback_worker_role_arn" {
  description = "ARN of the Loopback Communication Worker Lambda execution role"
  value       = aws_iam_role.loopback_worker.arn
}
