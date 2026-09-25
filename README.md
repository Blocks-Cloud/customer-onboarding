# Blocks Customer Onboarding

Infrastructure-as-code templates for onboarding to **Blocks** ([Blocks.cloud](https://blocks.cloud)).

## Overview

This repository provides a 2-step onboarding process:

| Step | Module | Access Level | Purpose |
|------|--------|--------------|---------|
| 1 | Cost Estimations | Read-only | Cost analysis and visibility |
| 2 | Cost Optimization | Read + Write | Active cost optimization |

## Prerequisites

- AWS Organizations with **All Features** enabled
- Access to the **Organization Management Account**
- Region: **us-east-1**
- **Contact Blocks** to receive your configuration values

## Deployment Options

### CloudFormation

Templates are located in `Cloudformation/`:
- **Step 1:** `01_step/Blocks-CostEstimations.yaml`
- **Step 2:** `02_step/Blocks-CostOptimization.yaml`

### Terraform

**Step 1 - Cost Estimations:**
```hcl
module "blocks_cost_estimations" {
  source = "github.com/Blocks-Cloud/customer-onboarding.git//Terraform/modules/blocks_cost_estimations?ref=v0.1.1"

  customer_id           = "<provided by Blocks>"
  external_id           = "<provided by Blocks>"
  blocks_account_id     = "<provided by Blocks>"
  stackset_template_url = "<provided by Blocks>"
}
```

**Step 2 - Cost Optimization:**
```hcl
module "blocks_cost_optimization" {
  source = "github.com/Blocks-Cloud/customer-onboarding.git//Terraform/modules/blocks_cost_optimization?ref=v0.1.1"

  customer_id           = "<provided by Blocks>"
  external_id           = "<provided by Blocks>"
  blocks_account_id     = "<provided by Blocks>"
  stackset_template_url = "<provided by Blocks>"
}
```

See `Terraform/examples/` for complete usage examples.

## Savings Plan holder accounts

Step 2 creates four empty member accounts in your organization: three for Compute Savings Plans and one for Database Savings Plans. You own these accounts. Their root email is a plus-address of your management account root email. Blocks holds only an execution role in them and buys Savings Plans on your behalf. Blocks never moves these accounts out of your organization.

### What a step-2 stack delete does

- Removes the Blocks execution role, the deny policies and the EventBridge forwarding from your accounts.
- Stops all Blocks purchases immediately.
- Does **not** close the four holder accounts and does **not** cancel active Savings Plans. Plans keep applying to usage in your organization until they expire. Plans bought in the last 7 days can be returned; ask Blocks before you delete the stack.

### Handing a holder account to Blocks

If you want Blocks to take over one holder account, the transfer is yours to run. Blocks cannot do these steps for you.

1. Sign in as the account root user and add a payment method, phone number and support plan. AWS requires this before a member account can leave an organization.
2. From your management account, remove the account from your organization (`aws organizations remove-account-from-organization --account-id <id>`).
3. Tell Blocks the account id. Blocks sends an organization invitation from account `503132503926`.
4. Sign in as the account root user and accept the invitation.

The Savings Plans stay in the account through the transfer.
