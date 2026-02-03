############################
# Enable Organization Services
# Enables Cost Optimization Hub and Compute Optimizer across the organization
############################

resource "terraform_data" "enable_org_services" {
  # Only run on create (triggers_replace would force recreation)
  input = {
    customer_id = var.customer_id
  }

  provisioner "local-exec" {
    command     = "bash ${path.module}/scripts/enable_org_services.sh"
    working_dir = path.module
  }
}

############################
# Cost Allocation Tag Backfill (Conditional)
# Triggers 12-month backfill of cost allocation tags
############################

resource "terraform_data" "enable_cost_allocation_backfill" {
  count = var.enable_cost_allocation_backfill ? 1 : 0

  # Depends on CUR export being created first
  depends_on = [aws_bcmdataexports_export.cur2]

  # Only run on create
  input = {
    customer_id = var.customer_id
  }

  provisioner "local-exec" {
    command     = "bash ${path.module}/scripts/enable_cost_allocation_backfill.sh"
    working_dir = path.module
  }
}
