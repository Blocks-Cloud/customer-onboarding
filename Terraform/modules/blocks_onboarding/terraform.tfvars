############################
# Historical Backfill
############################

# Set to true to create Lambda function for automated backfill request
# Note: Requires Business or Enterprise support plan
enable_backfill_lambda = true

support_severity = "low"

template_version = "1.0.0"

############################
# Resource Tagging
############################

default_tags = {
  Project   = "blocks-cost-reporting"
  ManagedBy = "terraform"
}