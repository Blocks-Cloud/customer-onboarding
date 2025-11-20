provider "aws" {
  region = "us-east-1"
}

module "blocks_onboarding" {
source = "git::https://github.com/Blocks-Cloud/customer-onboarding.git//Terraform/modules/blocks_onboarding?ref=v1.0.0"

  enable_backfill_lambda = true
  support_severity       = "low"

  # StackSet configuration
  template_version        = "1.0.0"

  default_tags = {
    Environment = "Example"
    Project     = "BlocksOnboarding"
  }
}
