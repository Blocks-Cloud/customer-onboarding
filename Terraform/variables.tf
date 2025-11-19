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

variable "blocks_external_account_id" {
  type        = string
  description = "Blocks AWS account ID that will assume the Read Only role"
  default     = "503132503926"
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
  default     = 30
  description = "Days to retain CUR data in S3 before expiration"
  validation {
    condition     = var.cur_data_retention_days >= 7
    error_message = "cur_data_retention_days must be at least 7 days"
  }
}

variable "default_tags" {
  type        = map(string)
  default     = {}
  description = "Default tags to apply to all resources"
}

############################
# Stackset Variables
############################

variable "stack_set_name" {
  description = "Name of the CloudFormation StackSet."
  type        = string
  default     = "Blocks-SubAccounts"
}

variable "stack_set_description" {
  description = "StackSet that deploys IAM role to sub-accounts"
  type        = string
  default     = "StackSet that deploys IAM role to sub-accounts"
}

variable "permission_model" {
  description = "The permission model for the StackSet."
  type        = string
  default     = "SERVICE_MANAGED"
}

variable "call_as" {
  description = "Specifies whether you are acting as an administrator of the organization."
  type        = string
  default     = "SELF"
}

variable "capabilities" {
  description = "A list of capabilities. Valid values: CAPABILITY_IAM, CAPABILITY_NAMED_IAM, CAPABILITY_AUTO_EXPAND."
  type        = list(string)
  default     = ["CAPABILITY_NAMED_IAM"]
}

variable "auto_deployment_enabled" {
  description = "Whether or not auto-deployment is enabled."
  type        = bool
  default     = true
}

variable "retain_stacks_on_account_removal" {
  description = "Whether or not to retain stacks on account removal."
  type        = bool
  default     = false
}

variable "template_url" {
  description = "The URL of the template body."
  type        = string
  default     = "https://blocks-cf-templates.s3.eu-north-1.amazonaws.com/Blocks-CF-Subaccounts-Template.yaml"
}

variable "failure_tolerance_percentage" {
  description = "The percentage of accounts per region for which this operation can fail before AWS CloudFormation stops the operation in that region."
  type        = number
  default     = 100
}

variable "max_concurrent_percentage" {
  description = "The maximum percentage of accounts in which to perform this operation at one time."
  type        = number
  default     = 100
}

variable "region_concurrency_type" {
  description = "The concurrency type of deploying StackSets operations in regions, could be SEQUENTIAL or PARALLEL."
  type        = string
  default     = "PARALLEL"
}
