# Role grants for the Blocks scanner service account. The section between the
# markers is generated (shared with the Cloud Shell onboarding script); never
# edit it by hand.

# ==== BEGIN GENERATED GCP IAM ====
# DO NOT EDIT MANUALLY
# Roleset: BlocksGcpEstimationsRead (step1, read_only)
# Scope is var.scope (project|folder|org) — count guards select the
# matching resources; custom roles for folder scope live at the org.

# GCP IAM Roleset: Blocks Cost Estimations (Step 1, read-only)
# Least-privilege by construction: GCP IAM deny policies cover only a subset of
# permissions, so unlike AWS there is no broad-allow + deny-shield pattern here.
# Safety comes from granting ONLY the narrow roles below.

# Single custom role replacing roles/compute.viewer + roles/monitoring.viewer: strict least-privilege, auditable in-repo, independent of the predefined-role catalog.
# Planes: Compute inventory, Cloud Monitoring, Recommender, Cloud Storage (bucket metadata), Cloud Asset Inventory (search), Memorystore for Redis (instance metadata)
resource "google_project_iam_custom_role" "blocks_estimations_read_project" {
  count       = var.scope == "project" ? 1 : 0
  project     = var.project_id
  role_id     = "blocksEstimationsRead_${replace(var.customer_resource_id, "-", "_")}"
  title       = "Blocks Cost Estimations Read"
  description = "Read access for Blocks.cloud cost estimations: Compute inventory, Monitoring metrics, Recommender cost recommendations, Storage and Memorystore metadata, Cloud Asset Inventory search (full config, incl. Cloud Run env vars), billing metadata. Managed by Blocks onboarding."
  stage       = "GA"
  permissions = [
    "compute.regions.list",
    "compute.regions.get",
    "compute.zones.list",
    "compute.zones.get",
    "compute.instances.list",
    "compute.instances.get",
    "compute.disks.list",
    "compute.disks.get",
    "compute.addresses.list",
    "compute.addresses.get",
    "compute.globalAddresses.list",
    "compute.globalAddresses.get",
    "compute.snapshots.get",
    "compute.commitments.list",
    "compute.machineTypes.list",
    "compute.machineTypes.get",
    "monitoring.timeSeries.list",
    "monitoring.metricDescriptors.list",
    "recommender.computeInstanceMachineTypeRecommendations.list",
    "recommender.computeInstanceIdleResourceRecommendations.list",
    "recommender.computeDiskIdleResourceRecommendations.list",
    "recommender.computeAddressIdleResourceRecommendations.list",
    "recommender.usageCommitmentRecommendations.list",
    "recommender.spendBasedCommitmentRecommendations.list",
    "recommender.computeIdleResourceRecommendations.list",
    "recommender.computeImageIdleResourceRecommendations.list",
    "recommender.computeInstanceGroupManagerMachineTypeRecommendations.list",
    "recommender.cloudsqlIdleInstanceRecommendations.list",
    "recommender.cloudsqlOverprovisionedInstanceRecommendations.list",
    "recommender.containerDiagnosisRecommendations.list",
    "recommender.runServiceCostRecommendations.list",
    "recommender.storageBucketSoftDeleteRecommendations.list",
    "recommender.bigqueryCapacityCommitmentsRecommendations.list",
    "recommender.bigqueryPartitionClusterRecommendations.list",
    "storage.buckets.list",
    "cloudasset.assets.searchAllResources",
    "redis.instances.list",
    "redis.instances.get",
  ]
}

resource "google_organization_iam_custom_role" "blocks_estimations_read_org" {
  count       = var.scope == "project" ? 0 : 1
  org_id      = var.org_id
  role_id     = "blocksEstimationsRead_${replace(var.customer_resource_id, "-", "_")}"
  title       = "Blocks Cost Estimations Read"
  description = "Read access for Blocks.cloud cost estimations: Compute inventory, Monitoring metrics, Recommender cost recommendations, Storage and Memorystore metadata, Cloud Asset Inventory search (full config, incl. Cloud Run env vars), billing metadata. Managed by Blocks onboarding."
  stage       = "GA"
  permissions = [
    "compute.regions.list",
    "compute.regions.get",
    "compute.zones.list",
    "compute.zones.get",
    "compute.instances.list",
    "compute.instances.get",
    "compute.disks.list",
    "compute.disks.get",
    "compute.addresses.list",
    "compute.addresses.get",
    "compute.globalAddresses.list",
    "compute.globalAddresses.get",
    "compute.snapshots.get",
    "compute.commitments.list",
    "compute.machineTypes.list",
    "compute.machineTypes.get",
    "monitoring.timeSeries.list",
    "monitoring.metricDescriptors.list",
    "recommender.computeInstanceMachineTypeRecommendations.list",
    "recommender.computeInstanceIdleResourceRecommendations.list",
    "recommender.computeDiskIdleResourceRecommendations.list",
    "recommender.computeAddressIdleResourceRecommendations.list",
    "recommender.usageCommitmentRecommendations.list",
    "recommender.spendBasedCommitmentRecommendations.list",
    "recommender.computeIdleResourceRecommendations.list",
    "recommender.computeImageIdleResourceRecommendations.list",
    "recommender.computeInstanceGroupManagerMachineTypeRecommendations.list",
    "recommender.cloudsqlIdleInstanceRecommendations.list",
    "recommender.cloudsqlOverprovisionedInstanceRecommendations.list",
    "recommender.containerDiagnosisRecommendations.list",
    "recommender.runServiceCostRecommendations.list",
    "recommender.storageBucketSoftDeleteRecommendations.list",
    "recommender.bigqueryCapacityCommitmentsRecommendations.list",
    "recommender.bigqueryPartitionClusterRecommendations.list",
    "storage.buckets.list",
    "cloudasset.assets.searchAllResources",
    "redis.instances.list",
    "redis.instances.get",
    "billing.accounts.get",
    "billing.accounts.list",
    "billing.resourceAssociations.list",
    "resourcemanager.projects.list",
  ]
}

# Audit-log read for the findings-resolver: the _Required bucket's _AllLogs view only (Admin Activity, System Event, Access Transparency). Application logs and Data Access logs stay unreadable.
# Planes: Cloud Audit Logs (_Required bucket: Admin Activity, System Event, Access Transparency)
resource "google_project_iam_member" "blocks_scanner_logging_view_accessor_project" {
  count   = var.scope == "project" ? 1 : 0
  project = var.project_id
  role    = "roles/logging.viewAccessor"
  member  = "serviceAccount:${google_service_account.blocks_scanner.email}"

  condition {
    title      = "blocks-required-audit-view-only"
    expression = "resource.name.endsWith(\"/buckets/_Required/views/_AllLogs\")"
  }
}

resource "google_folder_iam_member" "blocks_scanner_logging_view_accessor_folder" {
  count  = var.scope == "folder" ? 1 : 0
  folder = var.folder_id
  role   = "roles/logging.viewAccessor"
  member = "serviceAccount:${google_service_account.blocks_scanner.email}"

  condition {
    title      = "blocks-required-audit-view-only"
    expression = "resource.name.endsWith(\"/buckets/_Required/views/_AllLogs\")"
  }
}

resource "google_organization_iam_member" "blocks_scanner_logging_view_accessor_org" {
  count  = var.scope == "org" ? 1 : 0
  org_id = var.org_id
  role   = "roles/logging.viewAccessor"
  member = "serviceAccount:${google_service_account.blocks_scanner.email}"

  condition {
    title      = "blocks-required-audit-view-only"
    expression = "resource.name.endsWith(\"/buckets/_Required/views/_AllLogs\")"
  }
}

# Bind custom role: blocksEstimationsRead
resource "google_project_iam_member" "blocks_scanner_blocks_estimations_read_project" {
  count   = var.scope == "project" ? 1 : 0
  project = var.project_id
  role    = google_project_iam_custom_role.blocks_estimations_read_project[0].name
  member  = "serviceAccount:${google_service_account.blocks_scanner.email}"
}

resource "google_folder_iam_member" "blocks_scanner_blocks_estimations_read_folder" {
  count  = var.scope == "folder" ? 1 : 0
  folder = var.folder_id
  role   = google_organization_iam_custom_role.blocks_estimations_read_org[0].name
  member = "serviceAccount:${google_service_account.blocks_scanner.email}"
}

resource "google_organization_iam_member" "blocks_scanner_blocks_estimations_read_org" {
  count  = var.scope == "org" ? 1 : 0
  org_id = var.org_id
  role   = google_organization_iam_custom_role.blocks_estimations_read_org[0].name
  member = "serviceAccount:${google_service_account.blocks_scanner.email}"
}

# Lets the Blocks scanner impersonate this SA, scoped to attribute.aws_role/<scanner pod-role name> — not the whole pool. The pool provider's CEL attribute condition (structural, in the script/module) pins Blocks' shared scanner pod-role ARN; tenant isolation is the customer-owned pool + SA
resource "google_service_account_iam_member" "blocks_scanner_wif_user" {
  service_account_id = google_service_account.blocks_scanner.name
  role               = "roles/iam.workloadIdentityUser"
  member             = local.wif_pool_principal
}

# ==== END GENERATED GCP IAM ====
