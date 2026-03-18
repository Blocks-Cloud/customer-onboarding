############################
# Enable Cost Optimization Hub Opt-In
############################
#
# Best-effort: failures log a warning but never block StackSet deployment.
# Only runs on management accounts.
############################

resource "terraform_data" "enable_coh_opt_in" {
  count = local.is_management_account ? 1 : 0

  input = {
    customer_resource_id = var.customer_resource_id
  }

  provisioner "local-exec" {
    interpreter = ["/bin/bash", "-c"]
    command     = <<-EOT
      echo "=== Enabling Cost Optimization Hub ==="

      # Step 1: Enable AWS Organizations service access
      echo "Enabling AWS Organizations service access for Cost Optimization Hub..."
      aws organizations enable-aws-service-access \
        --service-principal cost-optimization-hub.bcm.amazonaws.com \
        2>/dev/null || echo "COH service access already enabled or skipped"

      sleep 5

      # Step 2: Opt-in (with retry, best-effort)
      MAX_RETRIES=3
      SUCCESS=false
      for attempt in $(seq 1 $MAX_RETRIES); do
        if aws cost-optimization-hub update-enrollment-status \
          --status Active \
          --include-member-accounts 2>/dev/null; then
          echo "Enabled Cost Optimization Hub Enrollment (Opt-In)"
          SUCCESS=true
          break
        else
          echo "  COH attempt $attempt/$MAX_RETRIES failed"
          if [[ $attempt -lt $MAX_RETRIES ]]; then
            sleep $((5 * attempt))
          fi
        fi
      done
      if [ "$SUCCESS" = "false" ]; then
        echo "WARNING: Could not enable Cost Optimization Hub after $MAX_RETRIES attempts. Continuing..."
      fi
    EOT
  }
}

############################
# Enable Compute Optimizer Opt-In
############################
#
# Best-effort: failures log a warning but never block StackSet deployment.
# Only runs on management accounts.
############################

resource "terraform_data" "enable_compute_optimizer_opt_in" {
  count = local.is_management_account ? 1 : 0

  depends_on = [terraform_data.enable_coh_opt_in]

  input = {
    customer_resource_id = var.customer_resource_id
  }

  provisioner "local-exec" {
    interpreter = ["/bin/bash", "-c"]
    command     = <<-EOT
      echo "=== Enabling Compute Optimizer ==="

      # Step 1: Enable AWS Organizations service access
      echo "Enabling AWS Organizations service access for Compute Optimizer..."
      aws organizations enable-aws-service-access \
        --service-principal compute-optimizer.amazonaws.com \
        2>/dev/null || echo "Compute Optimizer service access already enabled or skipped"

      sleep 5

      # Step 2: Opt-in (with retry, best-effort)
      MAX_RETRIES=3
      SUCCESS=false
      for attempt in $(seq 1 $MAX_RETRIES); do
        if aws compute-optimizer update-enrollment-status \
          --status Active \
          --include-member-accounts 2>/dev/null; then
          echo "Enabled Compute Optimizer Enrollment (Opt-In)"
          SUCCESS=true
          break
        else
          echo "  Compute Optimizer attempt $attempt/$MAX_RETRIES failed"
          if [[ $attempt -lt $MAX_RETRIES ]]; then
            sleep $((5 * attempt))
          fi
        fi
      done
      if [ "$SUCCESS" = "false" ]; then
        echo "WARNING: Could not enable Compute Optimizer after $MAX_RETRIES attempts. Continuing..."
      fi
    EOT
  }
}

############################
# Enable StackSets Trusted Access
############################
#
# This resource enables CloudFormation StackSets trusted access with AWS Organizations.
#
# Prerequisites:
#   - AWS CLI installed on the Terraform runner
#   - Credentials with organizations:EnableAWSServiceAccess and
#     cloudformation:ActivateOrganizationsAccess permissions
#
# What this does:
#   1. Enables AWS Organizations service access for CloudFormation StackSets
#   2. Activates trusted access for CloudFormation StackSets
#   3. Waits for activation to complete
############################

resource "terraform_data" "enable_stacksets_trusted_access" {
  count = local.is_management_account && local.deploy_stackset ? 1 : 0

  input = {
    customer_resource_id = var.customer_resource_id
  }

  provisioner "local-exec" {
    interpreter = ["/bin/bash", "-c"]
    command     = <<-EOT
      set -e

      echo "=== Enabling StackSets Trusted Access ==="

      # Step 1: Enable AWS Organizations service access for CloudFormation StackSets
      echo "Enabling AWS Organizations service access for CloudFormation StackSets..."
      aws organizations enable-aws-service-access \
        --service-principal member.org.stacksets.cloudformation.amazonaws.com \
        2>/dev/null || echo "Service access already enabled or skipped"

      # Wait for IAM propagation
      sleep 10

      # Step 2: Check current activation status
      echo "Checking current StackSets activation status..."
      CURRENT_STATUS=$(aws cloudformation describe-organizations-access \
        --query 'Status' --output text 2>/dev/null || echo "DISABLED")

      if [ "$CURRENT_STATUS" = "ENABLED" ]; then
        echo "StackSets trusted access is already ENABLED"
        exit 0
      fi

      # Step 3: Activate trusted access (with retry)
      echo "Activating CloudFormation StackSets trusted access..."
      MAX_STACKSETS_RETRIES=3
      for attempt in $(seq 1 $MAX_STACKSETS_RETRIES); do
        if aws cloudformation activate-organizations-access 2>/dev/null; then
          echo "Activated CloudFormation StackSets trusted access"
          break
        else
          echo "  Attempt $attempt/$MAX_STACKSETS_RETRIES failed"
          if [[ $attempt -lt $MAX_STACKSETS_RETRIES ]]; then
            sleep $((2 ** attempt))
          else
            echo "WARNING: Could not activate StackSets trusted access after $MAX_STACKSETS_RETRIES attempts"
          fi
        fi
      done

      # Step 4: Wait for activation to complete (max 12 attempts, 30 seconds each = 6 minutes)
      echo "Waiting for activation to complete..."
      for i in $(seq 1 12); do
        STATUS=$(aws cloudformation describe-organizations-access \
          --query 'Status' --output text 2>/dev/null || echo "UNKNOWN")

        if [ "$STATUS" = "ENABLED" ]; then
          echo "StackSets trusted access is now ENABLED"
          exit 0
        fi

        echo "Attempt $i/12: Status is $STATUS, waiting 30 seconds..."
        sleep 30
      done

      echo "ERROR: StackSets activation did not complete within 6 minutes"
      exit 1
    EOT
  }
}

############################
# Outputs for debugging
############################

output "stacksets_trusted_access_enabled" {
  description = "Whether StackSets trusted access setup was triggered"
  value       = local.is_management_account && local.deploy_stackset
}
