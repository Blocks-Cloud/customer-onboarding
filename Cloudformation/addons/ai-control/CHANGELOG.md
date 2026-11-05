# Blocks AI Control changelog

> [!NOTE]
> Customer-facing changes to the optional Blocks AI Control add-on stack. It is versioned and released
> separately from Step 1 and Step 2; their changelog does not list these changes.

## v0.2.12 (2026-11-05)

### Fixed
- The key intake and the stored key test of the provider Lambda `BlocksAIControlProvider-OpenAI` now refuse an OpenAI admin key that can only read. Before, such a key was accepted and stopping (engage) a project failed later, because the key could not set a spend limit. The earlier write scope check relied on scope information that OpenAI does not return, so it never refused a key.
- To check that the key can set a spend limit, the provider Lambda now tries to set and remove a spend limit on a project ID that does not exist. This changes nothing in your OpenAI organization. A key that cannot write is refused with `missing_permission`, and the answer names the missing scope when OpenAI names it. An invalid key is reported as `provider_auth_failed`; a rate limit or another OpenAI error is reported as a failure that can be retried, never as a refusal.
- The same checks now read the spend limit of every active project (up to 50) instead of only the first one. No permissions change, and no project is changed.

## v0.2.11 (2026-11-05)

### Fixed
- Stopping (engage) an OpenAI project that has spend alerts no longer fails. OpenAI refuses a project spend limit below any of the project's spend alerts, so such a project was left running. Now, when OpenAI refuses the one-cent limit for that reason, the provider Lambda `BlocksAIControlProvider-OpenAI` lowers each spend alert above one cent to one cent in steps, together with the project spend limit, so the limit is never below an alert. Each alert keeps its currency, interval and notification channel; only its amount changes. Projects without spend alerts are stopped as before.
- The answer to Blocks for such a project carries the earlier limit and the earlier amount of each lowered alert. Up to 5 lowered alerts per project are supported; a project with more, or with two alerts whose IDs start with the same 8 characters, is reported as failed and nothing is changed.
- If a stop fails half way (for example when the request runs out of time), the project's limit and alerts are put back as they were before. If that put back cannot finish, it is logged, and a later release completes it.
- Restarting (release) such a project puts the earlier limit back (or removes the limit if the project had none), then puts each lowered alert back to its earlier amount. An alert you deleted in the meantime is skipped, and when you changed the project's limit yourself, only alerts still at one cent are put back; an alert you set in the meantime is left alone. A release that cannot put every alert back is reported as failed and can be retried.
- The provider Lambda's logs in the control account now note when a project's spend alerts were lowered, when alerts could not be put back and when a failed stop could not be undone, with the project ID and alert counts only. No permissions change, and nothing else of a project is ever changed.

## v0.2.10 (2026-11-04)

### Permissions
- Control account: new Lambda execution role `BlocksAIControlProviderOpenAIRole`, created only when the OpenAI provider is enabled. It has `logs:CreateLogStream` and `logs:PutLogEvents` on its own log group; `secretsmanager:CreateSecret`, `secretsmanager:UpdateSecret`, `secretsmanager:GetSecretValue`, `secretsmanager:DescribeSecret`, `secretsmanager:DeleteSecret`, `secretsmanager:RestoreSecret` and `secretsmanager:TagResource` on secrets named `blocks/ai-control/openai/*` only; `secretsmanager:ListSecrets` (this action cannot be limited to resources); `cloudformation:DescribeStackResource` on its own stack only; and `kms:Encrypt`, `kms:Decrypt`, `kms:GenerateDataKey` and `kms:DescribeKey` on the provider KMS key only.
- Control account: the key policy of the provider KMS key `alias/BlocksAIControlProviderKeys` now also lets `BlocksAIControlProviderOpenAIRole` use the key (`kms:Encrypt`, `kms:Decrypt` and `kms:GenerateDataKey` only through Secrets Manager, and `kms:DescribeKey`), next to `BlocksAIControlProviderAnthropicRole`. The control account can still administer the key but not use it.
- Control account: API Gateway may invoke the OpenAI provider Lambda only through its `intake` alias and only from the key intake route `POST /providers/openai/credentials`.
- No permission changes in the management account or in member accounts.

### Added
- New Lambda `BlocksAIControlProvider-OpenAI` in the control account, with its log group `/aws/lambda/BlocksAIControlProvider-OpenAI` kept for 365 days. It calls only `api.openai.com`. It is created only when Blocks enables the OpenAI provider for your stack (`openai` in the enabled providers); otherwise nothing OpenAI-related is created.
- New key intake route `POST /providers/openai/credentials` on the existing key intake HTTP API `BlocksAIControlIntake`, with the same token checks, origin check and throttling as the Anthropic route. Your browser sends your OpenAI admin key straight to this API in your own account, never to Blocks.
- The intake accepts only OpenAI organization admin keys (keys starting with `sk-admin-`); project and service account keys are refused with `invalid_format` before anything is stored. Before storing a key, the intake checks that it can read your OpenAI organization, list its projects, read a project spend limit and read usage. If the key lists its scopes and has no write scope (`api.all.write` or `api.management.write`), it is refused with `missing_permission`, because it could not set a spend limit. Adding a key never overwrites a stored key that still works; replacing one requires a key from the same OpenAI organization.
- The OpenAI admin key is kept only in Secrets Manager in the control account under `blocks/ai-control/openai/`, encrypted with the provider KMS key. Logs and answers to Blocks contain at most its last 4 characters.
- Through `BlocksAIControlInvokeRole`, Blocks can ask the OpenAI provider Lambda to test the stored key (including the write scope check and when the key expires, as OpenAI reports it), list your OpenAI projects with their current spend limit, read usage (1-minute buckets for up to 24 hours, or 1-hour buckets for up to 7 days) across completions, embeddings, moderations, audio, images, web search, file search and code interpreter, read daily cost in USD by project and line item (up to 31 days per request; OpenAI keeps this data for one year), and delete the stored key (kept recoverable for 7 days).
- Through the same role, Blocks can stop (engage) or restart (release) up to 50 OpenAI projects per request. Engage only sets a monthly project spend limit of one cent (0.01 USD) on each named project, reads it back, and returns the limit it replaced. Release puts that earlier limit back, or removes the limit if the project had none, and only when the project's limit is still the one engage set; a limit someone else changed is left alone. Archived projects are always skipped. It never changes model permissions, rate limits, API keys or key scopes, and never archives a project. A request stops at the first rate limit from OpenAI or when its time runs out, and the projects not tried are reported as not attempted.
- Deleting the stack schedules every stored OpenAI admin key for deletion (recoverable for 7 days). A failure of this cleanup is logged and never blocks the stack delete.
- New outputs `OpenAIProviderIntakeUrl` and `OpenAIProviderFunctionArn` on the provider StackSet's stack in the control account when the OpenAI provider is enabled.

### Changed
- The provider StackSet `BlocksAIControlProviders-<id>` now reads its template (`Blocks-AIControl-Providers.yaml`) from a Blocks Amazon S3 URL (`TemplateURL`) instead of carrying it inside the main template, because with both providers it no longer fits the 51,200 byte limit of an inline template. The URL contains this release's version, so a published version never changes. It creates no account, OU or policy in your organization.
- The provider KMS key and the key intake HTTP API `BlocksAIControlIntake` (with its access log group) are now created when any provider is enabled, not only Anthropic. For a stack with only Anthropic enabled, the resources in the control account are the same as before.
- Logs and answers from the provider Lambdas now also mask anything shaped like an OpenAI key (`sk-admin-`, `sk-proj-`, `sk-svcacct-`), not only Anthropic keys. Updating the stack publishes a new version of `BlocksAIControlProvider-Anthropic` for this; its behaviour is otherwise unchanged.

## v0.2.9 (2026-11-04)

### Changed
- When Blocks tests the stored Anthropic key through the provider Lambda `BlocksAIControlProvider-Anthropic`, the answer now also includes when that key expires, as Anthropic reports it (empty for a key that never expires). The expiry is left out when the stored key is not in your Anthropic API key list. No permissions change.

## v0.2.8 (2026-11-02)

### Changed
- When Anthropic refuses a request from the provider Lambda `BlocksAIControlProvider-Anthropic` with a 4xx error that has no error code of its own, the answer to Blocks now includes Anthropic's error type and message (any key in it masked, whitespace collapsed, cut at 300 characters) instead of only the HTTP status. Authentication, permission, not-found and rate-limit errors still give only the HTTP status. The error detail in an answer can now be up to 400 characters instead of 200.
- The provider Lambda's log line for each request in the control account now also carries the error detail when the request fails.

### Fixed
- Reading token usage no longer fails because Anthropic allows at most 5 grouping dimensions on its usage report. Usage is no longer grouped by workspace; the provider Lambda now takes each row's workspace from your Anthropic API key list instead. The workspace is empty for usage without an API key (Console) and for a key the list does not have, as Anthropic reports it.
- The API key list used for workspaces is cached for 10 minutes. If it cannot be read, usage is still returned with the workspaces already known, and a key the list did not have is not looked up again within those 10 minutes.

## v0.2.7 (2026-11-02)

### Changed
- The key intake now accepts only Anthropic service account keys (keys starting with `sk-ant-svc`) and no longer accepts Anthropic admin keys (`sk-ant-admin`). Any other key is refused with `invalid_format` before it is sent to Anthropic or stored. The checks after that are unchanged: the key must be able to read your Anthropic organization, its API keys and its usage.
- The descriptions of the provider KMS key, the Lambda `BlocksAIControlProvider-Anthropic` and the key intake HTTP API `BlocksAIControlIntake` in the control account now refer to the stored credential as a service account key instead of an admin key. No permissions change.

## v0.2.6 (2026-11-01)

### Permissions
- Control account: the role `BlocksAIControlInvokeRole` that Blocks assumes now also has `lambda:InvokeFunction` on the AI Control provider Lambdas `BlocksAIControlProvider-*` in the control account (us-east-1). It is explicitly denied `lambda:InvokeFunction` on their `intake` alias and denied all `kms:*` and `secretsmanager:*` actions, so Blocks can never read the provider admin keys you store.
- Control account: new Lambda execution role `BlocksAIControlProviderAnthropicRole` with `logs:CreateLogStream` and `logs:PutLogEvents` on its own log group; `secretsmanager:CreateSecret`, `secretsmanager:UpdateSecret`, `secretsmanager:GetSecretValue`, `secretsmanager:DescribeSecret`, `secretsmanager:DeleteSecret`, `secretsmanager:RestoreSecret` and `secretsmanager:TagResource` on secrets named `blocks/ai-control/anthropic/*` only; `secretsmanager:ListSecrets` (this action cannot be limited to resources); `cloudformation:DescribeStackResource` on its own stack only; and `kms:Encrypt`, `kms:Decrypt`, `kms:GenerateDataKey` and `kms:DescribeKey` on the provider key below only.
- Control account: new KMS key `alias/BlocksAIControlProviderKeys` (yearly rotation on) that encrypts the stored provider admin keys. Its key policy lets the control account administer the key but not use it; only `BlocksAIControlProviderAnthropicRole` can use it, and only through Secrets Manager.
- Control account: API Gateway may invoke the Anthropic provider Lambda only through its `intake` alias and only from the key intake route `POST /providers/anthropic/credentials`.

### Added
- A new service-managed StackSet `BlocksAIControlProviders-<id>` deploys the AI Control provider resources into the control account only (us-east-1). It creates no account, OU or policy in your organization. The Anthropic resources below are created only when Blocks has enabled the Anthropic provider for your stack; otherwise the StackSet's stack is empty.
- New Lambda `BlocksAIControlProvider-Anthropic` in the control account, with its log group kept for 365 days. It calls only `api.anthropic.com`.
- New key intake HTTP API `BlocksAIControlIntake` in the control account. Your browser sends your Anthropic admin key straight to this API in your own account, never to Blocks. It accepts only a Blocks token issued for your control account and your Blocks customer, with the `ai-control:store-key` scope and a lifetime of at most 10 minutes, from the one Blocks web origin. Requests are throttled (5 per second, bursts of 10), and its access log, kept for 365 days, never holds the key.
- Before storing a key, the intake checks that it is an Anthropic admin key and that it can read your Anthropic organization, its API keys and its usage. Adding a key never overwrites a stored key that still works; replacing one requires a key from the same Anthropic organization.
- The admin key is kept only in Secrets Manager in the control account, encrypted with the provider KMS key. Logs and answers to Blocks contain at most its last 4 characters.
- Through `BlocksAIControlInvokeRole`, Blocks can ask the provider Lambda to test the stored key, list your Anthropic API keys (and which one is the stored admin key), read token usage (1-minute buckets for up to 24 hours, or 1-hour buckets for up to 7 days) and daily cost (up to 31 days per request), and delete the stored key (kept recoverable for 7 days).
- Through the same role, Blocks can deactivate (engage) or reactivate (release) up to 50 Anthropic API keys per request. Only the keys named are changed; archived and expired keys are always skipped, and an engage never deactivates the stored admin key itself. A request stops at the first rate limit from Anthropic or when its time runs out, and the keys not tried are reported as not attempted.
- Daily cost is read from Anthropic's Analytics cost API, and falls back to Anthropic's older cost report when that API is not available for your organization, does not cover the requested days, or no longer accepts the beta version the add-on sends.
- Deleting the stack schedules every stored provider admin key for deletion (recoverable for 7 days). A failure of this cleanup is logged and never blocks the stack delete.


### Permissions
- Management account: on the setup check role `BlocksAIControlOrgInfoRole-<id>`, `organizations:EnableAWSServiceAccess` now applies only to the service principals `stacksets.cloudformation.amazonaws.com` and `member.org.stacksets.cloudformation.amazonaws.com`, and `iam:CreateServiceLinkedRole` only to those same two service names. The role can no longer turn on trusted access or create service-linked roles for any other AWS service.
- Management account: the control account role `BlocksAIControlAccountRole-<id>` now also has `organizations:ListTagsForResource` and `organizations:DescribeAccount`, used to check the Blocks tags on the control account and to check that it is still in your organization.

### Changed
- On a new deployment, the stack now reuses an existing account named "Blocks AI Control <id>" only if it carries the tags `OwnedBy: Blocks.cloud` and `Purpose: BlocksAIControl` that the stack sets when it creates the account. An account with that name but without both tags is never adopted, moved or changed. If more than one active account carries those tags, the stack fails and asks you to contact support.
- Stack updates and deletes now act only on the control account the stack already recorded, and never look it up by name again, so another account with the same name can never be moved into or out of the `BlocksAIControlOU-<id>` OU.
- Deleting the stack now fails, with the real reason, when the control account cannot be moved out of the OU back to the organization root, instead of failing later with a less clear error when the OU is deleted. The delete can be retried.

### Fixed
- Deleting the stack now also moves a closed control account out of the OU back to the organization root, so the OU can be deleted. The account is still never closed by the stack.
- Deleting the stack now detaches the deny-Bedrock service control policy from every root, OU and account it is attached to. Before, only the first 20 targets were detached when the policy was attached to more.

## v0.2.4 (2026-10-18)

### Changed
- An engage now blocks Bedrock in the management account only after the kill switch confirms that the deny-Bedrock service control policy is attached to the organization root. Otherwise the management account part is skipped and the answer to Blocks gives the reason `scp_not_attached`, so the management account is never blocked while the rest of the organization is not.
- A release now removes the management account block first, before it detaches the service control policy, and that step gets its full time budget counted from its own start.

### Fixed
- A slow detach of the service control policy during a release can no longer use up the time for the management account and leave its guardrail enforced.
- If the first read of your organization fails during a release, the management account block is still removed, and the organization is read again before the policy is detached. If the organization's management account is not the one the stack was deployed in, the release still stops before it changes anything.
- A release always sends an answer to Blocks before the kill switch Lambda times out. If less than 60 seconds are left after the management account part, the policy detach is skipped and reported as `organizations_call_failed` with `timeout`. During a detach, no new target is started in the last 15 seconds, and the targets not tried are reported with `timeout`. The policy stays attached to those targets, and the release can be retried.

## v0.2.3 (2026-10-16)

### Added
- Blocks can now ask for a dry run of the service control policy part only. That dry run skips the management account block and says why in the answer. Asking for this with engage or release is refused as invalid input.
- The answer to Blocks now includes the AWS SDK version the kill switch Lambda runs with, and whether the list of Bedrock regions came from AWS or only from the SDK because the AWS list could not be read. The kill switch logs carry the same two values.

### Changed
- Calls the kill switch makes to AWS Organizations and AWS STS now time out after 5 seconds to connect and 15 seconds to read, so a call that hangs cannot use up the time of the request.
- If the service control policy part of a request has already used up the time for the management account block, that part is reported as failed with `timeout` and is not started.

### Fixed
- The kill switch Lambda `BlocksAIControlKillSwitch` in the control account now has 512 MB of memory instead of 256 MB and uses less memory per region, so it no longer runs out of memory while it handles the management account block in every region.
- A region where the kill switch cannot set up its connection to Bedrock now reports its own error, and the other regions still run.

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

