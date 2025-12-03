variable "aws_region" {
  type        = string
  default     = "us-east-1"

  validation {
    condition     = var.aws_region == "us-east-1"
    error_message = "You must deploy to region us-east-1 only. Since Data exports is only available in us-east-1"
  }
}
