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
}

variable "external_id" {
  type        = string
  description = "External ID for cross-account role assumption (security token)"
  sensitive   = true

  validation {
    condition     = length(var.external_id) >= 6
    error_message = "external_id must be at least 6 characters long for security."
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
  description = "S3 URL for the SubAccounts CloudFormation template (required for StackSet deployment)"

  validation {
    condition     = can(regex("^https://", var.stackset_template_url))
    error_message = "stackset_template_url must be a valid HTTPS URL (e.g., https://bucket.s3.region.amazonaws.com/template.yaml)"
  }
}

variable "template_version" {
  type        = string
  description = "Template version for deployment tracking and SQS notifications"
  default     = "v0.1.5"

  validation {
    condition     = length(var.template_version) > 0
    error_message = "template_version must not be empty."
  }
}
