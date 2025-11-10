############################
# Historical Backfill
############################

# Set to true to create Lambda function for automated backfill request
# Note: Requires Business or Enterprise support plan
enable_backfill_lambda = false

backfill_months  = 12
support_severity = "low"

############################
# Cross-Account Access
############################

external_account_id = ""

external_id = ""

############################
# Resource Tagging
############################

default_tags = {
  Environment = "production"
  Project     = "blocks-cost-reporting"
  ManagedBy   = "terraform"
}