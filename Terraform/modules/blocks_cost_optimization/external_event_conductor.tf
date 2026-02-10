############################
# External Event Conductor #
############################
# Dedicated EventBridge event bus to communicate with Blocks external workers.
# Enables cross-account event-driven communication for:
# - Terraform state file ETL processing
# - Loopback communication workflows

resource "aws_cloudwatch_event_bus" "external_event_conductor" {
  name = "BlocksExternalEventsOutbound-${var.customer_id}"

  tags = merge(local.common_tags, {
    Purpose = "CrossAccountCommunication"
  })
}

resource "aws_cloudwatch_event_bus_policy" "external_event_conductor" {
  event_bus_name = aws_cloudwatch_event_bus.external_event_conductor.name

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "AllowExternalEventConductor"
        Effect = "Allow"
        Principal = {
          AWS = "arn:${local.partition}:iam::${var.blocks_account_id}:root"
        }
        Action   = "events:PutEvents"
        Resource = aws_cloudwatch_event_bus.external_event_conductor.arn
      }
    ]
  })
}

###################################
# Terraform State File ETL Worker #
###################################
# Lambda function that processes Terraform state files from customer S3 buckets
# and uploads extracted data to Blocks for infrastructure analysis.

data "aws_iam_policy_document" "tf_state_etl_worker" {
  # List all S3 buckets and objects in current account
  # (required to find Terraform state file buckets and list workspace folders)
  statement {
    sid    = "S3List"
    effect = "Allow"
    actions = [
      "s3:GetBucketLocation",
      "s3:ListAllMyBuckets",
      "s3:ListBucket"
    ]
    resources = ["*"]
  }

  # Read .tfstate files in any S3 buckets in current account
  statement {
    sid    = "S3Get"
    effect = "Allow"
    actions = [
      "s3:GetObject",
      "s3:GetObjectVersion"
    ]
    resources = ["arn:${local.partition}:s3:::*.tfstate"]
  }

  # Write access to target bucket path for this account
  statement {
    sid    = "S3WriteTfStateFileEtlWorkerTargetBucket"
    effect = "Allow"
    actions = [
      "s3:GetBucketLocation",
      "s3:GetObject",
      "s3:ListBucket",
      "s3:PutObject"
    ]
    resources = [
      "arn:${local.partition}:s3:::blocks-tf-state-file-etl-target-${var.blocks_account_id}",
      "arn:${local.partition}:s3:::blocks-tf-state-file-etl-target-${var.blocks_account_id}/customer-accounts/${local.account_id}/*"
    ]
  }

  # Access to SSM parameter to read its config
  statement {
    sid    = "SSMReadConfig"
    effect = "Allow"
    actions = [
      "ssm:GetParameter"
    ]
    resources = [
      "arn:${local.partition}:ssm:*:${local.account_id}:parameter/Blocks-${var.customer_id}/TfStateFileEtlWorker/Config"
    ]
  }

  # SSM write access for self-provisioning config parameter
  statement {
    sid    = "SSMWriteConfig"
    effect = "Allow"
    actions = [
      "ssm:PutParameter",
      "ssm:PutResourcePolicy"
    ]
    resources = [
      "arn:${local.partition}:ssm:*:${local.account_id}:parameter/Blocks-${var.customer_id}/TfStateFileEtlWorker/Config"
    ]
  }

  # STS for getting current account ID
  statement {
    sid    = "STSGetCallerIdentity"
    effect = "Allow"
    actions = [
      "sts:GetCallerIdentity"
    ]
    resources = ["*"]
  }

  # Publish notifications to Blocks SNS topic
  statement {
    sid    = "SNSPublishNotifications"
    effect = "Allow"
    actions = [
      "sns:Publish"
    ]
    resources = [
      "arn:${local.partition}:sns:eu-central-1:${var.blocks_account_id}:gh-app-inbound-${var.customer_id}"
    ]
  }

  # CloudWatch Logs
  statement {
    sid    = "CloudWatchLogs"
    effect = "Allow"
    actions = [
      "logs:CreateLogGroup",
      "logs:CreateLogStream",
      "logs:PutLogEvents"
    ]
    resources = [
      "arn:${local.partition}:logs:${local.region}:${local.account_id}:log-group:/aws/lambda/BlocksTfStateFileEtlWorker-${var.customer_id}:*"
    ]
  }
}

resource "aws_iam_policy" "tf_state_etl_worker" {
  name        = "BlocksTfStateFileEtlWorkerLambdaPolicy-${var.customer_id}"
  description = "Used by Blocks.cloud. Must remain in place for Blocks to function correctly. Email support@blocks.cloud for assistance. Grants access to S3, SSM, STS, and CloudWatch Logs."
  policy      = data.aws_iam_policy_document.tf_state_etl_worker.json
  tags        = local.common_tags
}

data "aws_iam_policy_document" "tf_state_etl_worker_assume" {
  statement {
    effect = "Allow"
    principals {
      type        = "Service"
      identifiers = ["lambda.amazonaws.com"]
    }
    actions = ["sts:AssumeRole"]
  }
}

resource "aws_iam_role" "tf_state_etl_worker" {
  name               = "BlocksTfEtlWorkerRole-${var.customer_id}"
  description        = "Used by Blocks.cloud. Must remain in place for Blocks to function correctly. Email support@blocks.cloud for assistance. Grants access to S3, SSM, STS, and CloudWatch Logs."
  assume_role_policy = data.aws_iam_policy_document.tf_state_etl_worker_assume.json
  tags               = local.common_tags
}

resource "aws_iam_role_policy_attachment" "tf_state_etl_worker" {
  role       = aws_iam_role.tf_state_etl_worker.name
  policy_arn = aws_iam_policy.tf_state_etl_worker.arn
}

resource "aws_lambda_function" "tf_state_etl_worker" {
  function_name = "BlocksTfStateFileEtlWorker-${var.customer_id}"
  description   = "Used by Blocks.cloud. Must remain in place for Blocks to function correctly. Email support@blocks.cloud for assistance. Accesses S3 and SSM for Terraform state file processing."
  role          = aws_iam_role.tf_state_etl_worker.arn

  runtime     = "python3.12"
  handler     = "tf_state_file_etl_worker.handler"
  timeout     = 900
  memory_size = 256

  s3_bucket = "blocks-cloud-public-artifacts-${local.region}"
  s3_key    = "lambda/tf-state-file-etl-worker/tf_state_file_etl_worker.zip"

  environment {
    variables = {
      BLOCKS_CUSTOMER_ID = var.customer_id
      SNS_ACCOUNT        = var.blocks_account_id
    }
  }

  tags = local.common_tags

  depends_on = [aws_iam_role_policy_attachment.tf_state_etl_worker]
}

# Allow Blocks account to directly invoke the Lambda function
resource "aws_lambda_permission" "tf_state_etl_worker_external_conductor" {
  statement_id  = "AllowBlocksAccountInvoke"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.tf_state_etl_worker.function_name
  principal     = "arn:aws:iam::${var.blocks_account_id}:root"
}

# Allow EventBridge to invoke the Lambda function
resource "aws_lambda_permission" "tf_state_etl_worker_eventbridge" {
  statement_id  = "AllowEventBridgeInvoke"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.tf_state_etl_worker.function_name
  principal     = "events.amazonaws.com"
  source_arn    = aws_cloudwatch_event_rule.tf_state_etl_worker.arn
}

resource "aws_cloudwatch_event_rule" "tf_state_etl_worker" {
  name           = "BlocksTfStateFileEtlRequested"
  description    = "Used by Blocks.cloud. Must remain in place for Blocks to function correctly. Email support@blocks.cloud for assistance. Triggers Lambda on EventBridge events."
  event_bus_name = aws_cloudwatch_event_bus.external_event_conductor.name

  event_pattern = jsonencode({
    source      = ["state_bucket_finder"]
    detail-type = ["state_bucket_finder.succeeded"]
  })

  tags = local.common_tags
}

resource "aws_cloudwatch_event_target" "tf_state_etl_worker" {
  rule           = aws_cloudwatch_event_rule.tf_state_etl_worker.name
  event_bus_name = aws_cloudwatch_event_bus.external_event_conductor.name
  target_id      = "TfStateFileEtlWorkerLambda"
  arn            = aws_lambda_function.tf_state_etl_worker.arn
}

# SSM Parameter for additional Lambda configuration
resource "aws_ssm_parameter" "tf_state_etl_worker_config" {
  name        = "/Blocks-${var.customer_id}/TfStateFileEtlWorker/Config"
  type        = "String"
  description = "Used by Blocks.cloud. Must remain in place for Blocks to function correctly. Email support@blocks.cloud for assistance. Stores Lambda configuration."

  value = jsonencode({
    log_level               = "error"
    allow_eb_events         = true
    allow_direct_invocation = true
  })

  tags = local.common_tags
}

##########################
# Loopback Communication #
##########################
# Two Lambda functions that handle loopback event communication:
# - Prep Worker: Sets up EventBridge rules dynamically
# - Worker: Processes the actual loopback events

############################
# Loopback Prep Worker
############################

data "aws_iam_policy_document" "loopback_prep_worker" {
  # EventBridge permissions to create/manage rules on the external event bus
  statement {
    sid    = "EventBridgeRuleManagement"
    effect = "Allow"
    actions = [
      "events:PutRule",
      "events:PutTargets",
      "events:DeleteRule",
      "events:RemoveTargets",
      "events:DescribeRule",
      "events:ListTargetsByRule"
    ]
    resources = [
      "arn:${local.partition}:events:${local.region}:${local.account_id}:rule/BlocksExternalEventsOutbound-*"
    ]
  }

  # Lambda permissions to add invoke permissions for the worker
  statement {
    sid    = "LambdaPermissionManagement"
    effect = "Allow"
    actions = [
      "lambda:AddPermission",
      "lambda:RemovePermission"
    ]
    resources = [
      aws_lambda_function.loopback_worker.arn
    ]
  }

  # CloudWatch Logs
  statement {
    sid    = "CloudWatchLogs"
    effect = "Allow"
    actions = [
      "logs:CreateLogGroup",
      "logs:CreateLogStream",
      "logs:PutLogEvents"
    ]
    resources = [
      "arn:${local.partition}:logs:${local.region}:${local.account_id}:log-group:/aws/lambda/BlocksLoopbackCommunicationPrepWorker-${var.customer_id}:*"
    ]
  }
}

resource "aws_iam_policy" "loopback_prep_worker" {
  name        = "BlocksLoopbackCommunicationPrepWorkerLambdaPolicy-${var.customer_id}"
  description = "Used by Blocks.cloud. Must remain in place for Blocks to function correctly. Email support@blocks.cloud for assistance. Grants access to EventBridge, Lambda, and CloudWatch Logs."
  policy      = data.aws_iam_policy_document.loopback_prep_worker.json
  tags        = local.common_tags
}

data "aws_iam_policy_document" "loopback_prep_worker_assume" {
  statement {
    effect = "Allow"
    principals {
      type        = "Service"
      identifiers = ["lambda.amazonaws.com"]
    }
    actions = ["sts:AssumeRole"]
  }
}

resource "aws_iam_role" "loopback_prep_worker" {
  name               = "BlocksLoopbackPrepRole-${var.customer_id}"
  description        = "Used by Blocks.cloud. Must remain in place for Blocks to function correctly. Email support@blocks.cloud for assistance. Grants access to EventBridge, Lambda, and CloudWatch Logs."
  assume_role_policy = data.aws_iam_policy_document.loopback_prep_worker_assume.json
  tags               = local.common_tags
}

resource "aws_iam_role_policy_attachment" "loopback_prep_worker" {
  role       = aws_iam_role.loopback_prep_worker.name
  policy_arn = aws_iam_policy.loopback_prep_worker.arn
}

resource "aws_lambda_function" "loopback_prep_worker" {
  function_name = "BlocksLoopbackCommunicationPrepWorker-${var.customer_id}"
  description   = "Used by Blocks.cloud. Must remain in place for Blocks to function correctly. Email support@blocks.cloud for assistance. Accesses EventBridge and Lambda for loopback setup."
  role          = aws_iam_role.loopback_prep_worker.arn

  runtime     = "python3.12"
  handler     = "loopback_communication_prep_worker.handler"
  timeout     = 900
  memory_size = 256

  s3_bucket = "blocks-cloud-public-artifacts-${local.region}"
  s3_key    = "lambda/loopback-communication-prep-worker/loopback_communication_prep_worker.zip"

  environment {
    variables = {
      BLOCKS_CUSTOMER_ID = var.customer_id
    }
  }

  tags = local.common_tags

  depends_on = [aws_iam_role_policy_attachment.loopback_prep_worker]
}

# Allow Blocks account to directly invoke the Lambda function
resource "aws_lambda_permission" "loopback_prep_worker_external_conductor" {
  statement_id  = "AllowBlocksAccountInvoke"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.loopback_prep_worker.function_name
  principal     = "arn:aws:iam::${var.blocks_account_id}:root"
}

# Allow EventBridge to invoke the Lambda function
resource "aws_lambda_permission" "loopback_prep_worker_eventbridge" {
  statement_id  = "AllowEventBridgeInvoke"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.loopback_prep_worker.function_name
  principal     = "events.amazonaws.com"
  source_arn    = aws_cloudwatch_event_rule.loopback_prep_worker.arn
}

resource "aws_cloudwatch_event_rule" "loopback_prep_worker" {
  name           = "BlocksLoopbackCommunicationPrepRequested"
  description    = "Used by Blocks.cloud. Must remain in place for Blocks to function correctly. Email support@blocks.cloud for assistance. Triggers Lambda on EventBridge events."
  event_bus_name = aws_cloudwatch_event_bus.external_event_conductor.name

  event_pattern = jsonencode({
    source      = ["external_event_conductor.blocks.cloud"]
    detail-type = ["loopback_communication_prep.requested"]
  })

  tags = local.common_tags
}

resource "aws_cloudwatch_event_target" "loopback_prep_worker" {
  rule           = aws_cloudwatch_event_rule.loopback_prep_worker.name
  event_bus_name = aws_cloudwatch_event_bus.external_event_conductor.name
  target_id      = "LoopbackCommunicationPrepWorkerLambda"
  arn            = aws_lambda_function.loopback_prep_worker.arn
}

############################
# Loopback Worker
############################

data "aws_iam_policy_document" "loopback_worker" {
  # CloudWatch Logs only - minimal permissions
  statement {
    sid    = "CloudWatchLogs"
    effect = "Allow"
    actions = [
      "logs:CreateLogGroup",
      "logs:CreateLogStream",
      "logs:PutLogEvents"
    ]
    resources = [
      "arn:${local.partition}:logs:${local.region}:${local.account_id}:log-group:/aws/lambda/BlocksLoopbackCommunicationWorker-${var.customer_id}:*"
    ]
  }
}

resource "aws_iam_policy" "loopback_worker" {
  name        = "BlocksLoopbackCommunicationWorkerLambdaPolicy-${var.customer_id}"
  description = "Used by Blocks.cloud. Must remain in place for Blocks to function correctly. Email support@blocks.cloud for assistance. Grants access to CloudWatch Logs."
  policy      = data.aws_iam_policy_document.loopback_worker.json
  tags        = local.common_tags
}

data "aws_iam_policy_document" "loopback_worker_assume" {
  statement {
    effect = "Allow"
    principals {
      type        = "Service"
      identifiers = ["lambda.amazonaws.com"]
    }
    actions = ["sts:AssumeRole"]
  }
}

resource "aws_iam_role" "loopback_worker" {
  name               = "BlocksLoopbackWorkerRole-${var.customer_id}"
  description        = "Used by Blocks.cloud. Must remain in place for Blocks to function correctly. Email support@blocks.cloud for assistance. Grants access to CloudWatch Logs."
  assume_role_policy = data.aws_iam_policy_document.loopback_worker_assume.json
  tags               = local.common_tags
}

resource "aws_iam_role_policy_attachment" "loopback_worker" {
  role       = aws_iam_role.loopback_worker.name
  policy_arn = aws_iam_policy.loopback_worker.arn
}

resource "aws_lambda_function" "loopback_worker" {
  function_name = "BlocksLoopbackCommunicationWorker-${var.customer_id}"
  description   = "Used by Blocks.cloud. Must remain in place for Blocks to function correctly. Email support@blocks.cloud for assistance. Processes loopback communication events."
  role          = aws_iam_role.loopback_worker.arn

  runtime     = "python3.12"
  handler     = "loopback_communication_worker.handler"
  timeout     = 900
  memory_size = 256

  s3_bucket = "blocks-cloud-public-artifacts-${local.region}"
  s3_key    = "lambda/loopback-communication-worker/loopback_communication_worker.zip"

  environment {
    variables = {
      BLOCKS_CUSTOMER_ID = var.customer_id
    }
  }

  tags = local.common_tags

  depends_on = [aws_iam_role_policy_attachment.loopback_worker]
}
