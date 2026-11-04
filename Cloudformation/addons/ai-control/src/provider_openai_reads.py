"""One part of the BlocksAIControlProvider-OpenAI Lambda (provider_openai.py joins them): what Blocks reads from OpenAI through the provider Lambda: keys and projects, usage, and cost."""
# render: strip begin
from provider_common import ProviderError
from provider_openai_base import COST_PAGE_SIZE, Listing, SURFACES, SURFACE_FIELDS, USAGE_BUCKETS, USAGE_FIELDS, no_time_for_a_page, page_of, valid_page
from provider_openai_api import list_projects, paged, rfc3339
from provider_openai_kill import lever_state
# render: strip end
import json
from datetime import datetime, timedelta, timezone
from decimal import Decimal, InvalidOperation

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


def target_of(client, project):
    """A project as a kill target: status archived, inactive (at the kill value) or active; restore is what to put back on release."""
    if project["status"] == "archived":
        return {**project, "restore": "null"}
    state = lever_state(client, project["id"])
    return {**project, "status": "inactive" if state.engaged else "active", "restore": state.restore}


def act_read_keys(ctx, client, secret, p):
    keys = [{"id": t["id"], "name": t["name"], "status": t["status"], "workspace_id": t["id"], "partial_key_hint": None, "restore": t["restore"]}
            for t in (target_of(client, project) for project in list_projects(client))]
    return {"keys": keys, "self_hint": None, "self_key_id": None}


def at(seconds):
    return rfc3339(seconds) if isinstance(seconds, (int, float)) and not isinstance(seconds, bool) else None


def usage_query(start, end, width, surface):
    if width not in USAGE_BUCKETS:
        raise ProviderError("invalid_input", "bucket_width must be 1m or 1h")
    longest, per_request = USAGE_BUCKETS[width]
    if not start < end <= start + longest:
        raise ProviderError("invalid_input", f"the window must be longer than 0 and at most {longest.total_seconds() / 3600:g} hours for {width} buckets")
    groups = dict(SURFACES)[surface]
    return [("start_time", int(start.timestamp())), ("end_time", int(end.timestamp())), ("bucket_width", width), ("limit", per_request)] + [("group_by", g) for g in groups]


def usage_row(bucket, surface, r):
    fields = SURFACE_FIELDS[surface]
    return {"starting_at": at(bucket.get("start_time")), "ending_at": at(bucket.get("end_time")), "workspace_id": r.get("project_id"),
            "api_key_id": r.get("api_key_id"), "model": r.get("model"), "service_tier": r.get("service_tier"), "batch": r.get("batch"), "surface": surface,
            **{f: (r.get(fields[f]) or 0) if f in fields else 0 for f in USAGE_FIELDS}}


def cursor_of(p):
    """(index of the surface to read, OpenAI page of it) from the next_page of an earlier answer."""
    page = page_of(p)
    if page is None:
        return 0, None
    try:
        cursor = json.loads(page)
    except ValueError:
        cursor = None
    if not valid_cursor(cursor):
        raise ProviderError("invalid_input", "page must be the next_page of an earlier answer")
    return cursor["s"], cursor["p"]


def valid_cursor(cursor):
    if not isinstance(cursor, dict) or set(cursor) != {"s", "p"}:
        return False
    index, inner = cursor["s"], cursor["p"]
    return type(index) is int and 0 <= index < len(SURFACES) and (inner is None or valid_page(inner))


def cursor_page(index, inner):
    return json.dumps({"s": index, "p": inner}, separators=(",", ":"))


def act_read_usage(ctx, client, secret, p):
    start, end = iso(p.get("start"), "start"), iso(p.get("end"), "end")
    width, (index, page) = p.get("bucket_width", "1m"), cursor_of(p)
    rows = []
    for i in range(index, len(SURFACES)):
        surface = SURFACES[i][0]
        if i > index and no_time_for_a_page(client.deadline):
            return {"rows": rows, "next_page": cursor_page(i, None), "truncated": True}
        buckets, next_page, _, truncated = paged(client, Listing(f"/v1/organization/usage/{surface}", usage_query(start, end, width, surface)), page if i == index else None)
        rows += [usage_row(b, surface, r) for b in buckets for r in b.get("results", [])]
        if truncated:
            return {"rows": rows, "next_page": cursor_page(i, next_page), "truncated": True}
    return {"rows": rows, "next_page": None, "truncated": False}


def cents(amount):
    """OpenAI's dollars as Blocks' cents, a plain decimal string ("0.0012" is "0.12")."""
    try:
        return format((Decimal(str(amount)) * 100).normalize(), "f")
    except InvalidOperation:
        raise ProviderError("provider_error", "a cost amount is not a number") from None


def require_usd(amount):
    currency = str((amount or {}).get("currency") or "usd")
    if currency.lower() != "usd":
        raise ProviderError("provider_error", "a cost amount is not in USD")


def line_item_parts(r):
    """(model, token type) of a cost line item "gpt-5-nano, input"; None for a part that is empty."""
    model, _, token_type = str(r.get("line_item") or "").partition(", ")
    return model or None, token_type or None


def day_of(bucket):
    return str(at(bucket.get("start_time")) or "")[:10]


def amount_cents(r):
    return cents((r.get("amount") or {}).get("value", 0))


def cost_row(bucket, r):
    require_usd(r.get("amount"))
    model, token_type = line_item_parts(r)
    return {"day": day_of(bucket), "model": model, "token_type": token_type, "workspace_id": r.get("project_id"),
            "api_key_id": None, "service_tier": None, "context_window": None, "cost_type": "usage",
            "amount_cents": amount_cents(r), "list_amount_cents": None}


def act_read_cost(ctx, client, secret, p):
    start, end = day(p.get("start_day"), "start_day"), day(p.get("end_day"), "end_day")
    if not start < end <= start + timedelta(days=31):
        raise ProviderError("invalid_input", "the days must span 1 to 31 days")
    query = [("start_time", int(start.timestamp())), ("end_time", int(end.timestamp())), ("bucket_width", "1d"), ("limit", COST_PAGE_SIZE),
             ("group_by", "project_id"), ("group_by", "line_item")]
    buckets, next_page, _, truncated = paged(client, Listing("/v1/organization/costs", query), page_of(p))
    return {"rows": [cost_row(b, r) for b in buckets for r in b.get("results", [])], "next_page": next_page, "truncated": truncated,
            "data_refreshed_at": None, "source": "costs"}
