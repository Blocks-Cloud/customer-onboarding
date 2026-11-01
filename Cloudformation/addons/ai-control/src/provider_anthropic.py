"""BlocksAIControlProvider-Anthropic: the Blocks AI Control Lambda for Anthropic in the control account.

Two ways in. The key intake HTTP API calls store_credential with the admin key (Blocks never sees it). Blocks calls every other action
through BlocksAIControlInvokeRole. The admin key lives only in Secrets Manager; the log and every answer carry its last 4 characters at most.
"""
# render: strip begin
from provider_common import PinnedClient, ProviderError, READ_TIMEOUT, SCHEMA_VERSION, fail, http_response, key_hint, log_event, ok, redact
# render: strip end
import base64
import json
import logging
import os
import re
import time
import urllib.parse
import urllib.request
from collections import namedtuple
from datetime import date, datetime, timedelta, timezone

HOST = "api.anthropic.com"
ANTHROPIC_VERSION = "2023-06-01"
COST_BETA = "analytics-usage-cost-2026-08-24"
ADMIN_KEY_RE = re.compile(r"^sk-ant-admin[0-9]{2}-[A-Za-z0-9_-]{20,300}$")
CONNECTION_RE = re.compile(r"^[A-Za-z0-9_-]{1,64}$")
KEY_ID_RE = re.compile(r"^[A-Za-z0-9_-]{1,64}$")
MAX_TARGETS = 50
INTAKE_QUALIFIER = ":intake"  # the alias API Gateway calls; store_credential runs only there and nothing else does
INTAKE_DEADLINE_SECONDS = 20
MAX_BODY_BYTES = 2048
MAX_PAGE_CHARS = 512
USAGE_BUCKETS = {"1m": (timedelta(hours=24), 1440), "1h": (timedelta(days=7), 168)}  # bucket_width: (longest window, buckets per request)
MAX_TOKEN_SECONDS = 600
STORE_SCOPE = "ai-control:store-key"
ANALYTICS_FIRST_DAY = date(2026, 1, 1)
ANALYTICS_MAX_DAYS = 365
SKIPPED_STATUSES = {"archived": "skipped_archived", "expired": "skipped_expired"}
MAX_PAGES = 20
KEYS_PAGE_SIZE = 1000
RECOVERY_DAYS = 7
DEADLINE_MARGIN_SECONDS = 10
USAGE_GROUP_BY = ("api_key_id", "workspace_id", "model", "service_tier", "context_window", "inference_geo")
COST_GROUP_BY = ("model", "api_key_id", "workspace_id", "service_tier", "context_window", "cost_type", "token_type")
LEGACY_COST_GROUP_BY = ("workspace_id", "description")
COST_FIELDS = ("model", "api_key_id", "workspace_id", "service_tier", "context_window", "cost_type", "token_type")
PARAMS = {"test": (), "read_keys": (), "delete_credential": (), "read_usage": ("start", "end", "bucket_width", "page"), "read_cost": ("start_day", "end_day", "page"),
          "engage": ("target_ids",), "release": ("target_ids",), "info": ()}
TOP_LEVEL = {"schema_version", "action", "params", "request_id", "connection_id"}


def cloudformation_client():
    import boto3
    from botocore.config import Config
    return boto3.client("cloudformation", config=Config(connect_timeout=5, read_timeout=15, retries={"mode": "standard", "max_attempts": 3}))


def secrets_client():
    import boto3
    from botocore.config import Config
    return boto3.client("secretsmanager", config=Config(connect_timeout=5, read_timeout=15, retries={"mode": "standard", "max_attempts": 3}))


def secret_name(connection_id):
    return f"blocks/ai-control/anthropic/{connection_id}"


def aws_code(e):
    return getattr(e, "response", {}).get("Error", {}).get("Code", "")


def aws_error(e):
    """The AWS error code, else the exception class: what the log and an answer may say about a failure."""
    return aws_code(e) or type(e).__name__


def error_code(e):
    return e.code if isinstance(e, ProviderError) else aws_error(e)


def secrets_manager_error(e):
    return ProviderError("provider_error", f"secrets manager: {aws_error(e)}")


# ---- the stored admin key -------------------------------------------------------------------------------------------

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


def anthropic(admin_key, deadline=None):
    version = os.environ.get("TEMPLATE_VERSION", "")
    return PinnedClient(HOST, {"x-api-key": admin_key, "anthropic-version": ANTHROPIC_VERSION, "accept": "application/json",
                               "user-agent": f"BlocksAIControl/{version} (https://blocks.cloud)"}, deadline)


# ---- Anthropic Admin API ----------------------------------------------------------------------------------------------

def organization(client):
    me = client.get_json("/v1/organizations/me")
    return {"org_id": str(me.get("id", "")), "org_name": str(me.get("name", ""))}


def key_of(k):
    """A key as Blocks reads it. The workspace is in scope.workspace_id."""
    scope = k.get("scope") or {}
    return {"id": k.get("id"), "name": k.get("name"), "partial_key_hint": k.get("partial_key_hint"), "status": k.get("status"),
            "workspace_id": scope.get("workspace_id", k.get("workspace_id")), "scope_type": scope.get("type"), "expires_at": k.get("expires_at"),
            "created_at": k.get("created_at")}


def list_keys(client, status=None):
    keys, after = [], None
    for _ in range(MAX_PAGES):
        query = {"limit": KEYS_PAGE_SIZE, **({"status": status} if status else {}), **({"after_id": after} if after else {})}
        page = client.get_json("/v1/organizations/api_keys", query, on_404="missing_permission")
        keys += [key_of(k) for k in page.get("data", [])]
        after = page.get("last_id")
        if not page.get("has_more") or not after:
            return keys
    raise ProviderError("provider_error", "too many API keys to list")


def count_active(keys):
    return sum(1 for k in keys if k["status"] == "active")


# ---- store_credential (key intake) -------------------------------------------------------------------------------------

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


def purpose_ok(claims, account):
    return claims.get("provider") == "anthropic" and claims.get("mode") in ("add", "replace")


def connection_ok(claims, account):
    return valid_connection_id(claims.get("connection_id", ""))


def valid_connection_id(value):
    return bool(CONNECTION_RE.fullmatch(str(value)))


# In this order: who the token is from and for, then (after its lifetime) what it is for.
IDENTITY_CHECKS = ((audience_ok, "the token audience is not this control account"), (issuer_ok, "the token issuer is not the Blocks intake issuer"),
                   (customer_ok, "the token is not for this customer"))
PURPOSE_CHECKS = ((scope_ok, "the token is not for storing a key"), (purpose_ok, "the token is not for adding an Anthropic key"),
                  (connection_ok, "bad connection id"))


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


def run_checks(admin_key, checks, deadline):
    """Appends one entry per check that ran; stops at the first that fails. Returns the organization and the client."""
    if not ADMIN_KEY_RE.fullmatch(admin_key):
        record(checks, "format", "invalid_format")
        raise ProviderError("invalid_format", "this is not an Anthropic admin key")
    record(checks, "format")
    client = anthropic(admin_key, deadline)
    hour_end = datetime.now(timezone.utc).replace(microsecond=0)
    usage = [("starting_at", stamp(hour_end - timedelta(hours=1))), ("ending_at", stamp(hour_end)), ("bucket_width", "1h"), ("limit", 1)]
    org = checked(checks, "organization", lambda: organization(client))
    checked(checks, "api_keys", lambda: client.get_json("/v1/organizations/api_keys", [("limit", 1)], on_404="missing_permission"))
    checked(checks, "usage", lambda: client.get_json("/v1/organizations/usage_report/messages", usage, on_404="missing_permission"))
    return org, client


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


def active_keys_after_save(client):
    """Best effort, after the key is saved: a failure only leaves the count out."""
    try:
        return count_active(list_keys(client))
    except ProviderError:
        return None


def store_credential(event, account, sm):
    """add creates the connection's secret (never overwrites a live one); replace needs the secret and the same organization."""
    claims = claims_of(event, account)
    connection_id, mode = claims["connection_id"], claims["mode"]
    deadline = time.monotonic() + INTAKE_DEADLINE_SECONDS
    admin_key = admin_key_of(event)
    if mode == "add":
        refuse_a_live_key(sm, connection_id)
    org, client, checks = verify_key(admin_key, claims, sm, deadline)
    save_secret(sm, connection_id, {"admin_key": admin_key, "org_id": org["org_id"]})
    active = active_keys_after_save(client)
    log_event("store_credential", connection_id=connection_id, mode=mode, key_hint=key_hint(admin_key), active_keys=active)
    counted = {} if active is None else {"active_keys": active}
    return {"checks": checks, **org, "key_hint": key_hint(admin_key), **counted}


# ---- actions for Blocks ---------------------------------------------------------------------------------------------------

def act_test(ctx, client, secret, p):
    org = organization(client)
    if org["org_id"] != secret.get("org_id"):
        raise ProviderError("org_mismatch", "the stored key now belongs to a different organization")
    return {**org, "key_hint": key_hint(secret["admin_key"]), "active_keys": count_active(list_keys(client))}


def act_read_keys(ctx, client, secret, p):
    keys = list_keys(client)
    self_key_id = next((k["id"] for k in keys if is_self(k, secret["admin_key"])), None)
    return {"keys": keys, "self_hint": key_hint(secret["admin_key"]), "self_key_id": self_key_id}


def iso(value, name):
    try:
        d = datetime.fromisoformat(str(value))
    except ValueError:
        raise ProviderError("invalid_input", f"{name} is not an ISO time") from None
    if d.tzinfo is None:
        raise ProviderError("invalid_input", f"{name} needs a time zone")
    return d.astimezone(timezone.utc)


def day(value, name):
    try:
        return datetime.strptime(str(value), "%Y-%m-%d").replace(tzinfo=timezone.utc)
    except ValueError:
        raise ProviderError("invalid_input", f"{name} is not a YYYY-MM-DD day") from None


def is_control(c):
    return ord(c) < 32 or ord(c) == 127


def valid_page(page):
    if not isinstance(page, str) or not 1 <= len(page) <= MAX_PAGE_CHARS:
        return False
    return not any(map(is_control, page))


def page_of(p):
    """The opaque next_page of an earlier answer: a short string without control characters."""
    if "page" not in p:
        return None
    page = p["page"]
    if not valid_page(page):
        raise ProviderError("invalid_input", "page must be the next_page of an earlier answer")
    return page


def stamp(d):
    return d.strftime("%Y-%m-%dT%H:%M:%SZ")


Listing = namedtuple("Listing", "path query headers", defaults=(None,))  # a paged GET: path, query pairs, extra headers


def paged(client, listing, page=None):
    """(items, next_page, last answer, truncated): follows next_page until it ends. When the page cap or the client's deadline stops it
    first, next_page is still returned and truncated is true."""
    items, answer = [], {}
    for _ in range(MAX_PAGES):
        answer = client.get_json(listing.path, list(listing.query) + ([("page", page)] if page else []), listing.headers)
        items += answer.get("data", [])
        page = answer.get("next_page") if answer.get("has_more") else None
        if not page:
            return items, None, answer, False
        if no_time_for_a_page(client.deadline):
            break
    return items, page, answer, True


def no_time_for_a_page(deadline):
    return bool(deadline) and deadline - time.monotonic() < READ_TIMEOUT


def usage_query(start, end, width):
    if width not in USAGE_BUCKETS:
        raise ProviderError("invalid_input", "bucket_width must be 1m or 1h")
    longest, per_request = USAGE_BUCKETS[width]
    if not start < end <= start + longest:
        raise ProviderError("invalid_input", f"the window must be longer than 0 and at most {longest.total_seconds() / 3600:g} hours for {width} buckets")
    return [("starting_at", stamp(start)), ("ending_at", stamp(end)), ("bucket_width", width), ("limit", per_request)] + [("group_by[]", g) for g in USAGE_GROUP_BY]


def usage_row(b, r):
    cache, tools = r.get("cache_creation") or {}, r.get("server_tool_use") or {}
    return {"starting_at": b.get("starting_at"), "ending_at": b.get("ending_at"), **{g: r.get(g) for g in USAGE_GROUP_BY},
            "uncached_input_tokens": r.get("uncached_input_tokens", 0), "cache_read_input_tokens": r.get("cache_read_input_tokens", 0),
            "cache_creation_5m_tokens": cache.get("ephemeral_5m_input_tokens", 0), "cache_creation_1h_tokens": cache.get("ephemeral_1h_input_tokens", 0),
            "output_tokens": r.get("output_tokens", 0), "web_search_requests": tools.get("web_search_requests", 0)}


def act_read_usage(ctx, client, secret, p):
    start, end, page = iso(p.get("start"), "start"), iso(p.get("end"), "end"), page_of(p)
    query = usage_query(start, end, p.get("bucket_width", "1m"))
    buckets, next_page, _, truncated = paged(client, Listing("/v1/organizations/usage_report/messages", query), page)
    return {"rows": [usage_row(b, r) for b in buckets for r in b.get("results", [])], "next_page": next_page, "truncated": truncated}


def cost_rows(buckets):
    """Legacy cost_report: buckets with results. Amounts stay the raw strings (cents). Blocks divides by 100, once, in one place."""
    return [{"day": str(b.get("starting_at", ""))[:10], **{f: r.get(f) for f in COST_FIELDS}, "amount_cents": r.get("amount"),
             "list_amount_cents": r.get("list_amount")} for b in buckets for r in b.get("results", [])]


def analytics_rows(rows):
    """Analytics cost: one row per group and day, with the dimensions in group and the amounts in cost (cents, raw strings)."""
    return [{"day": str(r.get("starting_at", ""))[:10], **{f: (r.get("group") or {}).get(f) for f in COST_FIELDS},
             "amount_cents": (r.get("cost") or {}).get("amount"), "list_amount_cents": (r.get("cost") or {}).get("list_amount")} for r in rows]


def analytics_window_ok(start):
    """The Analytics API serves days from 2026-01-01 and at most 365 days back."""
    today = datetime.now(timezone.utc).date()
    return start.date() >= ANALYTICS_FIRST_DAY and (today - start.date()).days <= ANALYTICS_MAX_DAYS


BETA_UNAVAILABLE_RE = re.compile(r"^(?:the\s+)?(?:analytics|this (?:beta|endpoint|feature))\b[^.]*\bnot (?:yet )?(?:available|enabled)", re.I)
RETIRED_BETA_RE = re.compile(r"^unexpected value\(s\)[^.]*\bfor the [`'\"]?anthropic-beta[`'\"]? header", re.I)


def analytics_unavailable(e):
    """The beta endpoint is not there for this organization: a 404, or a 400 that says the feature (not our query) is not available or enabled,
    or that the anthropic-beta value we send is no longer accepted (retired). A 400 about any other header or field is an error."""
    return e.status == 404 or (e.status == 400 and bool(BETA_UNAVAILABLE_RE.search(e.message) or RETIRED_BETA_RE.search(e.message)))


def analytics_cost(client, window, page):
    """(answer, None), or (None, the reason for the legacy fallback) when the beta endpoint is not there for this organization."""
    query = window + [("time_bucket_width", "1d"), ("limit", 1000), ("order_by", "time")] + [("group_by[]", g) for g in COST_GROUP_BY]
    try:
        rows, next_page, last, truncated = paged(client, Listing("/v1/organizations/analytics/cost", query, {"anthropic-beta": COST_BETA}), page)
    except ProviderError as e:
        if not analytics_unavailable(e):  # any other error, including a 400 about our own request, is an error and not a silent fallback
            raise
        return None, str(e.status)
    return {"rows": analytics_rows(rows), "next_page": next_page, "truncated": truncated, "data_refreshed_at": last.get("data_refreshed_at"),
            "source": "analytics"}, None


def legacy_cost(client, window, page, reason):
    query = window + [("bucket_width", "1d"), ("limit", 31)] + [("group_by[]", g) for g in LEGACY_COST_GROUP_BY]
    buckets, next_page, _, truncated = paged(client, Listing("/v1/organizations/cost_report", query), page)
    return {"rows": cost_rows(buckets), "next_page": next_page, "truncated": truncated, "data_refreshed_at": None, "source": f"legacy_fallback:{reason}"}


def act_read_cost(ctx, client, secret, p):
    start, end = day(p.get("start_day"), "start_day"), day(p.get("end_day"), "end_day")
    if not start < end <= start + timedelta(days=31):
        raise ProviderError("invalid_input", "the days must span 1 to 31 days")
    window, page = [("starting_at", stamp(start)), ("ending_at", stamp(end))], page_of(p)
    if not analytics_window_ok(start):
        return legacy_cost(client, window, page, "window")
    answer, reason = analytics_cost(client, window, page)
    return answer or legacy_cost(client, window, page, reason)


def is_key_id(value):
    return isinstance(value, str) and bool(KEY_ID_RE.fullmatch(value))


def valid_target_ids(ids):
    if not isinstance(ids, list) or not 1 <= len(ids) <= MAX_TARGETS:
        return False
    return all(map(is_key_id, ids))


def target_ids(p):
    ids = p.get("target_ids")
    if not valid_target_ids(ids):
        raise ProviderError("invalid_input", f"target_ids must be 1 to {MAX_TARGETS} API key ids")
    return list(dict.fromkeys(ids))


Change = namedtuple("Change", "want done same self_key")  # the status to set, the outcome when set, when already so, the stored admin key whose own listing is skipped


def is_self(key, self_key):
    """The listed key is the stored credential: same last four, and the visible start (before the ellipsis) is a prefix of it."""
    if not self_key:
        return False
    hint = str(key["partial_key_hint"] or "")
    shown = re.match(r"(.*?)(?:\.{3}|\u2026)(.*)$", hint, re.S)
    if not shown:
        return hint.endswith(key_hint(self_key))
    return shown[2].endswith(key_hint(self_key)) and self_key.startswith(shown[1])


def skip_reason(key, change):
    """(outcome, code) when the key is left alone, else (None, None)."""
    if key is None:
        return "skipped_unknown", "invalid_input"
    if is_self(key, change.self_key):
        return "skipped_self", None
    if key["status"] in SKIPPED_STATUSES:
        return SKIPPED_STATUSES[key["status"]], None
    if key["status"] == change.want:
        return change.same, None
    return None, None


def update_key(client, kid, change):
    try:
        client.post_json(f"/v1/organizations/api_keys/{kid}", {"status": change.want})
    except ProviderError as e:
        return {"id": kid, "outcome": "failed", "code": e.code}
    return {"id": kid, "outcome": change.done, "code": None}


def key_result(client, kid, key, change):
    outcome, code = skip_reason(key, change)
    if outcome:
        return {"id": kid, "outcome": outcome, "code": code}
    return update_key(client, kid, change)


def timed_out(ctx):
    return "timeout" if time.monotonic() > ctx.deadline else None


def set_status(ctx, client, ids, change):
    """Changes the listed keys only. Stops at the first 429 (that key failed, the rest are not tried) or at the deadline."""
    by_id = {k["id"]: k for k in list_keys(client)}
    results, stop = [], None
    for kid in ids:
        stop = stop or timed_out(ctx)
        result = {"id": kid, "outcome": "not_attempted", "code": stop} if stop else key_result(client, kid, by_id.get(kid), change)
        results.append(result)
        stop = stop or ("provider_throttled" if result["code"] == "provider_throttled" else None)
    return {"results": results}


def act_engage(ctx, client, secret, p):
    return set_status(ctx, client, target_ids(p), Change("inactive", "engaged", "already_inactive", secret["admin_key"]))


def act_release(ctx, client, secret, p):
    return set_status(ctx, client, target_ids(p), Change("active", "released", "already_active", None))


ACTIONS = {"test": act_test, "read_keys": act_read_keys, "read_usage": act_read_usage, "read_cost": act_read_cost, "engage": act_engage,
           "release": act_release}


class Context:
    def __init__(self, lambda_ctx):
        remaining = lambda_ctx.get_remaining_time_in_millis() / 1000
        self.deadline = time.monotonic() + remaining - DEADLINE_MARGIN_SECONDS
        self.account = lambda_ctx.invoked_function_arn.split(":")[4]
        self.via_intake_alias = lambda_ctx.invoked_function_arn.endswith(INTAKE_QUALIFIER)


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
    return ACTIONS[action](context, anthropic(secret["admin_key"], context.deadline), secret, params)


def is_http_event(event):
    return isinstance(event, dict) and "requestContext" in event


CLEANUP_TYPE = "Custom::BlocksAIControlProviderSecretsCleanup"
CLEANUP_ID = "BlocksAIControlProviderSecretsCleanup"
CLEANUP_LOGICAL_ID = "ProviderSecretsCleanup"
RESPONSE_HOST_RE = re.compile(r"cloudformation-custom-resource-response-[a-z0-9-]+\.s3(?:\.[a-z0-9-]+)?\.amazonaws\.com")
SECRET_PREFIX = "blocks/ai-control/anthropic/"


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
    log_event("done", action=action, request_id=request_id, ok=envelope["ok"], error=envelope.get("error"), duration_ms=int((time.monotonic() - started) * 1000))
    return http_response(envelope) if http else envelope
