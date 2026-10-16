# Blocks AI Control changelog

> [!NOTE]
> Customer-facing changes to the optional Blocks AI Control add-on stack. It is versioned and released
> separately from Step 1 and Step 2; their changelog does not list these changes.

## v0.2.2 (2026-10-16)

### Permissions
- Management account: on the policy role `BlocksAIControlPolicyRole-<id>`, `bedrock:GetGuardrail` and `bedrock:CreateGuardrailVersion` now apply only to guardrails tagged `OwnedBy: Blocks.cloud`, and `bedrock:TagResource` may now only set the `OwnedBy: Blocks.cloud` tag and no other tag. New: `bedrock:ListTagsForResource` on guardrails in your management account, to check that tag.
- Management account: on the lifecycle role `BlocksAIControlLifecycleRole-<id>`, `bedrock:DeleteGuardrail` now applies only to guardrails tagged `OwnedBy: Blocks.cloud`. New: `bedrock:ListTagsForResource` on guardrails in your management account, to check that tag.

### Changed
- The kill switch now treats a guardrail as its own only when it has both the name `BlocksAIControlBlockAll-<id>` and the tag `OwnedBy: Blocks.cloud`. A guardrail with that name but without the tag is never used, changed or deleted: engaging fails for that region with `guardrail_name_taken`, and a dry run reports the name as taken.
- The management account block is now left alone when an engage targets the management account itself or names no organization root, and when a release names only OUs or accounts. The answer to Blocks says why it was skipped.
- The overall result of an answer to Blocks now covers both the service control policy part and the management account part. When only the management account part is incomplete, the answer carries the error code `management_account_incomplete`.
- The kill switch now checks every account-level enforced guardrail configuration a region lists, not only the first, and treats an unexpected answer from AWS as an error instead of guessing.
- Deleting the stack now fails, so it can be retried, whenever the kill switch's guardrail in a region cannot be deleted (unless it is already gone). Guardrails without the `OwnedBy: Blocks.cloud` tag are left in place.
- Calls to the Bedrock enforcement API no longer follow redirects, and error codes taken from AWS answers contain only letters and digits.

### Fixed
- If a region already has an account-level enforced guardrail of your own, engaging now puts the kill switch's enforcement next to it as intended, instead of stopping that region with a conflict. Your configuration is never changed and is reported for information only, on engage, release and dry run.

## v0.2.1 (2026-10-16)

### Permissions
- Management account: the policy role `BlocksAIControlPolicyRole-<id>` (assumed only by the kill switch Lambda in the control account) now also has `bedrock:CreateGuardrail`, `bedrock:ListGuardrails`, `bedrock:ListEnforcedGuardrailsConfiguration`, `bedrock:PutEnforcedGuardrailConfiguration`, `bedrock:DeleteEnforcedGuardrailConfiguration` and `account:ListRegions`; `bedrock:GetGuardrail`, `bedrock:CreateGuardrailVersion` and `bedrock:TagResource` on guardrails in your management account only; and `ssm:GetParametersByPath` on the public AWS parameter that lists Bedrock regions.
- Management account: the lifecycle role `BlocksAIControlLifecycleRole-<id>` now also has `bedrock:ListGuardrails`, `bedrock:ListEnforcedGuardrailsConfiguration`, `bedrock:DeleteEnforcedGuardrailConfiguration` and `account:ListRegions`; `bedrock:DeleteGuardrail` on guardrails in your management account only; and `ssm:GetParametersByPath` on the public Bedrock region list. It uses them only when the stack is deleted.

### Added
- Service control policies never apply to the management account, so the kill switch now also blocks Bedrock there. This is always on, with no parameter. When Blocks engages the kill switch, it does this in every Bedrock region your management account has enabled: it creates the guardrail `BlocksAIControlBlockAll-<id>` (tagged `OwnedBy: Blocks.cloud`) and a published version if they do not exist yet. The guardrail blocks all input and output. It then enforces that guardrail at account level for all models.
- If a region already has an account-level enforced guardrail of your own, the kill switch reports it for information, never changes or removes it, and puts its own enforcement next to it.
- Releasing removes only the kill switch's own enforcement and keeps the guardrails, so a later engage reuses them. A dry run changes nothing and reports, per region, whether the guardrail exists, whether it is enforced and whether there is a conflict.
- A region that fails does not stop the other regions. The answer to Blocks now has a separate per-region section for the management account. The kill switch logs contain only IDs, regions and counts, never guardrail, account or OU names.
- Deleting the stack now also removes the kill switch's enforcement and its guardrails in every region of the management account. If the block cannot be removed in a region, the stack delete fails and can be retried, so no block is left behind without you knowing.

### Changed
- When the stack cleanup step fails on delete, the CloudFormation stack events now show error codes only, never names or ARNs.

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

