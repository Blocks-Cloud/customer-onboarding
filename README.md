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
