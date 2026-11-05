"""BlocksAIControlProvider-OpenAI: the Blocks AI Control Lambda for OpenAI in the control account.

Two ways in. The key intake HTTP API calls store_credential with the OpenAI admin key (Blocks never sees it). Blocks calls every other action
through BlocksAIControlInvokeRole. The admin key lives only in Secrets Manager; the log and every answer carry its last 4 characters at most.

The kill is one lever: a project spend limit of 1 cent (LEVERS). A kill target is a project. OpenAI refuses a hard limit below any spend alert of the
project, so a project that has one also has its spend alerts brought down to 1 cent for the kill (provider_openai_alerts.py) and put back, amount by amount,
on the release. Connect and test try a spend limit write on a project that does not exist (provider_openai_probe.py), which changes nothing. Nothing else of a project is ever changed: no model permissions, no rate limits, no key scopes, no key delete and no project archive.
"""
# render: strip begin
from provider_common import ProviderError, SCHEMA_VERSION, fail, http_response, key_hint, log_event, ok, redact
from provider_openai_base import ADMIN_KEY_RE, CLEANUP_ID, CLEANUP_LOGICAL_ID, CLEANUP_TYPE, CONNECTION_RE, Context, INTAKE_DEADLINE_SECONDS, MAX_BODY_BYTES, MAX_TOKEN_SECONDS, PARAMS, RECOVERY_DAYS, SECRET_PREFIX, STORE_SCOPE, SURFACES, TOP_LEVEL
from provider_openai_api import active_keys_after_save, count_active, list_admin_keys, list_projects, openai, organization, own_key_expiry
from provider_openai_kill import act_engage, act_release
from provider_openai_probe import check_limits
from provider_openai_reads import act_read_cost, act_read_keys, act_read_usage
# render: strip end
import base64
import json
import logging
import os
import re
import time
import urllib.parse
import urllib.request

def cloudformation_client():
    import boto3
    from botocore.config import Config
    return boto3.client("cloudformation", config=Config(connect_timeout=5, read_timeout=15, retries={"mode": "standard", "max_attempts": 3}))


def secrets_client():
    import boto3
    from botocore.config import Config
    return boto3.client("secretsmanager", config=Config(connect_timeout=5, read_timeout=15, retries={"mode": "standard", "max_attempts": 3}))


def secret_name(connection_id):
    return f"blocks/ai-control/openai/{connection_id}"


def aws_code(e):
    return getattr(e, "response", {}).get("Error", {}).get("Code", "")


def aws_error(e):
    """The AWS error code, else the exception class: what the log and an answer may say about a failure."""
    return aws_code(e) or type(e).__name__


def error_code(e):
    return e.code if isinstance(e, ProviderError) else aws_error(e)


def secrets_manager_error(e):
    return ProviderError("provider_error", f"secrets manager: {aws_error(e)}")


UNREADABLE_SECRET_CODES = ("ResourceNotFoundException", "InvalidRequestException",  # not there, or scheduled for deletion
                           "DecryptionFailure", "KMSInvalidStateException", "KMSDisabledException", "KMSNotFoundException")  # its key is gone or off


def load_secret(sm, connection_id):
    try:
        return json.loads(sm.get_secret_value(SecretId=secret_name(connection_id))["SecretString"])
    except Exception as e:
        if aws_code(e) in UNREADABLE_SECRET_CODES:  # the connection has no usable key: Blocks asks for it again, and add can create it
            raise ProviderError("secret_missing", "no credential stored for this connection") from None
        raise secrets_manager_error(e) from None


def described(sm, name):
    """describe_secret, or None when there is no such secret."""
    try:
        return sm.describe_secret(SecretId=name)
    except Exception as e:
        if aws_code(e) != "ResourceNotFoundException":
            raise
        return None


def write_secret(sm, name, text):
    state = described(sm, name)
    if state is None:
        sm.create_secret(Name=name, SecretString=text, KmsKeyId=os.environ["PROVIDER_KEYS_KEY_ARN"], Tags=[{"Key": "OwnedBy", "Value": "Blocks.cloud"}])
        return
    if state.get("DeletedDate"):
        sm.restore_secret(SecretId=name)
    sm.update_secret(SecretId=name, SecretString=text, KmsKeyId=os.environ["PROVIDER_KEYS_KEY_ARN"])


def save_secret(sm, connection_id, value):
    """Create on the first add, else a new version (update_secret, so the current KMS key is used). The previous version stays as AWSPREVIOUS."""
    try:
        write_secret(sm, secret_name(connection_id), json.dumps(value))
    except Exception as e:
        raise secrets_manager_error(e) from None


def claim_int(claims, name):
    value = str(claims.get(name, ""))
    if not (value.isascii() and value.isdigit()):
        raise ProviderError("invalid_input", f"the token needs a numeric {name}")
    return int(value)


def jwt_claims(event):
    try:
        claims = event["requestContext"]["authorizer"]["jwt"]["claims"]
    except (KeyError, TypeError):
        raise ProviderError("invalid_input", "no token claims") from None
    if not isinstance(claims, dict):
        raise ProviderError("invalid_input", "the token audience is not this control account")
    return claims


def from_environment(claims, name, variable):
    """The claim equals a configured value; an unset value matches nothing."""
    expected = os.environ.get(variable)
    return bool(expected) and claims.get(name) == expected


def audience_ok(claims, account):
    return str(claims.get("aud", "")) == account


def issuer_ok(claims, account):
    return from_environment(claims, "iss", "INTAKE_ISSUER")


def customer_ok(claims, account):
    return from_environment(claims, "sub", "CUSTOMER_ID")


def scope_ok(claims, account):
    return STORE_SCOPE in re.split(r"[\s,\[\]]+", str(claims.get("scope", "")))


def connection_ok(claims, account):
    return valid_connection_id(claims.get("connection_id", ""))


def valid_connection_id(value):
    return bool(CONNECTION_RE.fullmatch(str(value)))


IDENTITY_CHECKS = ((audience_ok, "the token audience is not this control account"), (issuer_ok, "the token issuer is not the Blocks intake issuer"),
                   (customer_ok, "the token is not for this customer"))


def require(checks, claims, account):
    for check, message in checks:
        if not check(claims, account):
            raise ProviderError("invalid_input", message)


def check_lifetime(claims):
    iat, exp, now = claim_int(claims, "iat"), claim_int(claims, "exp"), time.time()
    if exp < now:
        raise ProviderError("token_expired", "the intake token has expired")
    if exp - iat > MAX_TOKEN_SECONDS or iat > now + 60:
        raise ProviderError("invalid_input", "the token lifetime is not allowed")


def claims_of(event, account):
    """The JWT claims. The API checked the signature, issuer, audience and scope; this checks them again (defence in depth), plus the
    lifetime, the customer and what the token is for."""
    claims = jwt_claims(event)
    require(IDENTITY_CHECKS, claims, account)
    check_lifetime(claims)
    require(PURPOSE_CHECKS, claims, account)
    return claims


def request_body(event):
    raw = event.get("body") or ""
    if not isinstance(raw, str) or len(raw.encode()) > MAX_BODY_BYTES:
        raise ProviderError("invalid_input", "the body is too large")
    try:
        return json.loads(base64.b64decode(raw) if event.get("isBase64Encoded") else raw)
    except ValueError:
        raise ProviderError("invalid_input", "the body is not JSON") from None


def is_admin_key_body(body):
    if not isinstance(body, dict) or set(body) != {"admin_key"}:
        return False
    return isinstance(body["admin_key"], str)


def admin_key_of(event):
    body = request_body(event)
    if not is_admin_key_body(body):
        raise ProviderError("invalid_input", "the body must be exactly {admin_key}")
    return body["admin_key"]


def record(checks, name, code=None):
    checks.append({"name": name, "ok": code is None, "code": code})


def checked(checks, name, step):
    """Runs one check and records it, passed or failed."""
    try:
        value = step()
    except ProviderError as e:
        record(checks, name, e.code)
        raise
    record(checks, name)
    return value


def secret_state(sm, connection_id):
    """None when there is no secret, "deleted" when it is scheduled for deletion, else "active"."""
    try:
        state = described(sm, secret_name(connection_id))
    except Exception as e:
        raise secrets_manager_error(e) from None
    if state is None:
        return None
    return "deleted" if state.get("DeletedDate") else "active"


def readable(sm, connection_id):
    """True when the stored key can be read. A secret nobody can decrypt any more does not count."""
    try:
        load_secret(sm, connection_id)
    except ProviderError as e:
        if e.code != "secret_missing":
            raise
        return False
    return True


def refuse_a_live_key(sm, connection_id):
    """add creates the secret and never overwrites a key that still works."""
    if secret_state(sm, connection_id) == "active" and readable(sm, connection_id):
        raise ProviderError("invalid_input", "This connection already has a key. Use replace.")


def check_same_org(sm, connection_id, org, checks):
    stored = load_secret(sm, connection_id)
    match = stored.get("org_id") == org["org_id"]
    checks.append({"name": "org_match", "ok": match, "code": None if match else "org_mismatch"})
    if not match:
        raise ProviderError("org_mismatch", "the new key belongs to a different organization")


def verify_key(admin_key, claims, sm, deadline):
    """The checks of a new key, plus the same organization for replace. A failure carries the checks that ran."""
    checks = []
    try:
        org, client = run_checks(admin_key, checks, deadline)
        if claims["mode"] == "replace":
            check_same_org(sm, claims["connection_id"], org, checks)
    except ProviderError as e:
        e.checks = checks
        raise
    return org, client, checks


def store_credential(event, account, sm):
    """add creates the connection's secret (never overwrites a live one); replace needs the secret and the same organization."""
    claims = claims_of(event, account)
    connection_id, mode = claims["connection_id"], claims["mode"]
    deadline = time.monotonic() + INTAKE_DEADLINE_SECONDS
    admin_key = admin_key_of(event)
    if mode == "add":
        refuse_a_live_key(sm, connection_id)
    org, client, checks = verify_key(admin_key, claims, sm, deadline)
    # `admin_key` = the stored OpenAI admin key; the field name is the wire contract
    save_secret(sm, connection_id, {"admin_key": admin_key, "org_id": org["org_id"]})
    active = active_keys_after_save(client)
    log_event("store_credential", connection_id=connection_id, mode=mode, key_hint=key_hint(admin_key), active_keys=active)
    counted = {} if active is None else {"active_keys": active}
    return {"checks": checks, **org, "key_hint": key_hint(admin_key), **counted}


def check_envelope(event):
    if not isinstance(event, dict):
        raise ProviderError("invalid_input", "the request must be a JSON object")
    version = event.get("schema_version")
    if version != SCHEMA_VERSION:
        raise ProviderError("invalid_input", f"unsupported schema_version {version!r}")
    if set(event) - TOP_LEVEL:
        raise ProviderError("invalid_input", "unknown request field")  # includes any attempt to name a host


def check_action(action, params):
    if not isinstance(action, str) or action not in PARAMS:
        raise ProviderError("invalid_input", f"unknown action {action!r}")
    if not isinstance(params, dict) or set(params) - set(PARAMS[action]):
        raise ProviderError("invalid_input", "unknown or malformed params")


def parse(event):
    check_envelope(event)
    action, params = event.get("action"), event.get("params") or {}
    check_action(action, params)
    connection_id = event.get("connection_id")
    if not connection_given(action, connection_id):
        raise ProviderError("invalid_input", "connection_id is required")
    return action, params, connection_id


def connection_given(action, connection_id):
    """Every action but info names a connection."""
    if action == "info":
        return True
    return valid_connection_id(connection_id or "")


def delete_credential(sm, connection_id):
    try:
        sm.delete_secret(SecretId=secret_name(connection_id), RecoveryWindowInDays=RECOVERY_DAYS)
    except Exception as e:
        if aws_code(e) != "ResourceNotFoundException":
            raise secrets_manager_error(e) from None
    return {"deleted": True}


def invoke_action(event, context):
    action, params, connection_id = parse(event)
    if action == "info":
        return {"intake_url": os.environ.get("INTAKE_URL", ""), "template_version": os.environ.get("TEMPLATE_VERSION", "")}
    sm = secrets_client()
    if action == "delete_credential":
        return delete_credential(sm, connection_id)
    secret = load_secret(sm, connection_id)
    return ACTIONS[action](context, openai(secret["admin_key"], context.deadline), secret, params)


def is_http_event(event):
    return isinstance(event, dict) and "requestContext" in event


RESPONSE_HOST_RE = re.compile(r"cloudformation-custom-resource-response-[a-z0-9-]+\.s3(?:\.[a-z0-9-]+)?\.amazonaws\.com")


def is_cfn_event(event):
    return isinstance(event, dict) and "RequestType" in event and "ResponseURL" in event


def cfn_event_ok(event):
    """Only a CloudFormation request for this stack's cleanup resource, answered to a presigned CloudFormation response bucket URL."""
    url = urllib.parse.urlparse(str(event.get("ResponseURL")))
    stack_id = os.environ.get("STACK_ID")
    return (url.scheme == "https" and bool(RESPONSE_HOST_RE.fullmatch(url.hostname or "")) and event.get("ResourceType") == CLEANUP_TYPE
            and bool(stack_id) and event.get("StackId") == stack_id and event.get("RequestType") in ("Create", "Update", "Delete"))


def cfn_put(url, body):
    request = urllib.request.Request(url, data=body, method="PUT", headers={"content-type": "", "content-length": str(len(body))})
    urllib.request.urlopen(request, timeout=10).read()  # noqa: S310 - https only, checked in cfn_event_ok


def cfn_respond(event, status, reason=""):
    """The cfn-response protocol: always answer, or the stack waits an hour."""
    body = json.dumps({"Status": status, "Reason": redact(reason)[:500] or "see the log", "PhysicalResourceId": event.get("PhysicalResourceId") or CLEANUP_ID,
                       "StackId": event.get("StackId"), "RequestId": event.get("RequestId"), "LogicalResourceId": event.get("LogicalResourceId"), "Data": {}})
    try:
        cfn_put(event["ResponseURL"], body.encode())
    except Exception as e:  # nothing else can be done: the stack times out
        log_event("cfn_response_failed", exception=type(e).__name__)


def is_live_provider_secret(entry):
    return entry["Name"].startswith(SECRET_PREFIX) and not entry.get("DeletedDate")


def provider_secret_names(sm):
    """Every live provider secret, all pages."""
    token, names = None, []
    while True:
        page = sm.list_secrets(Filters=[{"Key": "name", "Values": [SECRET_PREFIX]}], **({"NextToken": token} if token else {}))
        names += [x["Name"] for x in page.get("SecretList", []) if is_live_provider_secret(x)]
        token = page.get("NextToken")
        if not token:
            return names


def deleted_in_time(sm, name, deadline):
    """Schedules one secret for deletion; False when the time is gone or the delete fails (one secret must not stop the others)."""
    if time.monotonic() > deadline:
        return False
    try:
        sm.delete_secret(SecretId=name, RecoveryWindowInDays=RECOVERY_DAYS)
    except Exception as e:
        log_event("secret_delete_failed", logging.WARNING, name=name, code=aws_error(e))
        return False
    return True


def cleanup_secrets(sm, deadline):
    """Schedules every live provider secret for deletion with the same recovery window as delete_credential: the stack that held the KMS
    key is going away. The names are listed first and deleted after, so deleting does not disturb the paging. Returns (count, names left)."""
    names = provider_secret_names(sm)
    left = [name for name in names if not deleted_in_time(sm, name, deadline)]
    return len(names) - len(left), left


def stack_is_deleting():
    """True only when CloudFormation says the cleanup resource of this stack is being deleted: a forged event cannot make it so."""
    try:
        detail = cloudformation_client().describe_stack_resource(StackName=os.environ["STACK_ID"], LogicalResourceId=CLEANUP_LOGICAL_ID)["StackResourceDetail"]
        return detail.get("ResourceStatus") == "DELETE_IN_PROGRESS"
    except Exception as e:
        log_event("stack_status_unreadable", logging.WARNING, code=aws_error(e))
        return False


def delete_provider_secrets(context):
    if time.monotonic() > context.deadline:
        raise ProviderError("timeout", "no time left")
    deleted, left = cleanup_secrets(secrets_client(), context.deadline)
    log_event("secrets_cleanup", deleted=deleted, left=len(left))
    if left:
        log_event("secrets_left_behind", logging.ERROR, names=left)


def cleanup_on_delete(context):
    """The Delete request: "refused" unless CloudFormation confirms the delete. Never raises: a cleanup that fails is an ERROR log line."""
    try:
        if not stack_is_deleting():
            log_event("cleanup_refused_not_deleting", logging.WARNING)
            return "refused"
        delete_provider_secrets(context)
    except Exception as e:
        log_event("secrets_cleanup_failed", logging.ERROR, code=error_code(e))
    return "Delete"


def handle_cfn_event(event, context):
    """CloudFormation custom resource: Delete removes the provider secrets, Create and Update do nothing. A cleanup that fails never
    fails the Delete (the stack would stay in DELETE_FAILED): it logs an ERROR with the names left, which the KMS key delete makes unreadable."""
    try:
        outcome = cleanup_on_delete(context) if event["RequestType"] == "Delete" else event["RequestType"]
        cfn_respond(event, "SUCCESS")
        return ok({"cleanup": outcome})
    except Exception as e:  # always answer CloudFormation, with a short reason and no secret
        code = error_code(e)
        cfn_respond(event, "FAILED", f"custom resource failed: {code}")
        return fail("provider_error", str(code))


def cfn_route(event, context):
    if context.via_intake_alias or not cfn_event_ok(event):
        raise ProviderError("invalid_input", "this is not a CloudFormation request for this account")
    return handle_cfn_event(event, context)


def route(event, context, http):
    """(envelope, answered): answered is true for a CloudFormation event, which has had its answer and its log lines already."""
    if is_cfn_event(event):
        return cfn_route(event, context), True
    if http != context.via_intake_alias:  # intake alias: API Gateway events only
        raise ProviderError("invalid_input", "this request does not belong on this entry point")
    if http:
        return ok(store_credential(event, context.account, secrets_client())), False
    return ok(invoke_action(event, context)), False


def envelope_of(event, lambda_ctx, http, action):
    try:
        return route(event, Context(lambda_ctx), http)
    except ProviderError as e:
        return fail(e.code, e.detail, {"checks": e.checks} if e.checks else None), False
    except Exception as e:  # nothing may escape: an exception text could hold the key
        log_event("unhandled", action=action, exception=type(e).__name__)
        return fail("provider_error", "internal error"), False


def request_labels(event, http):
    """(action, request_id) for the log line."""
    if http:
        return "store_credential", ""
    body = event if isinstance(event, dict) else {}
    return str(body.get("action")), str(body.get("request_id") or "")[:128]


def handler(event, lambda_ctx):
    started, http = time.monotonic(), is_http_event(event)
    action, request_id = request_labels(event, http)
    envelope, answered = envelope_of(event, lambda_ctx, http, action)
    if answered:
        return envelope
    log_event("done", action=action, request_id=request_id, ok=envelope["ok"], error=envelope.get("error"), detail=None if envelope["ok"] else envelope.get("detail"), duration_ms=int((time.monotonic() - started) * 1000))
    return http_response(envelope) if http else envelope


def purpose_ok(claims, account):
    return claims.get("provider") == "openai" and claims.get("mode") in ("add", "replace")


PURPOSE_CHECKS = ((scope_ok, "the token is not for storing a key"), (purpose_ok, "the token is not for adding an OpenAI key"),
                  (connection_ok, "bad connection id"))


def usage_probe(client):
    end = int(time.time())
    query = [("start_time", end - 3600), ("end_time", end), ("bucket_width", "1h"), ("limit", 1)] + [("group_by", g) for g in SURFACES[0][1]]
    return client.get_json("/v1/organization/usage/completions", query, on_404="missing_permission")


def can_read_limits(client):
    """The key can list the projects and admin keys, read every project's spend limit, and write one (tried on a project that does not exist)."""
    projects = list_projects(client)
    list_admin_keys(client)
    check_limits(client, projects)


def run_checks(admin_key, checks, deadline):
    """Appends one entry per check that ran; stops at the first that fails. Returns the organization and the client."""
    if not ADMIN_KEY_RE.fullmatch(admin_key):
        record(checks, "format", "invalid_format")
        raise ProviderError("invalid_format", "this is not an OpenAI admin key")
    record(checks, "format")
    client = openai(admin_key, deadline)
    org = checked(checks, "organization", lambda: organization(client))
    checked(checks, "api_keys", lambda: can_read_limits(client))
    checked(checks, "usage", lambda: usage_probe(client))
    return org, client


def act_test(ctx, client, secret, p):
    org = organization(client)
    if org["org_id"] != secret.get("org_id"):
        raise ProviderError("org_mismatch", "the stored key now belongs to a different organization")
    keys, projects = list_admin_keys(client), list_projects(client)
    check_limits(client, projects)
    found, expires_at = own_key_expiry(keys, secret["admin_key"])
    active = count_active(projects)
    return {**org, "key_hint": key_hint(secret["admin_key"]), "active_keys": active, **({"key_expires_at": expires_at} if found else {})}


ACTIONS = {"test": act_test, "read_keys": act_read_keys, "read_usage": act_read_usage, "read_cost": act_read_cost, "engage": act_engage,
           "release": act_release}
