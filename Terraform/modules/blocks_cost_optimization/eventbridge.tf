############################
# EventBridge Notifications
############################

resource "terraform_data" "notify_blocks_deployment" {
  # Store values in input for use in destroy provisioner
  input = {
    blocks_account_id      = var.blocks_account_id
    notifier_role_arn      = aws_iam_role.blocks_optimization_notifier_role.arn
    region                 = local.region
    account_id             = local.account_id
    template_version       = var.template_version
    customer_id            = var.customer_id
    external_id            = var.external_id
    execution_role_arn     = aws_iam_role.blocks_execution_role.arn
    read_role_arn          = aws_iam_role.blocks_read_role.arn
    majortom_read_role_arn = aws_iam_role.majortom_read_role.arn
    bucket_arn             = aws_s3_bucket.cur_bucket.arn
  }

  triggers_replace = [
    aws_iam_role.blocks_execution_role.arn,
    aws_iam_role.blocks_read_role.arn,
    aws_s3_bucket.cur_bucket.arn,
    aws_bcmdataexports_export.cur2.arn
  ]

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
          "customerId": "${var.customer_id}",
          "externalId": "${var.external_id}",
          "executionRoleArn": "${aws_iam_role.blocks_execution_role.arn}",
          "readRoleArn": "${aws_iam_role.blocks_read_role.arn}",
          "majorTomReadRoleArn": "${aws_iam_role.majortom_read_role.arn}",
          "bucketArn": "${aws_s3_bucket.cur_bucket.arn}",
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
          "customerId": "${self.input.customer_id}",
          "externalId": "${self.input.external_id}",
          "executionRoleArn": "${self.input.execution_role_arn}",
          "readRoleArn": "${self.input.read_role_arn}",
          "majorTomReadRoleArn": "${self.input.majortom_read_role_arn}",
          "bucketArn": "${self.input.bucket_arn}",
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
    aws_s3_bucket.cur_bucket,
    aws_s3_bucket_policy.cur_bucket,
    aws_bcmdataexports_export.cur2
  ]
}
