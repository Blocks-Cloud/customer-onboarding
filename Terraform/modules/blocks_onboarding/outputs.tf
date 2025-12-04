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

output "create_backfill_support_case_role_arn" {
  description = "Cross-account role ARN to create a support case to backfill up to 36 months of historical CUR data"
  value       = aws_iam_role.create_backfill_support_case.arn
}

output "create_backfill_support_case_role_name" {
  description = "Cross-account role Name to create a support case to backfill up to 36 months of historical CUR data"
  value       = aws_iam_role.create_backfill_support_case.name
}

output "cur2_export_name" {
  description = "Name of the BCM Data Export"
  value       = local.blocks_resource_name
}

output "cur2_export_arn" {
  description = "ARN of the BCM Data Export"
  value       = aws_bcmdataexports_export.cur2.arn
}


output "next_steps" {
  description = "Instructions for completing setup"

  value = <<EOF
Setup Complete!

Blocks will automatically create an AWS Support case to backfill up to 36 months of historical CUR data.

Note: This role will automatically expire on 31st March 2026 for security.

EOF
}

