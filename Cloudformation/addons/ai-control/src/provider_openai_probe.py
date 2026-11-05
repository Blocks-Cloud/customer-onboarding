"""One part of the BlocksAIControlProvider-OpenAI Lambda (provider_openai.py joins them): the check that an admin key can set a project spend limit. OpenAI shows no scopes of a key, so the Lambda tries it: a write to a project that does not exist is 404 for a key that can write and 403 "Missing scopes" for a Read only key, and changes nothing.

Known assumption: a 404 means "can write" only because OpenAI checks the scope BEFORE it looks for the project (recorded on the dev org, fixtures write_probe_readonly_*). If OpenAI ever looks for the project first, a Read only key would get 404 and pass; the fixtures and the end-to-end run must be recorded again after any change on their side."""
# render: strip begin
from provider_common import ProviderError, Request
from provider_openai_base import KILL_LIMIT, MAX_TARGETS
from provider_openai_kill import limit_path
# render: strip end
import json
import re

NO_SUCH_PROJECT = "proj_doesnotexist000000000000"  # the only project the probe writes to: it does not exist, so nothing is ever changed
MAX_PROJECT_READS = MAX_TARGETS  # the spend limits of this many active projects are read at connect; the scope is the same for every project
SCOPES_RE = re.compile(r"Missing scopes?:\s*([A-Za-z0-9_.,\s]+?)(?:\.\s|\s*$)")  # OpenAI: "... Missing scopes: api.management.write. Check that ..."
SCOPE_RE = re.compile(r"[a-z][a-z0-9_]*(?:\.[a-z][a-z0-9_]*)+")


def error_text(raw):
    """The text of an OpenAI error body: error is a string for a missing scope and an object (message) for the other errors."""
    try:
        error = (json.loads(raw or b"{}") or {}).get("error")
    except (ValueError, AttributeError):
        return ""
    return str(error.get("message") if isinstance(error, dict) else error or "")


def missing_scopes(raw):
    """The scope names of a 403 "Missing scopes: a, b." answer; none when the text names none."""
    found = SCOPES_RE.search(error_text(raw) + " ")
    return SCOPE_RE.findall(found.group(1)) if found else []


def decide(status, raw, allowed, what):
    """Passes for a status in allowed. 403 is a refusal that names the scope; 401 is an invalid key. Every other answer (429, 5xx, 400, a
    surprise 200) is a retry: never a refusal and never a pass."""
    if status in allowed:
        return
    if status == 403:
        scopes = ", ".join(missing_scopes(raw)) or "not named by OpenAI"
        raise ProviderError("missing_permission", f"the admin key cannot {what}: missing scope {scopes}", 403)
    if status == 401:
        raise ProviderError("provider_auth_failed", "HTTP 401", 401)
    code = "provider_throttled" if status == 429 else "provider_error"
    raise ProviderError(code, f"HTTP {status} on the check that the admin key can {what}", status)


def answered(client, method, path, body=None):
    """(status, raw) of one call. A network failure or the deadline is raised by the client (provider_unreachable, timeout): a retry too."""
    headers = {**client.headers, **({"content-type": "application/json"} if body else {})}
    return client.send(Request(method, path, headers, json.dumps(body).encode() if body else None))


def read_limits(client, projects):
    """The spend limit of each active project (up to MAX_PROJECT_READS) is readable: 200, or 404 for a project with no limit."""
    for project in [p for p in projects if p["status"] == "active"][:MAX_PROJECT_READS]:
        decide(*answered(client, "GET", limit_path(project["id"])), {200, 404}, "read a project spend limit")


def probe_write(client):
    """The kill write and the release write on a project that does not exist: 404 on both means the key may write."""
    for method, body in (("POST", KILL_LIMIT), ("DELETE", None)):
        decide(*answered(client, method, limit_path(NO_SUCH_PROJECT), body), {404}, "write a project spend limit")


def check_limits(client, projects):
    read_limits(client, projects)
    probe_write(client)
