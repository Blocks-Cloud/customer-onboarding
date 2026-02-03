############################
# S3 Bucket for CUR 2.0 Data
############################

resource "aws_s3_bucket" "cur_bucket" {
  bucket        = local.cur_bucket_name
  force_destroy = false

  tags = merge(local.common_tags, {
    Purpose = "CostAndUsageReport"
  })
}

resource "aws_s3_bucket_versioning" "cur_bucket" {
  bucket = aws_s3_bucket.cur_bucket.id

  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_s3_bucket_ownership_controls" "cur_bucket" {
  bucket = aws_s3_bucket.cur_bucket.id

  rule {
    object_ownership = "BucketOwnerEnforced"
  }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "cur_bucket" {
  bucket = aws_s3_bucket.cur_bucket.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
    bucket_key_enabled = true
  }
}

resource "aws_s3_bucket_public_access_block" "cur_bucket" {
  bucket                  = aws_s3_bucket.cur_bucket.id
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_s3_bucket_lifecycle_configuration" "cur_bucket" {
  bucket = aws_s3_bucket.cur_bucket.id

  rule {
    id     = "expire-old-cur-data"
    status = "Enabled"

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
  # BCM Data Exports - PutObject
  statement {
    sid    = "AllowBCMDataExportsPut"
    effect = "Allow"
    principals {
      type        = "Service"
      identifiers = ["bcm-data-exports.amazonaws.com"]
    }
    actions   = ["s3:PutObject"]
    resources = ["${aws_s3_bucket.cur_bucket.arn}/*"]
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
    resources = [aws_s3_bucket.cur_bucket.arn]
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

  # BlocksExecutionRole - ListBucket
  statement {
    sid    = "AllowExecutionRoleListBucket"
    effect = "Allow"
    principals {
      type        = "AWS"
      identifiers = [aws_iam_role.blocks_execution_role.arn]
    }
    actions   = ["s3:ListBucket"]
    resources = [aws_s3_bucket.cur_bucket.arn]
    condition {
      test     = "StringLike"
      variable = "s3:prefix"
      values   = ["cur2/*"]
    }
  }

  # BlocksExecutionRole - GetObject
  statement {
    sid    = "AllowExecutionRoleGetObject"
    effect = "Allow"
    principals {
      type        = "AWS"
      identifiers = [aws_iam_role.blocks_execution_role.arn]
    }
    actions   = ["s3:GetObject"]
    resources = ["${aws_s3_bucket.cur_bucket.arn}/cur2/*"]
  }

  # BlocksReadRole - ListBucket
  statement {
    sid    = "AllowReadRoleListBucket"
    effect = "Allow"
    principals {
      type        = "AWS"
      identifiers = [aws_iam_role.blocks_read_role.arn]
    }
    actions   = ["s3:ListBucket"]
    resources = [aws_s3_bucket.cur_bucket.arn]
    condition {
      test     = "StringLike"
      variable = "s3:prefix"
      values   = ["cur2/*"]
    }
  }

  # BlocksReadRole - GetObject
  statement {
    sid    = "AllowReadRoleGetObject"
    effect = "Allow"
    principals {
      type        = "AWS"
      identifiers = [aws_iam_role.blocks_read_role.arn]
    }
    actions   = ["s3:GetObject"]
    resources = ["${aws_s3_bucket.cur_bucket.arn}/cur2/*"]
  }
}

resource "aws_s3_bucket_policy" "cur_bucket" {
  bucket = aws_s3_bucket.cur_bucket.id
  policy = data.aws_iam_policy_document.cur_bucket_policy.json

  depends_on = [
    aws_s3_bucket.cur_bucket,
    aws_iam_role.blocks_execution_role,
    aws_iam_role.blocks_read_role
  ]
}
