"""Shared pieces of the Blocks AI Control provider Lambdas: envelope, error codes, pinned-host HTTP, redaction.

scripts/render_provider_lambdas.py inlines this file and the provider file into the template. Python standard library only.
"""
import http.client
import json
import logging
import re
import socket
import ssl
import time
import urllib.parse
from collections import namedtuple

SCHEMA_VERSION = "1"
CONNECT_TIMEOUT = 5
READ_TIMEOUT = 15
MAX_RESPONSE_BYTES = 8_000_000
DETAIL_MAX = 400  # an error detail: "HTTP 400 invalid_request_error: " plus a provider message cut at PROVIDER_TEXT_MAX
PROVIDER_TEXT_MAX = 300
SECRET_RE = re.compile(r"sk-ant-[A-Za-z0-9_-]+")
STATUS_CODES = {"invalid_input": 400, "invalid_format": 400, "token_expired": 401, "provider_auth_failed": 422, "missing_permission": 422,
                "org_mismatch": 409, "provider_unreachable": 502, "provider_throttled": 429, "provider_error": 502, "secret_missing": 404,
                "timeout": 504}

log = logging.getLogger("blocks.ai_control.provider")
log.setLevel(logging.INFO)


class ProviderError(Exception):
    """An error with one of the contract codes. The detail is short and never holds a secret."""

    def __init__(self, code, detail="", status=None, message=""):
        super().__init__(code)
        self.code, self.detail, self.status, self.message = code, redact(str(detail))[:DETAIL_MAX], status, redact(str(message))[:200]
        self.checks = []  # store_credential: the checks that ran before this error


def redact(text):
    """Anything shaped like an Anthropic key becomes ***."""
    return SECRET_RE.sub("***", text)


def key_hint(secret):
    """The last 4 characters: the only part of a key that is ever logged or returned."""
    return secret[-4:]


def log_event(event, _level=logging.INFO, **fields):
    log.log(_level, redact(json.dumps({"event": event, **fields}, default=str)))


def ok(result):
    return {"schema_version": SCHEMA_VERSION, "ok": True, "result": result}


def fail(code, detail="", result=None):
    out = {"schema_version": SCHEMA_VERSION, "ok": False, "error": code, "detail": redact(str(detail))[:DETAIL_MAX]}
    if result is not None:
        out["result"] = result
    return out


def http_response(envelope):
    """The API Gateway answer for an envelope. CORS headers come from the API itself."""
    status = 200 if envelope["ok"] else STATUS_CODES.get(envelope["error"], 502)
    return {"statusCode": status, "headers": {"content-type": "application/json", "cache-control": "no-store"}, "body": json.dumps(envelope)}


Request = namedtuple("Request", "method path headers body")  # path: with the query string; body: bytes or None


def https_request(host, request, timeouts=(CONNECT_TIMEOUT, READ_TIMEOUT)):
    """One HTTPS request to a host fixed in code. timeouts: (connect, read) seconds. Returns (status, headers, body bytes); any network
    failure is provider_unreachable."""
    connect_timeout, read_timeout = timeouts
    conn = http.client.HTTPSConnection(host, timeout=connect_timeout, context=ssl.create_default_context())
    try:
        conn.connect()
        conn.sock.settimeout(read_timeout)
        conn.request(request.method, request.path, body=request.body, headers=request.headers)
        resp = conn.getresponse()
        data = resp.read(MAX_RESPONSE_BYTES + 1)
        if len(data) > MAX_RESPONSE_BYTES:
            raise ProviderError("provider_error", "response too large")
        return resp.status, dict(resp.getheaders()), data
    except socket.timeout:
        raise ProviderError("provider_unreachable", "timeout") from None
    except (OSError, http.client.HTTPException, ssl.SSLError) as e:
        raise ProviderError("provider_unreachable", type(e).__name__) from None
    finally:
        conn.close()


def json_object(raw):
    """The answer body as a JSON object; anything else is provider_error."""
    try:
        parsed = json.loads(raw or b"{}")
    except ValueError:
        raise ProviderError("provider_error", "the answer is not JSON") from None
    if not isinstance(parsed, dict):
        raise ProviderError("provider_error", "the answer is not a JSON object")
    return parsed


class PinnedClient:
    """JSON client for one host that only the code names, never the request. deadline: a time.monotonic() value that caps the
    whole conversation; each call's timeouts shrink to what is left, and no call starts after it."""

    def __init__(self, host, headers, deadline=None):
        self.host, self.headers, self.deadline = host, headers, deadline

    def get_json(self, path, query=None, extra_headers=None, on_404="provider_error"):
        full = path + ("?" + urllib.parse.urlencode(query) if query else "")
        return self.call(Request("GET", full, {**self.headers, **(extra_headers or {})}, None), on_404)

    def post_json(self, path, body, on_404="provider_error"):
        headers = {**self.headers, "content-type": "application/json"}
        return self.call(Request("POST", path, headers, json.dumps(body).encode()), on_404)

    def call(self, request, on_404="provider_error"):
        status, raw = self.send(request)
        raise_for_status(status, on_404, raw)
        return json_object(raw)

    def timeouts(self):
        """(connect, read): the fixed timeouts, cut to the time left before the deadline."""
        if self.deadline is None:
            return CONNECT_TIMEOUT, READ_TIMEOUT
        left = self.deadline - time.monotonic()
        if left <= 0:
            raise ProviderError("timeout", "the time for this request is used up")
        return min(CONNECT_TIMEOUT, left), min(READ_TIMEOUT, left)

    def send(self, request):
        timeouts = self.timeouts()
        try:
            status, _, raw = https_request(self.host, request, timeouts)
        except ProviderError as e:
            if self.cut_by_deadline(e):
                raise ProviderError("timeout", "the time for this request ran out") from None
            raise
        return status, raw

    def cut_by_deadline(self, e):
        """A socket timeout at the deadline is our time running out, not the provider being unreachable."""
        if (e.code, e.detail) != ("provider_unreachable", "timeout") or not self.deadline:
            return False
        return time.monotonic() >= self.deadline - 0.05


def error_message(raw):
    """The message of an Anthropic error body, for the caller's decisions only (redacted, short)."""
    try:
        return str(((json.loads(raw or b"{}") or {}).get("error") or {}).get("message") or "")
    except (ValueError, AttributeError):
        return ""


def error_detail(status, raw):
    """"HTTP 400 invalid_request_error: <message>" from an Anthropic error body: only error.type and error.message, redacted first,
    whitespace collapsed, cut at PROVIDER_TEXT_MAX. A body that is not that shape gives "HTTP 400"."""
    try:
        error = (json.loads(raw or b"{}") or {}).get("error") or {}
        kind, message = error.get("type"), error.get("message")
        text = f"{kind}: {message}" if kind and message else str(kind or message or "")
    except (ValueError, AttributeError):
        return f"HTTP {status}"
    text = " ".join(redact(text).split())[:PROVIDER_TEXT_MAX]
    return f"HTTP {status} {text}" if text else f"HTTP {status}"


def raise_for_status(status, on_404="provider_error", raw=b""):
    """Only a 4xx with no code of its own gets Anthropic's text (error_detail). 401, 403, 404 and 429 keep a plain "HTTP <n>", also a
    404 that maps to provider_error (the default on_404): the code already says what went wrong."""
    if 200 <= status < 300:
        return
    code = {401: "provider_auth_failed", 403: "missing_permission", 404: on_404, 429: "provider_throttled"}.get(status)
    detail = error_detail(status, raw) if code is None and 400 <= status < 500 else f"HTTP {status}"
    raise ProviderError(code or "provider_error", detail, status, error_message(raw))
