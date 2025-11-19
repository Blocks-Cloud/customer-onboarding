output "cur_bucket_name" {
  description = "Name of the S3 bucket storing CUR data"
  value       = local.cur_bucket_name
}

output "cur_bucket_arn" {
  description = "ARN of the S3 bucket storing CUR data"
  value       = "arn:aws:s3:::${local.cur_bucket_name}"
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
  value       = local.export_name
}

output "cur2_export_id" {
  description = "ID of the BCM Data Export"
  value       = aws_bcmdataexports_export.cur2.id
}

output "backfill_lambda_arn" {
  description = "ARN of the backfill Lambda function (if enabled)"
  value       = var.enable_backfill_lambda ? aws_lambda_function.backfill_fn[0].arn : null
}

output "next_steps" {
  description = "Instructions for completing setup"
  value       = var.enable_backfill_lambda ? "Backfill Lambda created. Invoke manually: aws lambda invoke --function-name ${local.export_name}-backfill --payload '{}' response.json" : "To request historical data backfill, open an AWS Support case requesting ${var.backfill_months} months of data for export '${local.export_name}'"
}