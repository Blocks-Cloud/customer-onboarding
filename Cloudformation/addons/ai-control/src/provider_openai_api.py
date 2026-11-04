"""One part of the BlocksAIControlProvider-OpenAI Lambda (provider_openai.py joins them): the OpenAI Admin API as the provider Lambda uses it: the HTTP client, the organization, the project and admin key lists."""
# render: strip begin
from provider_common import PinnedClient, ProviderError, Request, json_object, key_hint, raise_for_status
from provider_openai_base import HOST, KEYS_PAGE_SIZE, MAX_PAGES, WRITE_SCOPES, no_time_for_a_page
# render: strip end
import json
import os
from datetime import datetime, timezone

class OpenAIClient(PinnedClient):
    """The pinned JSON client, plus DELETE, and OpenAI's own code for a window older than it keeps data."""

    def call(self, request, on_404="provider_error"):
        status, raw = self.send(request)
        if status == 400 and error_field(raw, "code") == "reporting_lookback_exceeded":
            raise ProviderError("invalid_input", "OpenAI keeps usage and cost data for one year", status)
        raise_for_status(status, on_404, raw)
        return json_object(raw)

    def delete_json(self, path):
        return self.call(Request("DELETE", path, self.headers, None))


def error_field(raw, name):
    """One field of an OpenAI error body (error.code, error.type), or "" for a body of another shape."""
    try:
        return str(((json.loads(raw or b"{}") or {}).get("error") or {}).get(name) or "")
    except (ValueError, AttributeError):
        return ""


def openai(admin_key, deadline=None):
    version = os.environ.get("TEMPLATE_VERSION", "")
    return OpenAIClient(HOST, {"authorization": f"Bearer {admin_key}", "accept": "application/json",
                               "user-agent": f"BlocksAIControl/{version} (https://blocks.cloud)"}, deadline)


def organization(client):
    """The organization of the admin key. OpenAI answers every call made with the key with `openai-organization`: the name of the
    organization the key belongs to. /v1/me lists every organization of the key's OWNER (and marks the owner's default one, which can be
    another), so the id comes from the entry of that list with the same name, never from the default. A 403 on the first call is a
    project or service key on an admin endpoint ("Missing scopes: api.management.read")."""
    try:
        client.get_json("/v1/organization/projects", [("limit", 1)])
        named = client.response_headers.get("openai-organization")
        me = client.get_json("/v1/me")
    except ProviderError as e:
        if e.status == 403:
            raise ProviderError("invalid_format", "this is not an admin key", 403) from None
        raise
    if not named:
        raise ProviderError("provider_error", "OpenAI did not say which organization the key belongs to")
    return named_org(me, named)


def named_org(me, named):
    """{org_id, org_name} of the one organization in the /v1/me answer with this name."""
    orgs = [o for o in (me.get("orgs") or {}).get("data") or [] if isinstance(o, dict) and o.get("id") and o.get("name") == named]
    if len(orgs) != 1:
        raise ProviderError("provider_error", "the organization of the key is not in the list of its owner")
    return {"org_id": str(orgs[0]["id"]), "org_name": str(orgs[0]["name"])}


def listed(client, path, parse_item):
    """Every item of a paged OpenAI list (limit, after, has_more, last_id)."""
    items, after = [], None
    for _ in range(MAX_PAGES):
        page = client.get_json(path, [("limit", KEYS_PAGE_SIZE)] + ([("after", after)] if after else []))
        data = [d for d in page.get("data", []) if isinstance(d, dict)]
        items += [parse_item(d) for d in data]
        after = page.get("last_id") or (data[-1].get("id") if data else None)
        if not page.get("has_more") or not after:
            return items
    raise ProviderError("provider_error", "too many items to list")


def project_of(p):
    return {"id": p.get("id"), "name": p.get("name"), "status": p.get("status")}


def list_projects(client):
    return listed(client, "/v1/organization/projects", project_of)


def list_admin_keys(client):
    return listed(client, "/v1/organization/admin_api_keys", lambda k: k)


def count_active(projects):
    return sum(1 for p in projects if p["status"] == "active")


def active_keys_after_save(client):
    """Best effort, after the key is saved: a failure only leaves the count out."""
    try:
        return count_active(list_projects(client))
    except ProviderError:
        return None


def own_key(keys, admin_key):
    """The listed admin key that is the stored credential: its redacted value ends with the same last 4 characters and starts with
    the same characters as far as it shows them (the part before the first "*")."""
    return next((k for k in keys if redacted_matches(str(k.get("redacted_value") or ""), admin_key)), None)


def redacted_matches(redacted, admin_key):
    return redacted.endswith(key_hint(admin_key)) and admin_key.startswith(redacted.split("*", 1)[0])


def rfc3339(seconds):
    return datetime.fromtimestamp(seconds, timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ")


def own_key_expiry(keys, admin_key):
    """(found, expires_at) for the stored credential in the key list. expires_at is an RFC 3339 UTC string, or None for a key that never
    expires. A key that is not listed, or has an expiry that is not a Unix time, is not found (unknown, never "never expires")."""
    own = own_key(keys, admin_key)
    if own is None:
        return False, None
    expires = own.get("expires_at")
    if expires is None:
        return True, None
    if isinstance(expires, bool) or not isinstance(expires, (int, float)):
        return False, None
    return True, rfc3339(expires)


def only_reads(scopes):
    """True for a key that lists its scopes and has no write scope among them."""
    return isinstance(scopes, list) and bool(scopes) and not set(scopes) & set(WRITE_SCOPES)


def require_write_scope(keys, admin_key):
    """A key that lists its scopes and has no write scope cannot set a spend limit: refused when it is connected, not when it is needed."""
    scopes = (own_key(keys, admin_key) or {}).get("scopes")
    if only_reads(scopes):
        raise ProviderError("missing_permission", "the admin key can only read: it needs write access to set a project spend limit")

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

