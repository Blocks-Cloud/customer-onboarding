

############################
# Data Sources
############################

data "aws_caller_identity" "current" {}
data "aws_region" "current" {}

locals {
  cur_bucket_name = var.use_existing_bucket ? var.existing_bucket_name : "${var.bucket_name_prefix}-${data.aws_caller_identity.current.account_id}-${data.aws_region.current.name}"
  export_name     = "${var.export_name}-${data.aws_caller_identity.current.account_id}"

  common_tags = merge(
    var.default_tags,
    {
      OwnedBy = "Blocks.cloud"
      Purpose = "CostAndUsageReport"
    }
  )
}
