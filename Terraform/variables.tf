variable "aws_region" {
  type        = string
  description = "AWS region for resources"
  default     = "us-east-1"
}

variable "use_existing_bucket" {
  type        = bool
  default     = false
  description = "Use an existing S3 bucket instead of creating a new one"
}

variable "existing_bucket_name" {
  type        = string
  default     = ""
  description = "Name of existing bucket (required if use_existing_bucket = true)"
  validation {
    condition     = var.use_existing_bucket == false || var.existing_bucket_name != ""
    error_message = "existing_bucket_name must be provided when use_existing_bucket is true"
  }
}

variable "bucket_name_prefix" {
  type        = string
  default     = "blocks-cur-data"
  description = "Prefix for bucket name when creating new bucket"
}

variable "export_name" {
  type        = string
  default     = "hourly-cost-usage-cur2"
  description = "Base name for the CUR 2.0 export"
}

variable "time_granularity" {
  type        = string
  default     = "HOURLY"
  description = "Time granularity for CUR data"
  validation {
    condition     = contains(["HOURLY", "DAILY", "MONTHLY"], var.time_granularity)
    error_message = "time_granularity must be HOURLY, DAILY, or MONTHLY"
  }
}

variable "include_resources" {
  type        = bool
  default     = true
  description = "Include individual resource IDs in CUR"
}

variable "backfill_months" {
  type        = number
  default     = 12
  description = "Months of historical data to request"
  validation {
    condition     = var.backfill_months >= 1 && var.backfill_months <= 24
    error_message = "backfill_months must be between 1 and 24"
  }
}

variable "support_severity" {
  type        = string
  default     = "low"
  description = "AWS Support case severity for backfill request"
  validation {
    condition     = contains(["low", "normal", "high", "urgent", "critical"], var.support_severity)
    error_message = "support_severity must be low, normal, high, urgent, or critical"
  }
}

variable "external_account_id" {
  type        = string
  description = "AWS account ID that will assume the billing read role"
}

variable "external_id" {
  type        = string
  description = "External ID for cross-account role assumption (keep secret)"
  sensitive   = true
}

variable "kms_key_arn" {
  type        = string
  default     = ""
  description = "KMS key ARN for S3 encryption (optional, uses AES256 if not provided)"
}

variable "enable_backfill_lambda" {
  type        = bool
  default     = false
  description = "Create Lambda function to automate backfill request"
}

variable "enable_lifecycle_rules" {
  type        = bool
  default     = true
  description = "Enable S3 lifecycle rules for cost optimization"
}

variable "cur_data_retention_days" {
  type        = number
  default     = 400
  description = "Days to retain CUR data in S3 before expiration"
  validation {
    condition     = var.cur_data_retention_days >= 90
    error_message = "cur_data_retention_days must be at least 90 days"
  }
}

variable "default_tags" {
  type        = map(string)
  default     = {}
  description = "Default tags to apply to all resources"
}