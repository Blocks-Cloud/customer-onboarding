# Role grants for the Blocks scanner service account. The section between the
# markers is generated from iam-policies/gcp/ (single source of truth shared
# with the Cloud Shell onboarding script) — edit the roleset JSON and re-run
# generate_gcp_iam.py --inject; never edit the generated section by hand.

# ==== BEGIN GENERATED GCP IAM ====
# Source: iam-policies/gcp/ — regenerate with generate_gcp_iam.py
# DO NOT EDIT MANUALLY
# Roleset: BlocksGcpEstimationsRead (step1, read_only)
# Scope is var.scope (project|folder|org) — count guards select the
# matching resources; custom roles for folder scope live at the org.

# GCP IAM Roleset: Blocks Cost Estimations (Step 1, read-only)
# Least-privilege by construction: GCP IAM deny policies cover only a subset of
# permissions, so unlike AWS there is no broad-allow + deny-shield pattern here.
# Safety comes from granting ONLY the narrow roles below.

# Custom role instead of a predefined roles/recommender.* role: strict least-privilege, auditable in-repo, independent of the predefined-role catalog (decision Q2, docs/gcp-onboarding-design.md)
# Planes: Recommender
resource "google_project_iam_custom_role" "blocks_recommender_read_project" {
  count       = var.scope == "project" ? 1 : 0
  project     = var.project_id
  role_id     = "blocksRecommenderRead_${replace(var.customer_resource_id, "-", "_")}"
  title       = "Blocks Recommender Read"
  description = "Read access to Google Cloud Recommender cost recommendations for Blocks.cloud cost estimations. Managed by Blocks onboarding."
  stage       = "GA"
  permissions = [
    "recommender.computeInstanceMachineTypeRecommendations.list",
    "recommender.computeInstanceIdleResourceRecommendations.list",
    "recommender.computeDiskIdleResourceRecommendations.list",
    "recommender.computeAddressIdleResourceRecommendations.list",
    "recommender.usageCommitmentRecommendations.list",
  ]
}

resource "google_organization_iam_custom_role" "blocks_recommender_read_org" {
  count       = var.scope == "project" ? 0 : 1
  org_id      = var.org_id
  role_id     = "blocksRecommenderRead_${replace(var.customer_resource_id, "-", "_")}"
  title       = "Blocks Recommender Read"
  description = "Read access to Google Cloud Recommender cost recommendations for Blocks.cloud cost estimations. Managed by Blocks onboarding."
  stage       = "GA"
  permissions = [
    "recommender.computeInstanceMachineTypeRecommendations.list",
    "recommender.computeInstanceIdleResourceRecommendations.list",
    "recommender.computeDiskIdleResourceRecommendations.list",
    "recommender.computeAddressIdleResourceRecommendations.list",
    "recommender.usageCommitmentRecommendations.list",
  ]
}

# Compute Engine read-only: region/zone discovery (compute.regions.list + compute.regions.get) for the scan region grid and per-zone recommender enumeration, plus instances, disks, addresses for native orphan/idle detection
# Planes: Compute inventory
resource "google_project_iam_member" "blocks_scanner_compute_viewer_project" {
  count   = var.scope == "project" ? 1 : 0
  project = var.project_id
  role    = "roles/compute.viewer"
  member  = "serviceAccount:${google_service_account.blocks_scanner.email}"
}

resource "google_folder_iam_member" "blocks_scanner_compute_viewer_folder" {
  count  = var.scope == "folder" ? 1 : 0
  folder = var.folder_id
  role   = "roles/compute.viewer"
  member = "serviceAccount:${google_service_account.blocks_scanner.email}"
}

resource "google_organization_iam_member" "blocks_scanner_compute_viewer_org" {
  count  = var.scope == "org" ? 1 : 0
  org_id = var.org_id
  role   = "roles/compute.viewer"
  member = "serviceAccount:${google_service_account.blocks_scanner.email}"
}

# Cloud Monitoring read-only: CPU/memory metrics (8-day rightsize window, 14-day idle window)
# Planes: Cloud Monitoring
resource "google_project_iam_member" "blocks_scanner_monitoring_viewer_project" {
  count   = var.scope == "project" ? 1 : 0
  project = var.project_id
  role    = "roles/monitoring.viewer"
  member  = "serviceAccount:${google_service_account.blocks_scanner.email}"
}

resource "google_folder_iam_member" "blocks_scanner_monitoring_viewer_folder" {
  count  = var.scope == "folder" ? 1 : 0
  folder = var.folder_id
  role   = "roles/monitoring.viewer"
  member = "serviceAccount:${google_service_account.blocks_scanner.email}"
}

resource "google_organization_iam_member" "blocks_scanner_monitoring_viewer_org" {
  count  = var.scope == "org" ? 1 : 0
  org_id = var.org_id
  role   = "roles/monitoring.viewer"
  member = "serviceAccount:${google_service_account.blocks_scanner.email}"
}

# Bind custom role: blocksRecommenderRead
resource "google_project_iam_member" "blocks_scanner_blocks_recommender_read_project" {
  count   = var.scope == "project" ? 1 : 0
  project = var.project_id
  role    = google_project_iam_custom_role.blocks_recommender_read_project[0].name
  member  = "serviceAccount:${google_service_account.blocks_scanner.email}"
}

resource "google_folder_iam_member" "blocks_scanner_blocks_recommender_read_folder" {
  count  = var.scope == "folder" ? 1 : 0
  folder = var.folder_id
  role   = google_organization_iam_custom_role.blocks_recommender_read_org[0].name
  member = "serviceAccount:${google_service_account.blocks_scanner.email}"
}

resource "google_organization_iam_member" "blocks_scanner_blocks_recommender_read_org" {
  count  = var.scope == "org" ? 1 : 0
  org_id = var.org_id
  role   = google_organization_iam_custom_role.blocks_recommender_read_org[0].name
  member = "serviceAccount:${google_service_account.blocks_scanner.email}"
}

# Lets the Blocks scanner impersonate this SA, scoped to attribute.aws_role/<scanner pod-role name> — not the whole pool. The pool provider's CEL attribute condition (structural, in the script/module) pins Blocks' shared scanner pod-role ARN; tenant isolation is the customer-owned pool + SA (BLO-3815, docs/gcp-onboarding-design.md §4)
resource "google_service_account_iam_member" "blocks_scanner_wif_user" {
  service_account_id = google_service_account.blocks_scanner.name
  role               = "roles/iam.workloadIdentityUser"
  member             = local.wif_pool_principal
}

# ==== END GENERATED GCP IAM ====
