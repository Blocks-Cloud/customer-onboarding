# Blocks Customer Onboarding

This repository contains AWS infrastructure-as-code templates for onboarding customers to **Blocks** ([Blocks.cloud](https://blocks.cloud)) - a cloud cost optimization and analysis platform.

## Overview

Blocks helps organizations optimize their AWS spending by analyzing Cost and Usage Reports (CUR) data along with comprehensive resource inventory information. This repository provides the necessary infrastructure to:

1. **Set up AWS Cost and Usage Reports (CUR 2.0)** - Enable detailed billing data exports to S3
2. **Create secure cross-account access** - Establish IAM roles for Blocks to analyze your AWS account
3. **Enable cost optimization analysis** - Grant read-only access to 40+ AWS services for comprehensive insights

## What Gets Deployed

### Main/Payer Account Resources

- **S3 Bucket** for CUR data storage (with encryption and lifecycle policies)
- **BCM Data Exports (CUR 2.0)** with hourly granularity and resource-level details
- **Cross-account IAM Role** with comprehensive read-only permissions including:
  - Cost Explorer, Budgets, Savings Plans
  - Compute Optimizer, Trusted Advisor
  - Service Quotas, AWS Organizations
  - Resource inventory across 40+ AWS services (EC2, RDS, Lambda, S3, etc.)
  - Pricing API access
- **Lambda Function** (optional) to automate historical data backfill requests

### Sub-account Resources

- **Cross-account IAM Role** with similar read-only permissions (without CUR setup)
- Access to Cost Explorer and cost management tools within the sub-account

## Deployment Options

Choose either **CloudFormation** or **Terraform** based on your preference:

### Option 1: CloudFormation (Recommended for Quick Setup)

Deploy pre-built templates via AWS Console or CLI.

#### Main/Payer Account Template

```bash
aws cloudformation create-stack \
  --stack-name blocks-cost-optimization \
  --template-body file://Cloudformation/Blocks-CF-Template.yaml \
  --parameters \
    ParameterKey=BlocksExternalAccountId,ParameterValue=503132503926 \
    ParameterKey=ExternalId,ParameterValue=your-secure-external-id \
  --capabilities CAPABILITY_NAMED_IAM \
  --region us-east-1
```

**⚠️ Important:** Must be deployed in **us-east-1** (CUR 2.0 requirement)

### Option 2: Terraform (For Infrastructure-as-Code Workflows)

More flexible configuration options with version control integration.

See [Terraform/README.md](Terraform/README.md) for detailed instructions.

**Quick Start:**

```bash
cd Terraform

# Configure your variables
cat > terraform.tfvars <<EOF
external_account_id = "503132503926"
external_id         = "your-secure-external-id"
aws_region          = "us-east-1"
EOF

# Deploy
terraform init
terraform plan
terraform apply
```

## Key Parameters

| Parameter | Description | Default | Required |
|-----------|-------------|---------|----------|
| `BlocksExternalAccountId` | Blocks AWS account ID that will assume the role | `503132503926` | ✅ |
| `ExternalId` | Shared secret for secure cross-account access | `blocks-shared-secret` | ✅ |
| `BucketNamePrefix` | Prefix for the S3 bucket name | `blocks-cur-data` | ❌ |
| `ExportName` | Name for the CUR 2.0 export | `hourly-cost-usage-cur2` | ❌ |
| `TimeGranularity` | CUR data granularity | `HOURLY` | ❌ |
| `BackfillMonths` | Months of historical data to request | `12` | ❌ |

## Outputs

After successful deployment, you'll receive:

```
CURBucketName          = "blocks-cur-data-123456789123-us-east-1"
BillingReadRoleArn     = "arn:aws:iam::123456789123:role/hourly-cost-usage-cur2-123456789123-billing-read-role"
ExportNameOut          = "hourly-cost-usage-cur2-123456789123"
BackfillCaseId         = "case-123456789-abcd-2024" (if Support API available)
```

**Important:** Share the `BillingReadRoleArn` with your Blocks account representative to complete the onboarding process.

## Security & Permissions

### What Access Does Blocks Get?

Blocks receives **read-only** access to:

- ✅ Cost and Usage Reports (S3 bucket - `cur2/*` prefix only)
- ✅ Cost Explorer, Budgets, Savings Plans data
- ✅ Resource metadata (instance types, configurations, tags)
- ✅ Compute Optimizer recommendations
- ✅ Trusted Advisor checks
- ✅ Service utilization metrics

### What Access Does Blocks NOT Get?

- ❌ Write/modify permissions on any resources
- ❌ Access to application data or customer information
- ❌ Ability to launch, terminate, or modify resources
- ❌ Access to secrets, credentials, or sensitive data
- ❌ Ability to create or modify IAM policies

### Cross-Account Security

The IAM role uses AWS best practices:

- **External ID** requirement prevents the "confused deputy" problem
- **Scoped permissions** limited to cost optimization analysis
- **1-hour session duration** (configurable)
- **Least privilege** read-only access only

## Data & Privacy

### What Data Is Collected?

- Cost and usage line items from CUR
- Resource inventory (types, sizes, configurations)
- Service utilization metrics
- Optimization recommendations

### Where Is Data Stored?

- **Your CUR data** stays in your S3 bucket (you control retention)
- **Blocks analysis** processes data in Blocks-controlled infrastructure
- All data transmission uses encryption in transit (TLS)

## Post-Deployment

### 1. Historical Data Backfill

The template attempts to automatically request historical data via AWS Support. If you have an AWS Support plan:

- ✅ A Support case is created automatically
- ✅ AWS typically backfills 12+ months within 24-48 hours

If you don't have AWS Support:

- ⚠️ Forward data will be collected starting from deployment
- 📧 Contact your AWS account team to request historical data backfill

### 2. Share Role ARN with Blocks

Provide the `BillingReadRoleArn` output to your Blocks representative to complete setup.

### 3. Wait for Initial Data

- CUR 2.0 exports typically update **every 8-24 hours**
- First analysis available within 24-48 hours of deployment

## Architecture

```
┌──────────────────────────────────────────────────────────────┐
│                     Your AWS Account                         │
│                                                              │
│  ┌─────────────┐         ┌──────────────┐                  │
│  │   AWS CUR   │────────>│  S3 Bucket   │                  │
│  │ (Hourly)    │         │ (Encrypted)  │                  │
│  └─────────────┘         └──────┬───────┘                  │
│                                  │                          │
│                                  │ Read Access              │
│                          ┌───────▼────────┐                │
│                          │  IAM Role      │                │
│                          │  (Read-Only)   │                │
│                          └───────┬────────┘                │
│                                  │                          │
└──────────────────────────────────┼──────────────────────────┘
                                   │
                                   │ AssumeRole
                                   │ (External ID Required)
                                   │
                          ┌────────▼───────────┐
                          │   Blocks.cloud     │
                          │  Analysis Engine   │
                          └────────────────────┘
```

## Troubleshooting

### CUR Data Not Appearing

- Verify deployment in **us-east-1** region
- Check S3 bucket policy allows `bcm-data-exports.amazonaws.com`
- CUR exports can take 8-24 hours for initial data

### Historical Backfill Not Requested

- Requires AWS Support plan (Business or Enterprise)
- Manually create Support case if Lambda fails
- Template: "Request backfill for CUR 2.0 export [export-name]"

### IAM Role Assumption Fails

- Verify `ExternalId` matches on both sides
- Check trust relationship includes correct Blocks account ID
- Ensure role has not been modified after creation

### Terraform Apply Errors

- Ensure AWS credentials have sufficient permissions
- Check region is set to `us-east-1`
- Review `terraform.tfvars` for correct values

## Support

- **Blocks Support:** Contact your Blocks account representative
- **AWS Issues:** Open AWS Support case or check AWS documentation
- **Template Issues:** Review CloudFormation/Terraform logs in AWS Console

## Cleanup

To remove all resources:

**CloudFormation:**
```bash
aws cloudformation delete-stack --stack-name blocks-cost-optimization
```

**Terraform:**
```bash
terraform destroy
```

⚠️ **Note:** This will stop CUR collection and remove Blocks' access to your account.

## Repository Structure

```
.
├── Cloudformation/
│   ├── Blocks-CF-Template.yaml            # Main/payer account template
│   └── Blocks-CF-Subaccounts-Template.yaml # Sub-account template
│
└── Terraform/
    ├── README.md                           # Terraform-specific docs
    ├── main.tf                             # Main configuration
    ├── variables.tf                        # Input variables
    ├── outputs.tf                          # Output values
    ├── iam.tf                              # IAM role definitions
    ├── s3.tf                               # S3 bucket configuration
    ├── bcm.tf                              # CUR 2.0 export configuration
    ├── lambda.tf                           # Backfill Lambda (optional)
    └── terraform.tfvars                    # Your configuration values
```

## License

This infrastructure code is provided by Blocks for customer onboarding purposes.

## About Blocks

Blocks helps organizations optimize their cloud spending through:
- Real-time cost visibility and analysis
- Resource optimization recommendations
- Reserved Instance and Savings Plan guidance
- Usage anomaly detection
- Cost allocation and chargeback reporting

Learn more at [blocks.cloud](https://blocks.cloud)

