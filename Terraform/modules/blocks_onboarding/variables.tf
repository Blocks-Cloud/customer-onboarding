variable "aws_region" {
  type    = string
  default = "us-east-1"

  validation {
    condition     = var.aws_region == "us-east-1"
    error_message = "You must deploy to region us-east-1 only. Since Data exports is only available in us-east-1"
  }
}

variable "blocks_external_account_id" {
  type        = string
  description = "Blocks AWS account ID that will assume the Read Only role"
  default     = "810801871908"
}

variable "external_id" {
  type        = string
  description = "External ID for cross-account role assumption (keep secret)"
  default     = "blocks-shared-secret"
  sensitive   = true
}

variable "cur_data_retention_days" {
  type        = number
  default     = 365
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

variable "blocks_sqs_arn" {
  type        = string
  description = "ARN of Blocks SQS queue"
  default     = "arn:aws:sqs:us-east-1:810801871908:Blocks-Onboarding-Queue"
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

variable "template_version" {
  description = "The version of the template to use."
  type        = string
  default     = "1.0.0"
}

variable "failure_tolerance_count" {
  description = "The number of accounts per region for which this operation can fail before AWS CloudFormation stops the operation in that region."
  type        = number
  default     = 0
}

variable "max_concurrent_count" {
  description = "The maximum number of accounts in which to perform this operation at one time."
  type        = number
  default     = 100
}

variable "region_concurrency_type" {
  description = "The concurrency type of deploying StackSets operations in regions, could be SEQUENTIAL or PARALLEL."
  type        = string
  default     = "PARALLEL"
}
