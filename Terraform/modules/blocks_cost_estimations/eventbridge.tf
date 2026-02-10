############################
# EventBridge - Deployment Notification
############################
#
# - On apply: Sends CREATE_COMPLETE after all resources are created
# - On destroy: Sends DELETE_COMPLETE before resources are destroyed
#
############################

resource "terraform_data" "notify_blocks" {
  # Store values needed for destroy provisioner
  input = {
    blocks_account_id     = var.blocks_account_id
    notifier_role_arn     = aws_iam_role.blocks_estimations_notifier_role.arn
    account_id            = local.account_id
    template_version      = var.template_version
    customer_resource_id  = var.customer_resource_id
    external_id           = var.external_id
    read_role_arn         = aws_iam_role.blocks_estimations_read_role.arn
    account_type          = local.is_management_account ? "management" : "non_management"
    stackset_deployed     = local.is_management_account && local.deploy_stackset ? "true" : "false"
    organization_root_id  = local.organization_root_id != null ? local.organization_root_id : ""
    management_account_id = local.management_account_id != null ? local.management_account_id : ""
  }

  # Notify on successful deployment
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
        --role-arn "${aws_iam_role.blocks_estimations_notifier_role.arn}" \
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
          "source": "terraform.blocks_cost_estimations",
          "time": "'"$EVENT_TIME"'",
          "account": "${local.account_id}",
          "templateVersion": "${var.template_version}",
          "customerResourceId": "${var.customer_resource_id}",
          "externalId": "${var.external_id}",
          "readRoleArn": "${aws_iam_role.blocks_estimations_read_role.arn}",
          "accountType": "${local.is_management_account ? "management" : "non_management"}",
          "stackSetDeployed": "${local.is_management_account && local.deploy_stackset ? "true" : "false"}",
          "organizationRootId": "${local.organization_root_id != null ? local.organization_root_id : ""}",
          "managementAccountId": "${local.management_account_id != null ? local.management_account_id : ""}",
          "step": "1",
          "status": "CREATE_COMPLETE"
        }' \
        --region us-east-1

      echo "Notification sent successfully"
    EOF
  }

  # Notify on destroy (uses triggers because other resources may already be destroyed)
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
          "source": "terraform.blocks_cost_estimations",
          "time": "'"$EVENT_TIME"'",
          "account": "${self.input.account_id}",
          "templateVersion": "${self.input.template_version}",
          "customerResourceId": "${self.input.customer_resource_id}",
          "externalId": "${self.input.external_id}",
          "readRoleArn": "${self.input.read_role_arn}",
          "accountType": "${self.input.account_type}",
          "stackSetDeployed": "${self.input.stackset_deployed}",
          "organizationRootId": "${self.input.organization_root_id}",
          "managementAccountId": "${self.input.management_account_id}",
          "step": "1",
          "status": "DELETE_COMPLETE"
        }' \
        --region us-east-1 || true

      echo "Notification sent successfully"
    EOF
  }

  # Only notify after ALL resources are successfully created
  depends_on = [
    aws_iam_role.blocks_estimations_read_role,
    aws_iam_role.blocks_estimations_notifier_role,
    aws_iam_role_policy.blocks_estimations_notifier_policy,
    aws_iam_policy.blocks_savings_estimation_read_only,
    aws_iam_role_policy_attachment.blocks_estimations_read_role_custom_policy,
    aws_iam_role_policy_attachment.blocks_estimations_read_role_compute_optimizer,
    aws_iam_role_policy_attachment.blocks_estimations_read_role_organizations,
    aws_iam_role_policy_attachment.blocks_estimations_read_role_account_management,
    aws_iam_role_policy_attachment.blocks_estimations_read_role_savings_plans,
    aws_iam_role_policy_attachment.blocks_estimations_read_role_resource_groups,
    aws_cloudformation_stack_set.cost_estimations,
    aws_cloudformation_stack_set_instance.cost_estimations
  ]
}
