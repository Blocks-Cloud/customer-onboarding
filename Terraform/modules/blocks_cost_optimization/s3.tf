############################
# S3 Bucket for CUR 2.0 Data
############################

resource "aws_s3_bucket" "cur_bucket" {
  count = var.enable_cost_allocation_backfill ? 1 : 0

  bucket        = local.cur_bucket_name
  force_destroy = false

  tags = merge(local.common_tags, {
    Purpose = "CostAndUsageReport"
  })
}

resource "aws_s3_bucket_versioning" "cur_bucket" {
  count = var.enable_cost_allocation_backfill ? 1 : 0

  bucket = aws_s3_bucket.cur_bucket[0].id

  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_s3_bucket_ownership_controls" "cur_bucket" {
  count = var.enable_cost_allocation_backfill ? 1 : 0

  bucket = aws_s3_bucket.cur_bucket[0].id

  rule {
    object_ownership = "BucketOwnerEnforced"
  }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "cur_bucket" {
  count = var.enable_cost_allocation_backfill ? 1 : 0

  bucket = aws_s3_bucket.cur_bucket[0].id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
    bucket_key_enabled = true
  }
}

resource "aws_s3_bucket_public_access_block" "cur_bucket" {
  count = var.enable_cost_allocation_backfill ? 1 : 0

  bucket                  = aws_s3_bucket.cur_bucket[0].id
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_s3_bucket_lifecycle_configuration" "cur_bucket" {
  count = var.enable_cost_allocation_backfill ? 1 : 0

  bucket = aws_s3_bucket.cur_bucket[0].id

  rule {
    id     = "expire-old-cur-data"
    status = "Enabled"

    expiration {
      days = var.cur_data_retention_days
    }

    noncurrent_version_expiration {
      noncurrent_days = 30
    }

    abort_incomplete_multipart_upload {
      days_after_initiation = 30
    }
  }
}

############################
# S3 Bucket Policy
############################

data "aws_iam_policy_document" "cur_bucket_policy" {
  count = var.enable_cost_allocation_backfill ? 1 : 0

  # BCM Data Exports - PutObject
  statement {
    sid    = "AllowBCMDataExportsPut"
    effect = "Allow"
    principals {
      type        = "Service"
      identifiers = ["bcm-data-exports.amazonaws.com"]
    }
    actions   = ["s3:PutObject"]
    resources = ["${aws_s3_bucket.cur_bucket[0].arn}/*"]
    condition {
      test     = "StringEquals"
      variable = "aws:SourceAccount"
      values   = [local.account_id]
    }
    condition {
      test     = "StringLike"
      variable = "aws:SourceArn"
      values   = ["arn:${local.partition}:bcm-data-exports:${local.region}:${local.account_id}:export/*"]
    }
  }

  # BCM Data Exports - Bucket metadata
  statement {
    sid    = "AllowBCMDataExportsBucketMeta"
    effect = "Allow"
    principals {
      type        = "Service"
      identifiers = ["bcm-data-exports.amazonaws.com"]
    }
    actions = [
      "s3:GetBucketAcl",
      "s3:GetBucketPolicy",
      "s3:GetBucketLocation",
      "s3:ListBucket"
    ]
    resources = [aws_s3_bucket.cur_bucket[0].arn]
    condition {
      test     = "StringEquals"
      variable = "aws:SourceAccount"
      values   = [local.account_id]
    }
    condition {
      test     = "StringLike"
      variable = "aws:SourceArn"
      values   = ["arn:${local.partition}:bcm-data-exports:${local.region}:${local.account_id}:export/*"]
    }
  }

  # No role-based statements - roles use IAM policies (ReadOnlyAccess + BlocksDataProtectionPolicy)
}

resource "aws_s3_bucket_policy" "cur_bucket" {
  count = var.enable_cost_allocation_backfill ? 1 : 0

  bucket = aws_s3_bucket.cur_bucket[0].id
  policy = data.aws_iam_policy_document.cur_bucket_policy[0].json

  depends_on = [
    aws_s3_bucket.cur_bucket
  ]
}
