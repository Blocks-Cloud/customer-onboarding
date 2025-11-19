############################
# S3 Bucket
############################

resource "aws_s3_bucket" "cur_bucket" {
  count         = var.use_existing_bucket ? 0 : 1
  bucket        = local.cur_bucket_name
  force_destroy = false
  tags          = local.common_tags
}

resource "aws_s3_bucket_versioning" "cur_bucket" {
  count  = var.use_existing_bucket ? 0 : 1
  bucket = aws_s3_bucket.cur_bucket[count.index].id

  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_s3_bucket_ownership_controls" "cur_bucket" {
  count  = var.use_existing_bucket ? 0 : 1
  bucket = aws_s3_bucket.cur_bucket[count.index].id

  rule {
    object_ownership = "BucketOwnerEnforced"
  }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "cur_bucket" {
  count  = var.use_existing_bucket ? 0 : 1
  bucket = aws_s3_bucket.cur_bucket[count.index].id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm     = var.kms_key_arn != "" ? "aws:kms" : "AES256"
      kms_master_key_id = var.kms_key_arn != "" ? var.kms_key_arn : null
    }
    bucket_key_enabled = var.kms_key_arn != "" ? true : false
  }
}

resource "aws_s3_bucket_public_access_block" "cur_bucket" {
  bucket                  = local.cur_bucket_name
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true

  depends_on = [aws_s3_bucket.cur_bucket]
}

resource "aws_s3_bucket_lifecycle_configuration" "cur_bucket" {
  count  = var.use_existing_bucket ? 0 : 1
  bucket = aws_s3_bucket.cur_bucket[count.index].id

  rule {
    id     = "expire-old-cur-data"
    status = var.enable_lifecycle_rules ? "Enabled" : "Disabled"

    filter {
      prefix = "cur2/"
    }

    expiration {
      days = var.cur_data_retention_days
    }

    noncurrent_version_expiration {
      noncurrent_days = 30
    }
  }
}

############################
# S3 Bucket Policy
############################

data "aws_iam_policy_document" "cur_bucket_policy" {
  statement {
    sid    = "AllowBCMDataExportsPut"
    effect = "Allow"
    principals {
      type        = "Service"
      identifiers = ["bcm-data-exports.amazonaws.com"]
    }
    actions   = ["s3:PutObject"]
    resources = ["arn:aws:s3:::${local.cur_bucket_name}/*"]
    condition {
      test     = "StringEquals"
      variable = "aws:SourceAccount"
      values   = [data.aws_caller_identity.current.account_id]
    }
    condition {
      test     = "StringLike"
      variable = "aws:SourceArn"
      values   = ["arn:aws:bcm-data-exports:${data.aws_region.current.name}:${data.aws_caller_identity.current.account_id}:export/*"]
    }
  }

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
    resources = ["arn:aws:s3:::${local.cur_bucket_name}"]
    condition {
      test     = "StringEquals"
      variable = "aws:SourceAccount"
      values   = [data.aws_caller_identity.current.account_id]
    }
    condition {
      test     = "StringLike"
      variable = "aws:SourceArn"
      values   = ["arn:aws:bcm-data-exports:${data.aws_region.current.name}:${data.aws_caller_identity.current.account_id}:export/*"]
    }
  }

  statement {
    sid    = "AllowReadRoleGetObject"
    effect = "Allow"
    principals {
      type        = "AWS"
      identifiers = [aws_iam_role.blocks_read_role.arn]
    }
    actions   = ["s3:GetObject"]
    resources = ["arn:aws:s3:::${local.cur_bucket_name}/cur2/*"]
  }
}

resource "aws_s3_bucket_policy" "cur_bucket_policy" {
  bucket = local.cur_bucket_name
  policy = data.aws_iam_policy_document.cur_bucket_policy.json

  depends_on = [aws_s3_bucket.cur_bucket]
}
