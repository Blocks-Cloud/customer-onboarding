############################
# Historical Backfill
############################

# Set to true to create Lambda function for automated backfill request
# Note: Requires Business or Enterprise support plan
enable_backfill_lambda = true

backfill_months = 12

support_severity = "low"

############################
# Cross-Account Access
############################

external_id = ""

############################
# Resource Tagging
############################

default_tags = {
  Project   = "blocks-cost-reporting"
  ManagedBy = "terraform"
}