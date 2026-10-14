# Blocks AI Control changelog

> [!NOTE]
> Customer-facing changes to the optional Blocks AI Control add-on stack. It is versioned and released
> separately from Step 1 and Step 2; their changelog does not list these changes.

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

