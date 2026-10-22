# Blocks Customer Onboarding

Infrastructure-as-code templates for onboarding to **Blocks** ([blocks.cloud](https://blocks.cloud)).

See [CHANGELOG.md](CHANGELOG.md) for what each release changes, permissions first.

## Overview

Onboarding takes 2 steps:

| Step | Name | Access level | Where it runs |
|------|--------|--------------|---------------|
| 1 | Savings estimation | Read-only | Management, member or standalone account |
| 2 | Blocks membership | Read + write | Organization management account only |

> [!IMPORTANT]
> Step 1 access expires. Blocks can assume the Step 1 read roles only until 90 days after you create the
> Step 1 stack. Updating the stack doesn't change that date. Upgrade to Step 2 before then to keep access. The
> `AccessExpiresAt` stack output shows the date in UTC.

Step 2 removes the Step 1 stack when it deploys.

## Prerequisites

- Region: **us-east-1**. The templates you deploy refuse any other region.
- Step 1: any AWS account. In an organization's management account, it also deploys the read role
  to member accounts through a StackSet, and AWS Organizations **All Features** must be enabled.
- Step 2: the **organization management account**, with AWS Organizations **All Features** enabled.
- **Contact Blocks** to receive your configuration values.

## Deployment

Templates are in `Cloudformation/`:

| Step | Template | Deployed to |
|------|----------|-------------|
| 1 | `01_step/Blocks-CostEstimations.yaml` | The account you deploy in |
| 1 | `01_step/Blocks-CostEstimations-SubAccounts.yaml` | Member accounts, through the Step 1 StackSet |
| 2 | `02_step/Blocks-CostOptimization.yaml` | Management account |
| 2 | `02_step/Blocks-CostOptimization-SubAccounts.yaml` | Member accounts, through the Step 2 StackSet |
| 2 | `02_step/Blocks-EventForwarding.yaml` | All accounts, in 17 regions, through two StackSets |

You deploy only the top-level template for each step. The others are deployed for you.

## Support

Email support@blocks.cloud.
