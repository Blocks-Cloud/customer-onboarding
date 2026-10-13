# Changelog

> [!NOTE]
> **This changelog starts at v0.2.5.** Older releases are available as git tags. The v0.2.5 section is a
> baseline of what that release deploys; later releases list only their changes, permissions first.

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
