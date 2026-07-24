############################
# Primary Outputs
# Paste these into the Blocks dashboard (or feed them to blocks_cli) —
# Blocks verifies the connection automatically (status: pending -> healthy).
############################

output "service_account_email" {
  description = "Email of the read-only Blocks scanner service account"
  value       = google_service_account.blocks_scanner.email
}

output "wif_audience" {
  description = "Workload Identity provider audience Blocks uses to federate (//iam.googleapis.com/...)"
  value       = "//iam.googleapis.com/${google_iam_workload_identity_pool_provider.blocks_aws.name}"
}

output "customer_resource_id" {
  description = "Customer resource ID used for resource naming"
  value       = var.customer_resource_id
}

output "scope" {
  description = "Scope the read-only access was granted at (project, folder, or org)"
  value       = var.scope
}

output "billing_export_reader_granted" {
  description = "Whether this module manages a billing-export dataset read binding (coordinates supplied and the google_bigquery_dataset_iam_member is present)"
  value       = length(google_bigquery_dataset_iam_member.billing_export_reader) > 0
}
