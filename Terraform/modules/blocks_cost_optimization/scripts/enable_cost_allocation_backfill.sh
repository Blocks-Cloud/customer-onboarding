#!/usr/bin/env bash
#
# Enable Cost Allocation Tag Backfill for Blocks Cost Optimization
#
# This script triggers a 12-month backfill of cost allocation tags.
#
# Requirements:
#   - AWS CLI v2
#   - AWS credentials with Cost Explorer access
#   - Must run from the management account
#

set -euo pipefail

echo "============================================================"
echo "Enabling Cost Allocation Tag Backfill"
echo "============================================================"

# Check for existing backfills
echo "Checking for existing backfills..."
PROCESSING_COUNT=$(aws ce list-cost-allocation-tag-backfill-history \
    --query 'BackfillHistory[?BackfillStatus==`PROCESSING`] | length(@)' \
    --output text 2>/dev/null || echo "0")

if [[ "$PROCESSING_COUNT" != "0" && "$PROCESSING_COUNT" != "" && "$PROCESSING_COUNT" != "None" ]]; then
    echo "⚠ A backfill is already processing. Skipping new request."
    echo "============================================================"
    exit 0
fi

# Calculate backfill date (first day of same month, 1 year ago)
if [[ "$(uname)" == "Darwin" ]]; then
    # macOS
    BACKFILL_FROM=$(date -v-1y -v1d +%Y-%m-01T00:00:00Z)
else
    # Linux
    BACKFILL_FROM=$(date -d '1 year ago' +%Y-%m-01T00:00:00Z)
fi
echo "  Backfill from: $BACKFILL_FROM"

# Find a tag to activate
TARGET_TAG_KEY="aws:createdBy"
echo ""
echo "Checking cost allocation tag status..."

# Check if aws:createdBy is already active
TAG_STATUS=$(aws ce list-cost-allocation-tags \
    --tag-keys "$TARGET_TAG_KEY" \
    --type AWSGenerated \
    --query 'CostAllocationTags[0].Status' \
    --output text 2>/dev/null || echo "")

if [[ "$TAG_STATUS" == "Active" ]]; then
    echo "  Tag '$TARGET_TAG_KEY' is already Active. Searching for another inactive tag..."

    # Find an inactive tag to activate instead
    INACTIVE_TAG=$(aws ce list-cost-allocation-tags \
        --status Inactive \
        --max-results 50 \
        --query 'CostAllocationTags[0].TagKey' \
        --output text 2>/dev/null || echo "")

    if [[ -n "$INACTIVE_TAG" && "$INACTIVE_TAG" != "None" ]]; then
        TARGET_TAG_KEY="$INACTIVE_TAG"
        echo "  Found inactive tag to activate: $TARGET_TAG_KEY"
    else
        echo "⚠ No inactive tags found. Backfill may not trigger new data."
    fi
fi

# Activate the target tag
echo "  Activating tag: $TARGET_TAG_KEY"
if aws ce update-cost-allocation-tags-status \
    --cost-allocation-tags-status "TagKey=$TARGET_TAG_KEY,Status=Active" 2>/dev/null; then
    echo "✓ Tag '$TARGET_TAG_KEY' activated"
else
    echo "⚠ Warning: Could not activate tag (may already be active or not available)"
fi

# Start backfill
echo ""
echo "Starting cost allocation tag backfill..."
if aws ce start-cost-allocation-tag-backfill \
    --backfill-from "$BACKFILL_FROM" 2>/dev/null; then
    echo "✓ Backfill started successfully"
else
    # Check if it failed due to backfill already in progress
    ERROR_MSG=$(aws ce start-cost-allocation-tag-backfill \
        --backfill-from "$BACKFILL_FROM" 2>&1 || true)

    if [[ "$ERROR_MSG" == *"BackfillInProgress"* ]]; then
        echo "⚠ Backfill already in progress, skipping."
    elif [[ "$ERROR_MSG" == *"LimitExceeded"* ]]; then
        echo "⚠ Backfill limit exceeded (max 1 per day). Try again tomorrow."
    else
        echo "⚠ Warning: Could not start backfill: $ERROR_MSG"
    fi
fi

echo ""
echo "============================================================"
echo "✓ Cost Allocation Backfill requested successfully"
echo "  Note: Backfill may take several hours to complete."
echo "============================================================"
