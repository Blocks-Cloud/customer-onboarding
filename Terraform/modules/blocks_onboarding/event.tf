########################################
# EventBridge Rule - Notify Blocks     #
########################################

resource "null_resource" "notify_blocks" {
  depends_on = [
    aws_cloudwatch_event_target.forward_to_sqs,
    aws_s3_bucket.cur_bucket,
    aws_bcmdataexports_export.cur2,
    aws_iam_role.blocks_read_role,
    aws_cloudformation_stack_set.blocks,
    aws_cloudformation_stack_instances.blocks
  ]

  provisioner "local-exec" {
    command = <<EOF
EVENT_TIME=$(date -u +"%Y-%m-%dT%H:%M:%SZ")

aws events put-events \
--region ${var.aws_region} \
--entries "[{
\"Source\": \"customer.terraform\",
\"DetailType\": \"Terraform Apply Finished\",
\"Detail\": \"{\\\"status-details\\\":{\\\"status\\\":\\\"CREATE_COMPLETE\\\"}}\",
\"Time\": \"$EVENT_TIME\",
\"Resources\": []
}]"
EOF
  }

  provisioner "local-exec" {
    when    = destroy
    command = <<EOF
EVENT_TIME=$(date -u +"%Y-%m-%dT%H:%M:%SZ")

aws events put-events \
--region us-east-1 \
--entries "[{
\"Source\": \"customer.terraform\",
\"DetailType\": \"Terraform Destroy Finished\",
\"Detail\": \"{\\\"status-details\\\":{\\\"status\\\":\\\"DELETE_COMPLETE\\\"}}\",
\"Time\": \"$EVENT_TIME\",
\"Resources\": []
}]"
EOF
  }
}

resource "aws_cloudwatch_event_rule" "terraform_finished_rule" {
  name        = "NotifyBlocksTerraformComplete"
  description = "Forward Terraform finished events to Blocks SQS"
  event_pattern = jsonencode({
    source        = ["customer.terraform"]
    "detail-type" = ["Terraform Apply Finished", "Terraform Destroy Finished"]
  })
}

resource "aws_iam_role" "blocks_notifier_role" {
  name = "BlocksNotifierRole"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Principal = {
          Service = "events.amazonaws.com"
        }
        Action = "sts:AssumeRole"
      }
    ]
  })
}

resource "aws_iam_role_policy" "blocks_notifier_policy" {
  name = "SendToBlocksSQS"
  role = aws_iam_role.blocks_notifier_role.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "sqs:SendMessage"
        ]
        Resource = var.blocks_sqs_arn
      }
    ]
  })
}

resource "aws_cloudwatch_event_target" "forward_to_sqs" {
  rule     = aws_cloudwatch_event_rule.terraform_finished_rule.name
  arn      = var.blocks_sqs_arn
  role_arn = aws_iam_role.blocks_notifier_role.arn
}
