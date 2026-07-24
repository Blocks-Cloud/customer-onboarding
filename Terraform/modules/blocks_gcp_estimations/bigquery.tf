# ============================================================================
# Blocks.cloud — GCP billing-export dataset read (BLO-3942)
#
# Grants the read-only scanner service account roles/bigquery.dataViewer on the
# customer's Cloud Billing BigQuery export dataset, so Blocks can read spend
# from the detailed usage-cost export — the GCP analog of read access to the
# AWS CUR bucket (FOCUS cost-plane, BLO-3664).
#
# Why this is hand-authored here and NOT in the generated iam.tf: iam.tf is the
# single-source-of-truth section the roleset generator owns, and that generator
# only models project|folder|org scope dispatch. This grant is DATASET-scoped —
# its target is a per-deployment (project, dataset) pair the customer supplies,
# orthogonal to that scope axis — so it is structural, in the same category as
# the WIF pool and service account (see iam-policies/gcp/README.md, "generated
# vs structural", and decision D1 of the FOCUS cost-plane spike, BLO-3939).
#
# The binding is ADDITIVE (google_bigquery_dataset_iam_member): it adds exactly
# this one member to this one role and leaves the customer's existing dataset
# access untouched. Enabling a detailed, EU/US multi-region export is a
# console-only manual step — see docs/gcp-billing-export.md.
# ============================================================================

locals {
  # Grant only when BOTH coordinates are supplied. Absent (the default) means
  # the customer has no export yet, or spend ingest is out of scope for this
  # deployment — either way the read-only cost-estimations surface stands alone.
  # "Both or neither" is enforced by a precondition on the service account in
  # main.tf so a half-set pair fails loudly instead of silently skipping.
  grant_billing_export = var.billing_export_project_id != "" && var.billing_export_dataset_id != ""
}

resource "google_bigquery_dataset_iam_member" "billing_export_reader" {
  count = local.grant_billing_export ? 1 : 0

  project    = var.billing_export_project_id
  dataset_id = var.billing_export_dataset_id
  role       = "roles/bigquery.dataViewer"
  member     = "serviceAccount:${google_service_account.blocks_scanner.email}"
}
