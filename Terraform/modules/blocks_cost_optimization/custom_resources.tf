############################
# Enable Organization Services
# Enables Cost Optimization Hub and Compute Optimizer across the organization
############################

resource "terraform_data" "enable_org_services" {
  count = local.is_management_account ? 1 : 0

  # Force re-run when script content changes
  triggers_replace = {
    script_hash = filemd5("${path.module}/scripts/enable_org_services.sh")
  }

  provisioner "local-exec" {
    command     = "bash scripts/enable_org_services.sh"
    working_dir = path.module
  }
}

