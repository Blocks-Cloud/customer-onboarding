# ============================================================================
# Blocks.cloud — GCP Cost Estimations onboarding (Step 1, read-only)
#
# IaC analog of CloudShell/gcp/step1/blocks-gcp-estimations.sh. Everything
# here is read-only; nothing can modify your resources:
#   - A Workload Identity Pool + AWS provider that ONLY accepts Blocks'
#     shared cost-scanner AWS identity (CEL attribute condition pinning the
#     Blocks scanner role — confused-deputy protection; no keys are created
#     or exchanged)
#   - A read-only service account
#   - Narrow viewer-role bindings at your chosen scope (iam.tf, generated
#     from iam-policies/gcp/ — single source of truth)
#
# Tenant isolation is this pool + service account (which only the customer
# owns), not the pinned AWS role: that role is Blocks' shared scanner identity,
# the same for every customer — the GCP analog of the shared
# BlocksCustomerAccessRole on the AWS side. See docs/gcp-onboarding-design.md §4.
# ============================================================================

data "google_project" "host" {
  project_id = var.project_id
}

locals {
  # Scope the impersonation grant (in iam.tf) to the scanner's AWS role via
  # attribute.aws_role rather than the whole pool (GCP best practice: grant
  # workloadIdentityUser to specific identities, not all pool members). The
  # provider maps attribute.aws_role to the BARE role name, so the principal
  # uses the bare name too.
  wif_pool_principal = "principalSet://iam.googleapis.com/projects/${data.google_project.host.number}/locations/global/workloadIdentityPools/${google_iam_workload_identity_pool.blocks_scanner.workload_identity_pool_id}/attribute.aws_role/${var.scanner_pod_role_name}"

  required_apis = [
    "iam.googleapis.com",
    "iamcredentials.googleapis.com",
    "sts.googleapis.com",
    "cloudresourcemanager.googleapis.com",
    "compute.googleapis.com",
    "monitoring.googleapis.com",
    "recommender.googleapis.com",
    "cloudbilling.googleapis.com",
  ]
}

# Enables the required APIs on the HOST project only. Unlike IAM bindings — a
# folder/org grant is inherited hierarchy-wide — API enablement is PER-PROJECT.
# For scope = folder|org, every child project you want covered must have these
# same APIs enabled, notably recommender.googleapis.com (off by default).
# Automated per-project enablement is deferred until the Blocks scanner fans out
# across the hierarchy (BLO-3814); see docs/gcp-onboarding-design.md §5.
resource "google_project_service" "required" {
  for_each = toset(local.required_apis)

  project            = var.project_id
  service            = each.value
  disable_on_destroy = false
}

# ─── Workload Identity Pool + AWS provider ──────────────────────────────────

resource "google_iam_workload_identity_pool" "blocks_scanner" {
  project                   = var.project_id
  workload_identity_pool_id = var.wif_pool_id
  display_name              = "Blocks scanner"
  description               = "Keyless federation for the Blocks.cloud cost scanner (read-only)"

  depends_on = [google_project_service.required]
}

# The attribute condition pins Blocks' shared scanner AWS role ARN — only that
# identity can authenticate through this provider (confused-deputy protection).
# attribute.aws_role is mapped to the BARE role name so the SA impersonation
# grant (iam.tf) can be scoped to that role. The default AWS mapping would
# resolve attribute.aws_role to the full assumed-role ARN, so it is set
# explicitly here to match var.scanner_pod_role_name.
resource "google_iam_workload_identity_pool_provider" "blocks_aws" {
  project                            = var.project_id
  workload_identity_pool_id          = google_iam_workload_identity_pool.blocks_scanner.workload_identity_pool_id
  workload_identity_pool_provider_id = var.wif_provider_id
  display_name                       = "Blocks AWS"
  attribute_condition                = "assertion.arn.startsWith('${var.scanner_pod_role_arn}')"

  attribute_mapping = {
    "google.subject"     = "assertion.arn"
    "attribute.aws_role" = "assertion.arn.extract('assumed-role/{role_name}/')"
  }

  aws {
    account_id = var.scanner_aws_account_id
  }
}

# ─── Read-only service account ──────────────────────────────────────────────

resource "google_service_account" "blocks_scanner" {
  project      = var.project_id
  account_id   = var.scanner_sa_name
  display_name = "Blocks Cost Estimations (read-only)"
  description  = "Used by Blocks.cloud to analyze cost savings. Must remain in place for Blocks to function correctly. Email support@blocks.cloud for assistance."

  depends_on = [google_project_service.required]

  lifecycle {
    precondition {
      condition     = var.scope != "folder" || (var.folder_id != "" && var.org_id != "")
      error_message = "scope = folder requires both folder_id and org_id (custom roles are created at the org and bound at the folder)."
    }
    precondition {
      condition     = var.scope != "org" || var.org_id != ""
      error_message = "scope = org requires org_id."
    }
  }
}
