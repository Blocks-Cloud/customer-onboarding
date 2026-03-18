############################
# EventBridge Notifications
############################

locals {
  # Base triggers that always exist
  base_notification_triggers = [
    aws_iam_role.blocks_execution_role.arn,
    aws_iam_role.blocks_read_role.arn,
  ]

}

resource "terraform_data" "notify_blocks_deployment" {
  # Store values in input for use in destroy provisioner
  input = {
    blocks_account_id         = var.blocks_account_id
    notifier_role_arn         = aws_iam_role.blocks_optimization_notifier_role.arn
    region                    = local.region
    account_id                = local.account_id
    template_version          = var.template_version
    customer_resource_id      = var.customer_resource_id
    external_id               = var.external_id
    execution_role_arn        = aws_iam_role.blocks_execution_role.arn
    read_role_arn             = aws_iam_role.blocks_read_role.arn
    majortom_read_role_arn    = aws_iam_role.majortom_read_role.arn
    blocks_optimization_ou_id = try(aws_organizations_organizational_unit.blocks_optimization[0].id, "")
  }

  triggers_replace = local.base_notification_triggers

  # Notify on create/update
  provisioner "local-exec" {
    interpreter = ["/bin/bash", "-c"]
    command     = <<-EOF
      set -e

      # Wait for IAM policy propagation
      echo "Waiting for IAM policy propagation..."
      sleep 10

      EVENT_TIME=$(date -u +"%Y-%m-%dT%H:%M:%SZ")

      # Assume the NotifierRole to get SQS permissions
      echo "Assuming NotifierRole for SQS access..."
      CREDS=$(aws sts assume-role \
        --role-arn "${aws_iam_role.blocks_optimization_notifier_role.arn}" \
        --role-session-name "TerraformNotify" \
        --query 'Credentials.[AccessKeyId,SecretAccessKey,SessionToken]' \
        --output text)

      export AWS_ACCESS_KEY_ID=$(echo $CREDS | cut -d' ' -f1)
      export AWS_SECRET_ACCESS_KEY=$(echo $CREDS | cut -d' ' -f2)
      export AWS_SESSION_TOKEN=$(echo $CREDS | cut -d' ' -f3)

      # Send notification to Blocks SQS
      echo "Sending CREATE_COMPLETE notification to Blocks..."
      aws sqs send-message \
        --queue-url "https://sqs.us-east-1.amazonaws.com/${var.blocks_account_id}/Blocks-Onboarding-Queue" \
        --message-body '{
          "source": "terraform.blocks_cost_optimization",
          "time": "'"$EVENT_TIME"'",
          "account": "${local.account_id}",
          "templateVersion": "${var.template_version}",
          "customerResourceId": "${var.customer_resource_id}",
          "externalId": "${var.external_id}",
          "executionRoleArn": "${aws_iam_role.blocks_execution_role.arn}",
          "readRoleArn": "${aws_iam_role.blocks_read_role.arn}",
          "majorTomReadRoleArn": "${aws_iam_role.majortom_read_role.arn}",
          "blocksOptimizationOUId": "${self.input.blocks_optimization_ou_id}",
          "step": "2",
          "status": "CREATE_COMPLETE"
        }' \
        --region us-east-1

      echo "Notification sent successfully"
    EOF
  }

  # Notify on destroy (uses input values because other resources may already be destroyed)
  provisioner "local-exec" {
    when        = destroy
    interpreter = ["/bin/bash", "-c"]
    command     = <<-EOF
      set -e
      EVENT_TIME=$(date -u +"%Y-%m-%dT%H:%M:%SZ")

      # Assume the NotifierRole to get SQS permissions
      echo "Assuming NotifierRole for SQS access..."
      CREDS=$(aws sts assume-role \
        --role-arn "${self.input.notifier_role_arn}" \
        --role-session-name "TerraformNotify" \
        --query 'Credentials.[AccessKeyId,SecretAccessKey,SessionToken]' \
        --output text) || { echo "Could not assume role, skipping notification"; exit 0; }

      export AWS_ACCESS_KEY_ID=$(echo $CREDS | cut -d' ' -f1)
      export AWS_SECRET_ACCESS_KEY=$(echo $CREDS | cut -d' ' -f2)
      export AWS_SESSION_TOKEN=$(echo $CREDS | cut -d' ' -f3)

      # Send notification to Blocks SQS
      echo "Sending DELETE_COMPLETE notification to Blocks..."
      aws sqs send-message \
        --queue-url "https://sqs.us-east-1.amazonaws.com/${self.input.blocks_account_id}/Blocks-Onboarding-Queue" \
        --message-body '{
          "source": "terraform.blocks_cost_optimization",
          "time": "'"$EVENT_TIME"'",
          "account": "${self.input.account_id}",
          "templateVersion": "${self.input.template_version}",
          "customerResourceId": "${self.input.customer_resource_id}",
          "externalId": "${self.input.external_id}",
          "executionRoleArn": "${self.input.execution_role_arn}",
          "readRoleArn": "${self.input.read_role_arn}",
          "majorTomReadRoleArn": "${self.input.majortom_read_role_arn}",
          "blocksOptimizationOUId": "${self.input.blocks_optimization_ou_id}",
          "step": "2",
          "status": "DELETE_COMPLETE"
        }' \
        --region us-east-1 || true

      echo "Notification sent successfully"
    EOF
  }

  depends_on = [
    aws_iam_role.blocks_execution_role,
    aws_iam_role.blocks_read_role,
    aws_iam_role.majortom_read_role,
    aws_iam_role.blocks_optimization_notifier_role,
    aws_iam_role_policy.blocks_notifier_permissions,
    # Conditional resources removed - dependencies inferred from self.input references
  ]
}

############################
# EventBridge CloudTrail Forwarding Rule
############################
# Forwards CloudTrail management write events to the Blocks customer-events bus
# Deployed in us-east-1 only (management account) — captures organization-level events
# Member accounts get multi-region coverage via the EventForwarding StackSet

resource "aws_cloudwatch_event_rule" "blocks_cloudtrail_forwarding" {
  name        = "blocks-cloudtrail-forwarding-${var.customer_resource_id}"
  description = "Forwards CloudTrail management write events to Blocks for change detection. Used by Blocks.cloud - must remain in place for Blocks to function correctly."

  event_pattern = jsonencode({
    source = [
      "aws.ec2",
      "aws.rds",
      "aws.s3",
      "aws.lambda",
      "aws.ecs",
      "aws.eks",
      "aws.elasticloadbalancing",
      "aws.autoscaling",
      "aws.dynamodb",
      "aws.elasticache",
      "aws.redshift",
      "aws.es",
      "aws.opensearch",
      "aws.kinesis",
      "aws.firehose",
      "aws.sqs",
      "aws.sns",
      "aws.cloudfront",
      "aws.route53",
      "aws.apigateway",
      "aws.iam",
      "aws.kms",
      "aws.secretsmanager",
      "aws.acm",
      "aws.cloudformation",
      "aws.cloudwatch",
      "aws.logs",
      "aws.events",
      "aws.ssm",
      "aws.config",
      "aws.organizations",
      "aws.ce",
      "aws.savingsplans",
      "aws.sagemaker",
      "aws.emr",
      "aws.glue",
      "aws.athena",
      "aws.msk",
      "aws.mediaconvert",
      "aws.mediaconnect",
      "aws.memorydb",
      "aws.fsx",
      "aws.efs",
      "aws.backup",
      "aws.transfer",
      "aws.dms",
      "aws.neptune",
      "aws.docdb",
      "aws.workspaces",
      "aws.lightsail",
      "aws.budgets"
    ]
    detail-type = ["AWS API Call via CloudTrail"]
    detail = {
      managementEvent = [true]
      readOnly        = [false]
      errorCode       = [{ exists = false }]
    }
  })

  tags = merge(local.common_tags, {
    Purpose = "EventForwarding"
  })
}

resource "aws_cloudwatch_event_target" "blocks_cloudtrail_forwarding" {
  rule      = aws_cloudwatch_event_rule.blocks_cloudtrail_forwarding.name
  target_id = "BlocksCustomerEventBus"
  arn       = local.blocks_event_bus_arn
  role_arn  = aws_iam_role.blocks_event_bridge_cross_account_role.arn

  # Note: InputTransformer is not supported when the target is an EventBridge event bus.
  # The event pattern filter already limits forwarded events to management write calls
  # with no errors, so only matching CloudTrail metadata crosses the account boundary.
}

############################
# EventBridge Alarm State Change Forwarding Rule
############################

resource "aws_cloudwatch_event_rule" "blocks_alarm_state_forwarding" {
  name        = "blocks-alarm-forwarding-${var.customer_resource_id}"
  description = "Forwards Blocks CloudWatch alarm state changes to Blocks for incident detection. Used by Blocks.cloud - must remain in place for Blocks to function correctly."

  event_pattern = jsonencode({
    source      = ["aws.cloudwatch"]
    detail-type = ["CloudWatch Alarm State Change"]
    detail = {
      alarmName = [{ prefix = "Blocks-" }]
      state = {
        value = ["ALARM", "INSUFFICIENT_DATA"]
      }
    }
  })

  tags = merge(local.common_tags, {
    Purpose = "EventForwarding"
  })
}

resource "aws_cloudwatch_event_target" "blocks_alarm_state_forwarding" {
  rule      = aws_cloudwatch_event_rule.blocks_alarm_state_forwarding.name
  target_id = "BlocksCustomerEventBusAlarms"
  arn       = local.blocks_event_bus_arn
  role_arn  = aws_iam_role.blocks_event_bridge_cross_account_role.arn
}
