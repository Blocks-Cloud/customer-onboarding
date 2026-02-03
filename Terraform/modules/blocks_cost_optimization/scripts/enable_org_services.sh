#!/usr/bin/env bash
#
# Enable Organization Services for Blocks Cost Optimization
#
# This script enables Cost Optimization Hub and Compute Optimizer
# across the AWS Organization.
#
# Requirements:
#   - AWS CLI v2
#   - AWS credentials with Organizations admin access
#   - Must run from the management account
#

set -euo pipefail

echo "============================================================"
echo "Enabling Organization Services for Blocks Cost Optimization"
echo "============================================================"

# Verify organization has all features enabled
echo "Verifying organization configuration..."
FEATURE_SET=$(aws organizations describe-organization --query 'Organization.FeatureSet' --output text 2>/dev/null || echo "ERROR")

if [[ "$FEATURE_SET" == "ERROR" ]]; then
    echo "✗ Error: Could not describe organization."
    echo "  Ensure you're running from the management account with proper permissions."
    exit 1
fi

if [[ "$FEATURE_SET" != "ALL" ]]; then
    echo "✗ Error: Organization must have 'All Features' enabled."
    echo "  Current feature set: $FEATURE_SET"
    exit 1
fi

ORG_ID=$(aws organizations describe-organization --query 'Organization.Id' --output text)
echo "✓ Organization verified (ID: $ORG_ID)"

# Enable Cost Optimization Hub
echo ""
echo "Enabling Cost Optimization Hub..."

# 1. Enable service access
if aws organizations enable-aws-service-access \
    --service-principal cost-optimization-hub.bcm.amazonaws.com 2>/dev/null; then
    echo "✓ Enabled AWS Organizations Service Access for Cost Optimization Hub"
else
    echo "✓ Cost Optimization Hub service access already enabled (or skipped)"
fi

sleep 5

# 2. Check current enrollment status first
COH_STATUS=$(aws cost-optimization-hub list-enrollment-statuses \
    --region us-east-1 \
    --query 'Items[0].status' --output text 2>/dev/null || echo "Unknown")

COH_STATUS_UPPER=$(echo "$COH_STATUS" | tr '[:lower:]' '[:upper:]')
if [[ "$COH_STATUS_UPPER" == "ACTIVE" ]]; then
    echo "✓ Cost Optimization Hub Enrollment already active (status: $COH_STATUS)"
else
    # Enable enrollment with retry
    MAX_RETRIES=3
    for attempt in $(seq 1 $MAX_RETRIES); do
        if aws cost-optimization-hub update-enrollment-status \
            --region us-east-1 \
            --status Active \
            --include-member-accounts 2>/dev/null; then
            echo "✓ Enabled Cost Optimization Hub Enrollment (Opt-In)"
            break
        else
            echo "  Attempt $attempt/$MAX_RETRIES failed for Cost Optimization Hub enrollment"
            if [[ $attempt -lt $MAX_RETRIES ]]; then
                SLEEP_TIME=$((5 * attempt))
                echo "  Retrying in $SLEEP_TIME seconds..."
                sleep $SLEEP_TIME
            else
                echo "⚠ Warning: Could not enable Cost Optimization Hub enrollment after $MAX_RETRIES attempts"
            fi
        fi
    done
fi

# Enable Compute Optimizer
echo ""
echo "Enabling Compute Optimizer..."

# 1. Enable service access
if aws organizations enable-aws-service-access \
    --service-principal compute-optimizer.amazonaws.com 2>/dev/null; then
    echo "✓ Enabled AWS Organizations Service Access for Compute Optimizer"
else
    echo "✓ Compute Optimizer service access already enabled (or skipped)"
fi

sleep 5

# 2. Check current enrollment status first
CO_STATUS=$(aws compute-optimizer get-enrollment-status \
    --query 'status' --output text 2>/dev/null || echo "Unknown")

CO_STATUS_UPPER=$(echo "$CO_STATUS" | tr '[:lower:]' '[:upper:]')
if [[ "$CO_STATUS_UPPER" == "ACTIVE" ]]; then
    echo "✓ Compute Optimizer Enrollment already active (status: $CO_STATUS)"
else
    # Enable enrollment with retry
    MAX_RETRIES=3
    for attempt in $(seq 1 $MAX_RETRIES); do
        if aws compute-optimizer update-enrollment-status \
            --status Active \
            --include-member-accounts 2>/dev/null; then
            echo "✓ Enabled Compute Optimizer Enrollment (Opt-In)"
            break
        else
            echo "  Attempt $attempt/$MAX_RETRIES failed for Compute Optimizer enrollment"
            if [[ $attempt -lt $MAX_RETRIES ]]; then
                SLEEP_TIME=$((5 * attempt))
                echo "  Retrying in $SLEEP_TIME seconds..."
                sleep $SLEEP_TIME
            else
                echo "⚠ Warning: Could not enable Compute Optimizer enrollment after $MAX_RETRIES attempts"
            fi
        fi
    done
fi

echo ""
echo "============================================================"
echo "✓ Successfully enabled Cost Optimization Hub and Compute Optimizer"
echo "============================================================"
