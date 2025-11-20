output "cur_bucket_name" {
  description = "Name of the S3 bucket storing CUR data"
  value       = local.blocks_resource_name
}

output "cur_bucket_arn" {
  description = "ARN of the S3 bucket storing CUR data"
  value       = "arn:aws:s3:::${local.blocks_resource_name}"
}

output "blocks_read_role_arn" {
  description = "Cross-account role ARN with read-only access to CUR S3 data, billing services, and 40+ AWS services for complete cost visibility and optimization"
  value       = aws_iam_role.blocks_read_role.arn
}

output "blocks_read_role_name" {
  description = "Cross-account role Name with read-only access to CUR S3 data, billing services, and 40+ AWS services for complete cost visibility and optimization"
  value       = aws_iam_role.blocks_read_role.name
}

output "cur2_export_name" {
  description = "Name of the BCM Data Export"
  value       = local.blocks_resource_name
}

output "cur2_export_arn" {
  description = "ARN of the BCM Data Export"
  value       = aws_bcmdataexports_export.cur2.arn
}

output "backfill_lambda_arn" {
  description = "ARN of the backfill Lambda function (if enabled)"
  value       = var.enable_automatic_backfill ? aws_lambda_function.backfill_fn[0].arn : null
}

output "next_steps" {
  description = "Instructions for completing setup"

  value = var.enable_automatic_backfill ? "Backfill support case created. Please wait for AWS Support to process your request." : <<EOF
To request historical data backfill, open an AWS Support case.

Use the following details for the support request:

Subject:
Request historical data backfill for CUR 2.0 export ${local.blocks_resource_name}

Body:
Hello AWS Support,

We are requesting assistance with backfilling a CUR 2.0 Data Export according to the requirements below.

Please backfill the existing ${local.blocks_resource_name} report from the:
s3://${local.blocks_resource_name}/cur2/${local.blocks_resource_name}/data
S3 bucket.

We need historical data for the following period: 01.01.2022 through the current date.

Thank you.
EOF
}

