provider "aws" {
  region = var.aws_region # Please do not change this region, it must be us-east-1
}

module "blocks_onboarding" {
  source = "github.com/Blocks-Cloud/customer-onboarding.git/Terraform/modules/blocks_onboarding?ref=v1.0.0"

  aws_region = var.aws_region

  create_backfill_support_case = var.create_backfill_support_case

  # StackSet configuration
  template_version = "1.0.0"

  default_tags = {
    Environment = "Example"
    Project     = "BlocksOnboarding"
  }
}
