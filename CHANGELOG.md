# Changelog

> [!NOTE]
> **This changelog starts at v0.2.5.** Older releases are available as git tags. The v0.2.5 section is a
> baseline of what that release deploys; later releases list only their changes, permissions first.

## v0.2.22 (2026-11-25)

### Permissions
- Step 1: Savings estimation, management account, CloudFormation only: `EnableStackSetsLambdaRole` (the role used by the stack's own setup Lambda, not assumable by Blocks) can again call `iam:CreateServiceLinkedRole` without the `iam:AWSServiceName` condition added in v0.2.21. This is the same grant as v0.2.20. AWS does not match that condition when StackSets trusted access is turned on, so the condition blocked the setup.

### Fixed
- Step 1: Savings estimation, CloudFormation only: v0.2.21 failed to deploy in organizations that had not yet turned on StackSets trusted access, because the setup Lambda could not create the StackSets service-linked role. Step 1 now deploys in these organizations again.

## v0.2.21 (2026-11-25)

### Permissions
- Step 1: Savings estimation, management and member accounts, CloudFormation only: the `BlocksStep1Guardrails` inline policy on `BlocksEstimationsReadRole` now also denies `cloudformation:GetTemplateSummary`. `ViewOnlyAccess` grants it, and it returns a stack's parameter defaults and template Metadata, which can hold hardcoded secrets.
- Step 1: Savings estimation, management and member accounts, CloudFormation only: `BlocksStep1Guardrails` now also denies `glacier:GetJobOutput` (archive contents), `ssm:GetCommandInvocation` (Run Command output) and `timestream:Select` (table rows). No attached policy grants them today; the deny keeps it that way if an AWS managed policy adds them later.
- Step 1: Savings estimation, management account, CloudFormation only: `EnableStackSetsLambdaRole` (the role used by the stack's own setup Lambda, not assumable by Blocks) can now call `iam:CreateServiceLinkedRole` only for the StackSets service-linked roles (`stacksets.cloudformation.amazonaws.com` and `member.org.stacksets.cloudformation.amazonaws.com`). Before this change it could create a service-linked role for any service.
- Step 1: Savings estimation, management account, CloudFormation only: `EnableStackSetsLambdaRole` can now read the StackSet template (`s3:GetObject`, `s3:GetObjectVersion`) only from Blocks' three template buckets, named exactly, instead of any bucket whose name starts with `blocks-customer-templates`. Bucket names are global, so the prefix also matched look-alike buckets someone else could register.

## v0.2.20 (2026-11-23)

### Permissions
- Step 1: Savings estimation and Step 2: Blocks membership, management and member accounts: the data protection policies now deny `mobiletargeting:Get*`, `mobiletargeting:List*` (Amazon Pinpoint) and `sms-voice:*` (SMS and voice messaging). Before this change these reads were not denied, because the policy listed `pinpoint:Get*`, `pinpoint:List*`, `pinpoint-email:*` and `pinpoint-sms-voice:*`, which are not IAM action prefixes and matched nothing. Those four entries and `sesv2:Get*`, `sesv2:List*` are removed. SES v2 and Pinpoint email calls are authorized as `ses:` actions, so they stay denied by the existing `ses:Get*` and `ses:List*` entries.
- Step 1: Savings estimation and Step 2: Blocks membership, management and member accounts: the data protection policies now deny `redshift-data:*` instead of six separate actions (`ExecuteStatement`, `BatchExecuteStatement`, `GetStatementResult`, `GetStatementResultV2`, `DescribeStatement`, `ListStatements`). The deny now covers the whole Redshift Data API. The shorter form keeps the Step 1 policy under the IAM size limit.
- Step 1: Savings estimation and Step 2: Blocks membership, management and member accounts: the CloudWatch Logs Insights deny on `logs:StartQuery` now applies to every log group except the Container Insights performance log groups (`/aws/containerinsights/*/performance`). Before this change it was written with a condition key CloudWatch Logs does not have, so it denied queries on all log groups, including the Container Insights ones it was meant to allow.
- Step 1: Savings estimation and Step 2: Blocks membership, management and member accounts: the data protection policies now deny `logs:DescribeQueries`, so Blocks can't list the IDs of Logs Insights queries other principals started. `logs:GetQueryResults` is no longer denied, because IAM can't limit it to specific log groups. It returns results only for a query ID the caller supplies, and Blocks can no longer list those IDs.

## v0.2.19 (2026-11-20)

### Fixed
- Step 2: Blocks membership, CloudFormation only: redeploying or updating the Step 2 stack no longer moves the 4 Blocks-managed accounts out of the `BlocksOptimization` OU to the organization root, where the Savings Plans SCP blocked them from buying Savings Plans. The accounts now stay in the OU across redeploys.

## v0.2.18 (2026-11-13)

### Permissions
- Step 1: Savings estimation, management and member accounts, CloudFormation only: `BlocksEstimationsReadRole` now uses the AWS managed policy `job-function/ViewOnlyAccess` instead of `ReadOnlyAccess`. `ViewOnlyAccess` returns resource metadata and grants far fewer reads. The Terraform module's role keeps `ReadOnlyAccess`.
- Step 1: Savings estimation, management account, CloudFormation only: `BlocksEstimationsReadRole` no longer has the AWS managed policy `AWSAccountManagementReadOnlyAccess`.
- Step 1: Savings estimation, management and member accounts: the custom read policy now allows `ce:GetCommitmentPurchaseAnalysis`, `tag:GetResources`, `elasticache:ListTagsForResource`, `aoss:ListCollections`, `aoss:BatchGetCollection`, `aoss:ListTagsForResource`, `es:DescribeReservedInstances`, `kafka:DescribeCluster`, `kafka:DescribeClusterV2`, `kafka:ListClustersV2`, `redshift:DescribeReservedNodes`, `ecr:DescribeImages`, `kinesis:DescribeStreamSummary`, `s3:GetBucketVersioning`, `s3:GetBucketTagging`, `s3:GetReplicationConfiguration`, `s3:GetBucketObjectLockConfiguration`, `cloudtrail:GetTrailStatus`, `cloudtrail:GetEventSelectors`, `elasticfilesystem:DescribeLifecycleConfiguration`, `cloudwatch:DescribeAlarms`, `mq:ListBrokers` and `mq:DescribeBroker`. These are configuration and metadata reads the cost estimate needs that `ViewOnlyAccess` doesn't include.
- Step 1: Savings estimation, management and member accounts: `iam:SimulatePrincipalPolicy` is now limited to `BlocksEstimationsReadRole-*` (previously all resources). Blocks uses it only to check that its own read role has the permissions it needs and isn't blocked by an SCP or permissions boundary. It can no longer simulate any other user or role.
- Step 1: Savings estimation, management and member accounts, CloudFormation only: a new inline policy `BlocksStep1Guardrails` on `BlocksEstimationsReadRole` denies `ecs:DescribeTaskDefinition`, `ecs:DescribeTasks` (container environment variables, which can hold secrets), `ec2:DescribeVpnConnections` (VPN tunnel configuration, including pre-shared keys), `organizations:DescribePolicy` (service control policy contents), `cloudtrail:LookupEvents` (CloudTrail activity history) and `account:Get*` (account contact details, alternate contacts and the root email). It also limits `cloudformation:DescribeStackEvents` and `cloudformation:DescribeStackResources` to Blocks' own onboarding stacks. Account emails still appear in `organizations:ListAccounts`, which Blocks needs for the account list.
- Step 1: Savings estimation, management and member accounts, CloudFormation only: the `sts:TagSession` statement in the `BlocksEstimationsReadRole` trust policy now has the same conditions as `sts:AssumeRole`: Blocks' platform addresses only, and only until the access expiry date. Before this change it had no conditions.

### Changed
- Step 1: Savings estimation, CloudFormation only: Blocks skips ECS Fargate rightsizing in the Step 1 estimate, because it no longer reads ECS task definitions. Step 2 still includes it.

## v0.2.17 (2026-11-10)

- Maintenance release, no changes to deployed resources.

## v0.2.16 (2026-11-06)

### Permissions
- Step 2: Blocks membership, management account, CloudFormation only: `BlocksOnboardingLambdaRole` (the role used by the stack's own setup Lambdas, not assumable by Blocks) now has `sqs:SendMessage`, limited to Blocks' `Blocks-Onboarding-Queue`. The new account check uses it to send its result to Blocks. No other actions were added or removed.

### Added
- Step 2: Blocks membership, CloudFormation only: a new `ManagementAccountId` stack output shows the AWS Organization management account the account check verified. The deployment notification sent to Blocks now includes the same ID.

### Changed
- Step 2: Blocks membership, CloudFormation only: the management account check is now an `AccountCheck` custom resource (new Lambda `AccountCheck-<id>`) instead of a template rule. It runs before any other resource is created and checks with AWS Organizations that the stack is in your organization's management account. If the account is standalone, a member account, or a different management account than Blocks expects, the stack fails with a plain reason before anything else is built, and the result (pass or fail) is sent to Blocks so it can help you fix the deployment.

### Fixed
- Step 2: Blocks membership, CloudFormation only: the root emails of the 4 Blocks-managed accounts now end in the last 6 characters of your Blocks resource ID (`+bc1-<id6>`, `+bc2-<id6>`, `+bc3-<id6>`, `+bd1-<id6>`) instead of the full ID. Management account root emails up to 53 characters now fit AWS's 64-character limit (previously 44), so the accounts are created instead of being skipped with an error. Existing accounts are still matched by name and are not changed.

## v0.2.15 (2026-11-05)

- Maintenance release, no changes to deployed resources.

## v0.2.14 (2026-11-04)

- Maintenance release, no changes to deployed resources.

## v0.2.13 (2026-11-04)

### Permissions
- Step 1: Savings estimation and Step 2: Blocks membership, management and member accounts: the trust policies of `BlocksEstimationsReadRole` (Step 1) and of `BlocksExecutionRole`, `BlocksReadRole` and `MajorTomReadRole` (Step 2) now also have an `IpAddress` condition on `aws:SourceIp`. Blocks can assume these roles only from its platform addresses `63.180.91.77/32`, `52.58.150.93/32` and `63.181.154.255/32`, in addition to the existing external ID check (and, for Step 1, the access expiry date). A leaked external ID can't be used to assume the roles from anywhere else. No actions were added or removed.
- Step 2: Blocks membership, management account: `BlocksExecutionRole` no longer has `cloudtrail:StartLogging` on all trails (`Resource: "*"`), so Blocks can no longer restart one of your own stopped CloudTrail trails. Every CloudTrail write action Blocks has is now limited to its own `blocks-org-trail-*` trails.

## v0.2.12 (2026-11-01)

- Maintenance release, no changes to deployed resources.

## v0.2.11 (2026-10-29)

- Maintenance release, no changes to deployed resources.

## v0.2.10 (2026-10-27)

- Maintenance release, no changes to deployed resources.

## v0.2.9 (2026-10-26)

- Maintenance release, no changes to deployed resources.

## v0.2.8 (2026-10-22)

### Permissions
- Step 1: Savings estimation, management and member accounts: `BlocksEstimationsReadRole` now denies `elasticbeanstalk:DescribeConfigurationSettings`, `elasticbeanstalk:RequestEnvironmentInfo`, `elasticbeanstalk:RetrieveEnvironmentInfo`, `amplify:*`, `codebuild:BatchGet*` and `lambda:GetLayerVersion`. These calls can return environment variables, build specs, layer code links or instance logs, which may contain secrets. Blocks can still list your resources through calls such as `ec2:DescribeInstances`, `autoscaling:Describe*`, `elasticbeanstalk:DescribeEnvironments` and `codebuild:ListProjects`.
- Step 1: Savings estimation and Step 2: Blocks membership, management and member accounts: the data protection policies now deny `rds-data:*` instead of six separate `rds-data:` actions (`ExecuteStatement`, `BatchExecuteStatement`, `ExecuteSql`, `BeginTransaction`, `CommitTransaction`, `RollbackTransaction`). Those six actions already covered the whole RDS Data API, so what Blocks can do does not change. The shorter form keeps the Step 1 policy under the IAM size limit.

## v0.2.7 (2026-10-15)

### Permissions
- Step 1: Savings estimation, management and member accounts: the `BlocksEstimationsReadRole` trust policy now has a `DateLessThan` condition on `aws:CurrentTime`, so Blocks can assume the role only until 90 days after you first deploy. The date is set once and later stack updates or applies don't change it. Upgrade to Step 2 before it passes to keep access. The role description now says this. No actions were added or removed, and Step 2 is unchanged.

### Added
- Step 1: Savings estimation: a new `AccessExpiresAt` stack output (CloudFormation) and `access_expires_at` module output (Terraform) show when Blocks loses access through the read roles (UTC). The deployment notification sent to Blocks now includes the same date.

### Changed
- Step 1: Savings estimation, Terraform only: the module now needs the `hashicorp/time` provider (`>= 0.9`). Run `terraform init` to install it.

### Fixed
- Step 2: Blocks membership, CloudFormation only: deleting the stack now moves the 4 Blocks-managed accounts out of the `BlocksOptimization` OU and back to the organization root. The accounts are still not closed. This leaves the OU empty, so CloudFormation can delete it, and a later redeploy recreates the OU instead of failing because an OU with that name already exists.

## v0.2.6 (2026-10-13)

### Permissions
- Step 1: Savings estimation, management and member accounts: `BlocksEstimationsReadRole` now denies `guardduty:*`, `inspector:*`, `inspector2:*`, `securityhub:*`, `macie2:*`, `detective:*`, `access-analyzer:*`, `auditmanager:*`, `securityagent:*`, `shield:*`, `fms:*`, `identitystore:*`, `identitystore-auth:*` and `sso-directory:*`. AWS `ReadOnlyAccess` grants these, but cost estimation doesn't need them, so Blocks can't read your security findings, vulnerability reports, audit evidence or Identity Center directory. Step 2 is unchanged.

### Changed
- Step 2: Blocks membership, all accounts: ECS write events are now forwarded to Blocks only for `UpdateService`. Other ECS calls, such as frequent `UpdateTaskProtection` heartbeats, are no longer forwarded, which lowers cross-account event costs.

### Fixed
- Step 2: Blocks membership, all accounts: the event forwarding rule now matches MSK events under their real source, `aws.kafka`. It previously listed `aws.msk`, which matched nothing, so MSK write events were never forwarded.

## v0.2.5 (2026-10-06) — baseline

All Blocks roles trust only Blocks' `BlocksCustomerAccessRole` and require your external ID.

### Step 1: Savings estimation (read-only)

| Resource | Where | Purpose |
|----------|-------|---------|
| `BlocksEstimationsReadRole` | All accounts | Read-only cost analysis: AWS `ReadOnlyAccess` plus billing, Savings Plans and Organizations read-only, with explicit denies on data contents |
| `EnableStackSets` Lambda + role | Management | Deploys the read role to member accounts via StackSet |
| Notifier role + EventBridge rule | Management | Sends one deployment notification to Blocks |

### Step 2: Blocks membership (read and write)

Step 2 removes the Step 1 stack.

| Resource | Where | Purpose |
|----------|-------|---------|
| `BlocksReadRole` | All accounts | Read-only cost analysis, same denies as Step 1 |
| `MajorTomReadRole` | All accounts | Read-only access for the Blocks AI assistant |
| `BlocksExecutionRole` | All accounts | Buys Savings Plans and Reserved Instances, manages budgets, alarms and cost settings; in the management account also moves accounts between OUs |
| `BlocksOptimization` OU + 4 accounts | Management | Blocks-managed accounts that hold Savings Plans; not closed when the stack is deleted |
| Savings Plans SCP | Organization root | Only `BlocksExecutionRole` inside the `BlocksOptimization` OU can buy Savings Plans |
| Governance SCP | `BlocksOptimization` OU | Locks down the managed accounts: no leaving the org, IAM users or disabling security services except by Blocks' roles |
| CUR 2.0 export + S3 bucket | Management | Hourly cost and usage data, encrypted, readable by Blocks |
| Onboarding Lambdas | Management | Enable Cost Optimization Hub and Compute Optimizer, create the managed accounts, remove Step 1 |
| Event forwarding rules + role | All accounts | Forward CloudTrail write events and SSM Automation events to Blocks (`eu-central-1`) |
| Notifier role + EventBridge rule | Management | Sends one deployment notification to Blocks |
