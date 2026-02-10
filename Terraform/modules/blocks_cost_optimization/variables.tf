############################
# Required Variables
############################

variable "customer_id" {
  type        = string
  description = "Unique customer identifier used for resource naming (e.g., 'acme-corp-12345')"

  validation {
    condition     = can(regex("^[a-zA-Z0-9-_]+$", var.customer_id))
    error_message = "customer_id must contain only alphanumeric characters, hyphens, and underscores."
  }

  validation {
    condition     = length(var.customer_id) <= 30
    error_message = "customer_id must be 30 characters or less to avoid IAM role name length limits."
  }
}

variable "external_id" {
  type        = string
  description = "External ID for cross-account role assumption (security token)"
  sensitive   = true

  validation {
    condition     = length(var.external_id) >= 10
    error_message = "external_id must be at least 10 characters long for security."
  }
}

variable "blocks_account_id" {
  type        = string
  description = "Blocks AWS account ID (production: 810801871908, development: 532003627937)"

  validation {
    condition     = can(regex("^[0-9]{12}$", var.blocks_account_id))
    error_message = "blocks_account_id must be a valid 12-digit AWS account ID."
  }
}

############################
# Optional Variables
############################

variable "stackset_template_url" {
  type        = string
  description = "S3 URL for the SubAccounts CloudFormation template deployed via StackSet to member accounts"

  validation {
    condition     = can(regex("^https://", var.stackset_template_url))
    error_message = "stackset_template_url must be a valid HTTPS URL (e.g., https://bucket.s3.us-east-1.amazonaws.com/template.yaml)."
  }
}

variable "enable_cost_allocation_backfill" {
  type        = bool
  description = "Enable 12-month cost allocation tag backfill. Only runs once per day per AWS account."
  default     = true
}

variable "cur_data_retention_days" {
  type        = number
  description = "Days to retain CUR data in S3 before expiration"
  default     = 365

  validation {
    condition     = var.cur_data_retention_days >= 30
    error_message = "cur_data_retention_days must be at least 30 days for meaningful cost analysis."
  }
}

variable "default_tags" {
  type        = map(string)
  description = "Default tags to apply to all resources"
  default     = {}
}

variable "target_ou_ids" {
  type        = list(string)
  description = "List of Organization Unit IDs to target for StackSet deployment. Empty list deploys to all accounts (organization root)."
  default     = []

  validation {
    condition     = alltrue([for ou in var.target_ou_ids : can(regex("^(ou-[a-z0-9]{4,32}-[a-z0-9]{8,32}|r-[a-z0-9]{4,32})$", ou))])
    error_message = "Each target_ou_ids entry must be a valid OU ID (ou-xxxx-xxxxxxxx) or organization root ID (r-xxxx)."
  }
}

variable "template_version" {
  type        = string
  description = "Template version for deployment tracking and SQS notifications"
  default     = "v0.1.7"

  validation {
    condition     = length(var.template_version) > 0
    error_message = "template_version must not be empty."
  }
}

