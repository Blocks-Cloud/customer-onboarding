############################
# S3 Bucket
############################

resource "aws_s3_bucket" "cur_bucket" {
  bucket        = local.blocks_resource_name
  force_destroy = false
  tags          = local.common_tags
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
      sse_algorithm     = "AES256"
    }
    bucket_key_enabled = true
  }
}

resource "aws_s3_bucket_public_access_block" "cur_bucket" {
  bucket                  = local.blocks_resource_name
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true

  depends_on = [aws_s3_bucket.cur_bucket]
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
      days = 365
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
    resources = ["arn:aws:s3:::${local.blocks_resource_name}/*"]
    condition {
      test     = "StringEquals"
      variable = "aws:SourceAccount"
      values   = [data.aws_caller_identity.current.account_id]
    }
    condition {
      test     = "StringLike"
      variable = "aws:SourceArn"
      values   = ["arn:aws:bcm-data-exports:${data.aws_region.current.region}:${data.aws_caller_identity.current.account_id}:export/*"]
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
    resources = ["arn:aws:s3:::${local.blocks_resource_name}"]
    condition {
      test     = "StringEquals"
      variable = "aws:SourceAccount"
      values   = [data.aws_caller_identity.current.account_id]
    }
    condition {
      test     = "StringLike"
      variable = "aws:SourceArn"
      values   = ["arn:aws:bcm-data-exports:${data.aws_region.current.region}:${data.aws_caller_identity.current.account_id}:export/*"]
    }
  }

  statement {
    sid    = "AllowReadRoleListBucket"
    effect = "Allow"

    principals {
      type        = "AWS"
      identifiers = [aws_iam_role.blocks_read_role.arn]
    }
    actions = [
      "s3:ListBucket"
    ]
    resources = [
      "arn:aws:s3:::${local.blocks_resource_name}"
    ]
    condition {
      test     = "StringLike"
      variable = "s3:prefix"
      values   = ["cur2/*"]
    }
  }

  statement {
    sid    = "AllowReadRoleGetObject"
    effect = "Allow"

    principals {
      type        = "AWS"
      identifiers = [aws_iam_role.blocks_read_role.arn]
    }
    actions = [
      "s3:GetObject"
    ]
    resources = [
      "arn:aws:s3:::${local.blocks_resource_name}/cur2/*"
    ]
  }

}

resource "aws_s3_bucket_policy" "cur_bucket_policy" {
  bucket = local.blocks_resource_name
  policy = data.aws_iam_policy_document.cur_bucket_policy.json

  depends_on = [aws_s3_bucket.cur_bucket]
}
