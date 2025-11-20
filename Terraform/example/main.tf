provider "aws" {
  region = "us-east-1"
}

module "blocks_onboarding" {
  source = "../modules/blocks_onboarding"

  # Required variables (or those you want to override)
  blocks_external_account_id = "503132503926"
  external_id                = "blocks-shared-secret-example"

  # Optional: Override defaults
  bucket_name_prefix     = "blocks-cur-data-example"
  enable_backfill_lambda = true
  support_severity       = "low"

  # StackSet configuration
  stack_set_name          = "Blocks-SubAccounts-Example"
  auto_deployment_enabled = true
  max_concurrent_count    = 50
  template_version        = "1.0.0"

  default_tags = {
    Environment = "Example"
    Project     = "BlocksOnboarding"
  }
}
