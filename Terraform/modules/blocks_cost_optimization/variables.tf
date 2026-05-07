############################
# Required Variables
############################

variable "customer_resource_id" {
  type        = string
  description = "Unique resource identifier assigned by Blocks to distinguish each client's deployed infrastructure (e.g., 'acme-corp-12345')"

  validation {
    condition     = can(regex("^[a-zA-Z0-9-_]+$", var.customer_resource_id))
    error_message = "customer_resource_id must contain only alphanumeric characters, hyphens, and underscores."
  }

  validation {
    condition     = length(var.customer_resource_id) <= 30
    error_message = "customer_resource_id must be 30 characters or less to avoid IAM role name length limits."
  }
}

variable "external_id" {
  type        = string
  description = "External ID for cross-account role assumption (security token)"

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

variable "event_forwarding_template_url" {
  type        = string
  description = "S3 URL for the EventForwarding CloudFormation template deployed via multi-region StackSet to member accounts"
  default     = "https://blocks-customer-templates-production.s3.eu-central-1.amazonaws.com/shared/Blocks-EventForwarding.yaml"

  validation {
    condition     = can(regex("^https://", var.event_forwarding_template_url))
    error_message = "event_forwarding_template_url must be a valid HTTPS URL (e.g., https://bucket.s3.us-east-1.amazonaws.com/Blocks-EventForwarding.yaml)."
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
  default     = "0.1.59" # x-release-please-version

  validation {
    condition     = length(var.template_version) > 0
    error_message = "template_version must not be empty."
  }
}

variable "internal" {
  type        = bool
  description = "Mark this as an internal test customer"
  default     = false
}
