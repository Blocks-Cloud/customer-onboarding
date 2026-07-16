# The committed .terraform.lock.hcl in this module is load-bearing, not stray
# hygiene: CI runs `terraform init && validate` here standalone (ci.yml), so the
# lock pins a deterministic provider version for that job. Matches the AWS
# modules. See iam-policies/gcp/README.md ("Terraform provider locks").
terraform {
  required_version = ">= 1.3"

  required_providers {
    google = {
      source  = "hashicorp/google"
      version = ">= 5.0"
    }
  }
}
