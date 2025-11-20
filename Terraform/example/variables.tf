variable "enable_automatic_backfill" {
  description = "Set to true if business support is enabled in your AWS account, This will create a support Case Request to backfill the data for the last 36 months"
  type        = bool
}

variable "aws_region" {
  type        = string
  default     = "us-east-1"

  validation {
    condition     = var.aws_region == "us-east-1"
    error_message = "You must deploy to region us-east-1 only. Since Data exports is only available in us-east-1"
  }
}
