output "cur_bucket_name" {
  description = "Name of the S3 bucket storing CUR data"
  value       = module.blocks_onboarding.cur_bucket_name
}

output "blocks_read_role_arn" {
  description = "Cross-account role ARN"
  value       = module.blocks_onboarding.blocks_read_role_arn
}

output "cur2_export_name" {
  description = "Name of the BCM Data Export"
  value       = module.blocks_onboarding.cur2_export_name
}

output "cur2_export_arn" {
  description = "Name of the BCM Data Export"
  value       = module.blocks_onboarding.cur2_export_arn
}

output "next_steps" {
  description = "Next steps to backfill the data"
  value       = module.blocks_onboarding.next_steps
}
