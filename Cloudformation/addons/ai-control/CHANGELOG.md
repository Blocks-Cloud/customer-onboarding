# Blocks AI Control changelog

> [!NOTE]
> Customer-facing changes to the optional Blocks AI Control add-on stack. It is versioned and released
> separately from Step 1 and Step 2; their changelog does not list these changes.

## v0.2.0 (2026-10-15)

### Permissions
- Management account: the setup check role `BlocksAIControlOrgInfoRole-<id>` now also has `cloudformation:DescribeOrganizationsAccess`, `cloudformation:ActivateOrganizationsAccess`, `organizations:EnableAWSServiceAccess`, `iam:GetRole` and `iam:CreateServiceLinkedRole`, used to turn on CloudFormation StackSets trusted access for your organization.
- Management account: new role `BlocksAIControlPolicyRole-<id>`, which only the `BlocksAIControlLambdaRole` role in the control account can assume. It has `organizations:AttachPolicy` and `organizations:DetachPolicy` for the add-on's own deny-Bedrock service control policy only, plus read-only `organizations:ListRoots`, `organizations:ListOrganizationalUnitsForParent`, `organizations:ListAccountsForParent`, `organizations:ListAccounts`, `organizations:ListPoliciesForTarget`, `organizations:ListPolicies`, `organizations:DescribePolicy`, `organizations:DescribeOrganization` and `organizations:ListTargetsForPolicy`.
- Control account: new Lambda execution role `BlocksAIControlLambdaRole` with `sts:AssumeRole` on `BlocksAIControlPolicyRole-<id>` only, and `logs:CreateLogStream` and `logs:PutLogEvents` on the kill switch log group.
- Control account: new role `BlocksAIControlInvokeRole` that Blocks can assume, only from the Blocks AI Control executor role and only with your external ID (plus `sts:TagSession` from that same role). It has `lambda:InvokeFunction` on the kill switch Lambda only and `organizations:DescribeOrganization`. This is the add-on's first role that Blocks can assume; it lives in the control account, not in your management account.

### Added
- A kill switch Lambda, `BlocksAIControlKillSwitch`, deployed into the control account only (us-east-1) through a new service-managed StackSet `BlocksAIControl-<id>`, with its own log group kept for 365 days.
- Through the kill switch, Blocks can attach the deny-Bedrock policy to the roots, OUs and accounts you choose (up to 50 per request), detach it from some or all of them, or run a dry run that changes nothing and reports the policy's content check and the free policy slots on each target. Attaching is refused for the management account, the control account and anything outside your organization. The Lambda reads your organization structure (including account and OU names) to return it to Blocks; its logs contain IDs only.
- The setup check now turns on CloudFormation StackSets trusted access for your organization if it is not already on, and fails with a clear message if it does not turn on.
- New stack outputs `PolicyRoleArn`, `ControlAccountStackSetId`, `InvokeRoleArn` and `KillSwitchFunctionArn`; the notification to Blocks now also includes the policy role, invoke role and kill switch Lambda ARNs.

### Changed
- If the control account cannot be created on a new deployment, the stack now fails with the real reason instead of only reporting it in the `ControlAccountError` output. When the account already exists, problems are still only reported in that output. A failed update from v0.1.0 still rolls back cleanly.
- Deleting the stack now removes the kill switch StackSet first, then detaches the deny-Bedrock policy and moves the control account back to the organization root. The account is still never closed.

## v0.1.0 (2026-10-14)

### Permissions
- Management account: new service control policy `BlocksAIControlDenyBedrock-<id>` that denies `bedrock:*` and `bedrock-mantle:*` on all resources. It is created but not attached; it only takes effect when you block Bedrock through Blocks.
- Management account: new Lambda execution role `BlocksAIControlOrgInfoRole-<id>` for the setup checks, with `organizations:DescribeOrganization`, `organizations:ListRoots`, `organizations:ListPoliciesForTarget`, `organizations:ListAccounts`, `servicequotas:GetServiceQuota`, `servicequotas:GetAWSDefaultServiceQuota`, and `organizations:EnablePolicyType` on the organization root only.
- Management account: new Lambda execution role `BlocksAIControlAccountRole-<id>` for creating the control account, with `organizations:CreateAccount`, `organizations:TagResource`, `organizations:DescribeCreateAccountStatus`, `organizations:ListAccounts`, `organizations:ListParents`, and `organizations:MoveAccount` (limited to your organization's root, OUs and accounts).
- Management account: new Lambda execution role `BlocksAIControlLifecycleRole-<id>` with `organizations:ListTargetsForPolicy` and `organizations:DetachPolicy`, limited to the add-on's own service control policy, used only to detach it when the stack is deleted.
- Management account: new role `BlocksAIControlNotifierRole-<id>`, trusted by EventBridge only, with `sqs:SendMessage` to the Blocks AI Control queue.
- Each Lambda role also has the AWS managed `AWSLambdaBasicExecutionRole` for its logs. The add-on creates no role that Blocks can assume.

### Added
- New optional Blocks AI Control add-on stack (CloudFormation only), deployed in the organization management account in us-east-1.
- Before creating anything, the stack checks that your organization has all features enabled, that the root has fewer than 10 service control policies attached, that there is a free account slot, and that the derived root email fits in 64 characters; it fails with a clear message otherwise. It turns on the service control policy type for the organization root if it is not already enabled.
- Creates the `BlocksAIControlOU-<id>` organizational unit under the root.
- Creates one empty member account, "Blocks AI Control <id>", in that OU. Its root email is your management account root email with a `+aic-<id>` suffix, and IAM user access to billing is denied. Re-running the stack reuses the existing account by name instead of creating another.
- Problems creating the control account do not fail the stack; they are reported in the `ControlAccountError` output.
- Creates an EventBridge rule that notifies Blocks when this stack changes state, including the control account ID, OU ID and policy ID.
- Deleting the stack detaches the deny-Bedrock policy from wherever it is attached and moves the control account back to the organization root. The account is never closed.

