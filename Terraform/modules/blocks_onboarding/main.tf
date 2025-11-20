############################
# Data Sources
############################

data "aws_caller_identity" "current" {}
data "aws_region" "current" {}

locals {
  blocks_resource_name = "blocks-cur-data-${data.aws_caller_identity.current.account_id}"

  common_tags = merge(
    var.default_tags,
    {
      OwnedBy = "Blocks.cloud"
      Purpose = "CostAndUsageReport"
    }
  )
}
