# Blocks Customer Onboarding

Infrastructure-as-code templates for onboarding to **Blocks** ([Blocks.cloud](https://blocks.cloud)).

## Overview

This setup enables Blocks to analyze your AWS costs by:
1. **Creating CUR 2.0 Exports** in your management account
2. **Deploying Read-Only Roles** to your organization via StackSets
3. **Automatically Starting Backfill** for the last 12 months

## Prerequisites

- ✅ **AWS Organizations enabled**
- ✅ **Management Account access**
- ✅ **Organization Root ID** (format: `r-xxxx`)

## Deployment Options

### Option 1: CloudFormation (Recommended - 2 Minutes)

1. **[Click here to deploy via AWS Console](https://us-east-1.console.aws.amazon.com/cloudformation/home?region=us-east-1#/stacks/quickcreate?stackName=blocks-cur2&templateURL=https%3A%2F%2Fblocks-cf-templates.s3.eu-north-1.amazonaws.com%2FBlocks-CF-Template.yaml)**

2. **Enter stack name `blocks-cur2`**

3. **Enter your Organization Root ID**
   - Find this in the [AWS Organizations console](https://console.aws.amazon.com/organizations/v2/home)
   - Format: `r-xxxx`

4. **Click "Create stack"**

That's it! The template will automatically set up everything needed.

**⚠️ Important:** Must be deployed in the **Organization Management Account** in **us-east-1** region.

### Option 2: Terraform

For Infrastructure-as-Code workflows, use our Terraform module.

**Quick Start:**

```bash
cd Terraform/example
terraform init
terraform plan
terraform apply
```

**Module Usage:**

```hcl
module "blocks_onboarding" {
  source = "git::https://github.com/Blocks-Cloud/customer-onboarding.git//Terraform/modules/blocks_onboarding?ref=v1.1.0"
  aws_region = "us-east-1"
  template_version = "1.0.0"
}
```