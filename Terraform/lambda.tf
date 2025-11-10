############################
# Backfill Lambda (Optional)
############################

data "aws_iam_policy_document" "lambda_assume" {
  statement {
    effect = "Allow"
    principals {
      type        = "Service"
      identifiers = ["lambda.amazonaws.com"]
    }
    actions = ["sts:AssumeRole"]
  }
}

resource "aws_iam_role" "backfill_role" {
  count              = var.enable_backfill_lambda ? 1 : 0
  name               = "${local.export_name}-backfill-role"
  assume_role_policy = data.aws_iam_policy_document.lambda_assume.json
  tags               = local.common_tags
}

resource "aws_iam_role_policy_attachment" "backfill_basic" {
  count      = var.enable_backfill_lambda ? 1 : 0
  role       = aws_iam_role.backfill_role[0].name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
}

data "aws_iam_policy_document" "backfill_support" {
  statement {
    effect = "Allow"
    actions = [
      "support:CreateCase",
      "support:DescribeServices",
      "support:DescribeSeverityLevels"
    ]
    resources = ["*"]
  }
}

resource "aws_iam_role_policy" "backfill_support" {
  count  = var.enable_backfill_lambda ? 1 : 0
  name   = "SupportCaseBackfill"
  role   = aws_iam_role.backfill_role[0].id
  policy = data.aws_iam_policy_document.backfill_support.json
}

data "archive_file" "backfill_zip" {
  count       = var.enable_backfill_lambda ? 1 : 0
  type        = "zip"
  output_path = "${path.module}/.terraform/backfill.zip"
  source_file = "${path.module}/backfill_lambda.py"
}

resource "aws_lambda_function" "backfill_fn" {
  count            = var.enable_backfill_lambda ? 1 : 0
  function_name    = "${local.export_name}-backfill"
  role             = aws_iam_role.backfill_role[0].arn
  handler          = "backfill_lambda.lambda_handler"
  runtime          = "python3.12"
  timeout          = 120
  filename         = data.archive_file.backfill_zip[0].output_path
  source_code_hash = data.archive_file.backfill_zip[0].output_base64sha256

  environment {
    variables = {
      EXPORT_NAME     = local.export_name
      BACKFILL_MONTHS = tostring(var.backfill_months)
      SEVERITY        = var.support_severity
    }
  }

  tags = local.common_tags
}

