############################
# Required Variables
############################

variable "customer_resource_id" {
  type        = string
  description = "Unique resource identifier assigned by Blocks to distinguish each client's deployed infrastructure (a UUID)"

  validation {
    # Max 36 chars: the id is embedded (hyphens -> underscores) in custom role
    # IDs and GCP caps role IDs at 64 chars. Blocks issues a UUID (36 chars).
    condition     = can(regex("^[a-zA-Z0-9-_]{1,36}$", var.customer_resource_id))
    error_message = "customer_resource_id must be 1-36 alphanumeric characters, hyphens, or underscores."
  }
}

variable "scanner_aws_account_id" {
  type        = string
  description = "AWS account ID of Blocks' shared cost scanner, whose role your Workload Identity provider will trust (provided by Blocks)"

  validation {
    condition     = can(regex("^[0-9]{12}$", var.scanner_aws_account_id))
    error_message = "scanner_aws_account_id must be a valid 12-digit AWS account ID."
  }
}

variable "scanner_pod_role_arn" {
  type        = string
  description = "STS assumed-role ARN prefix of Blocks' shared scanner identity, pinned in the provider attribute condition (arn:aws:sts::<acct>:assumed-role/<role>/). Same value for every customer; provided by Blocks."

  validation {
    condition     = can(regex("^arn:aws:sts::[0-9]{12}:assumed-role/.+/$", var.scanner_pod_role_arn))
    error_message = "scanner_pod_role_arn must be an STS assumed-role ARN prefix ending in '/', e.g. arn:aws:sts::123456789012:assumed-role/BlocksScanner/."
  }
}

variable "scanner_pod_role_name" {
  type        = string
  description = "Bare AWS role name of Blocks' shared scanner (the <role> in the assumed-role ARN). The SA impersonation grant is scoped to attribute.aws_role/<this>. Provided by Blocks."

  validation {
    condition     = can(regex("^[A-Za-z0-9+=,.@_-]+$", var.scanner_pod_role_name))
    error_message = "scanner_pod_role_name must be a valid IAM role name (no path, no ARN)."
  }
}

variable "wif_pool_id" {
  type        = string
  description = "Workload Identity Pool ID to create in your project (4-32 chars, [a-z0-9-]). Provided by Blocks."
  default     = "blocks-scanner-pool"

  validation {
    condition     = can(regex("^[a-z0-9-]{4,32}$", var.wif_pool_id))
    error_message = "wif_pool_id must be 4-32 characters of lowercase letters, digits, or hyphens."
  }
}

variable "wif_provider_id" {
  type        = string
  description = "Workload Identity Pool provider ID to create (4-32 chars, [a-z0-9-]). Provided by Blocks."
  default     = "aws-blocks"

  validation {
    condition     = can(regex("^[a-z0-9-]{4,32}$", var.wif_provider_id))
    error_message = "wif_provider_id must be 4-32 characters of lowercase letters, digits, or hyphens."
  }
}

variable "scanner_sa_name" {
  type        = string
  description = "Account ID (name) of the read-only Blocks scanner service account to create (6-30 chars, [a-z][a-z0-9-]). Provided by Blocks."
  default     = "blocks-scanner"

  validation {
    condition     = can(regex("^[a-z][a-z0-9-]{4,28}[a-z0-9]$", var.scanner_sa_name))
    error_message = "scanner_sa_name must be a valid GCP service account ID (6-30 chars, lowercase)."
  }
}

variable "project_id" {
  type        = string
  description = "GCP project hosting the Workload Identity pool and the Blocks service account (also the binding target for scope = project)"

  validation {
    condition     = can(regex("^[a-z][a-z0-9-]{4,28}[a-z0-9]$", var.project_id))
    error_message = "project_id must be a valid GCP project ID (6-30 chars, lowercase letters, digits, hyphens)."
  }
}

############################
# Scope Selection
############################

variable "scope" {
  type        = string
  description = "Where Blocks gets read access: 'project' (project_id only), 'folder' (all projects under folder_id), or 'org' (the whole organization). One folder/org grant is inherited by all child projects."
  default     = "project"

  validation {
    condition     = contains(["project", "folder", "org"], var.scope)
    error_message = "scope must be one of: project, folder, org."
  }
}

variable "folder_id" {
  type        = string
  description = "Folder ID (numeric) to grant read access on. Required when scope = folder."
  default     = ""

  validation {
    condition     = var.folder_id == "" || can(regex("^[0-9]+$", var.folder_id))
    error_message = "folder_id must be the numeric folder ID (no 'folders/' prefix)."
  }
}

variable "org_id" {
  type        = string
  description = "Organization ID (numeric). Required when scope = folder (custom roles cannot live at folder level, so they are created at the org) or scope = org."
  default     = ""

  validation {
    condition     = var.org_id == "" || can(regex("^[0-9]+$", var.org_id))
    error_message = "org_id must be the numeric organization ID (no 'organizations/' prefix)."
  }
}
