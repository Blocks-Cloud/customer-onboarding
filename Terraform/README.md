# Blocks Cost Opmitization Role - Terraform

## Quick Start

### 1. Configure Variables

Edit `terraform.tfvars` with your values:
- `external_account_id` - AWS account ID that will assume the role
- `external_id` - Shared secret for secure role assumption

### 2. Deploy

```bash
terraform init
terraform plan
terraform apply
```

## Outputs

After successful deployment, you'll receive:

```
billing_read_role_arn = "arn:aws:iam::123456789123:role/hourly-cost-usage-cur2-123456789123-billing-read-role"
billing_read_role_name = "hourly-cost-usage-cur2-123456789123-billing-read-role"
cur2_export_id = "arn:aws:bcm-data-exports:us-east-1:123456789123:export/hourly-cost-usage-cur2-123456789123-e67027ff-ead6-4a75-a451-3b8b259c6880"
cur2_export_name = "hourly-cost-usage-cur2-123456789123"
cur_bucket_arn = "arn:aws:s3:::blocks-cur-data-123456789123-us-east-1"
cur_bucket_name = "blocks-cur-data-123456789123-us-east-1"
next_steps = "To request historical data backfill, open an AWS Support case requesting 12 months of data for export 'hourly-cost-usage-cur2-123456789123'"
```

**Important:** Copy the `billing_read_role_arn` - this is the role ARN you'll need to assume to access billing data.

## What Gets Created

- S3 bucket for CUR data storage
- BCM Data Exports (CUR 2.0) with hourly granularity
- IAM role with read-only access to billing, cost, and AWS service data

## Cleanup

```bash
terraform destroy
```
