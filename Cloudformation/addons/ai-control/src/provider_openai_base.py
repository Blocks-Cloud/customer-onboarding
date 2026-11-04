"""One part of the BlocksAIControlProvider-OpenAI Lambda (provider_openai.py joins them): constants and the small helpers shared by the OpenAI provider Lambda's modules (time, page and deadline checks)."""
# render: strip begin
from provider_common import ProviderError, READ_TIMEOUT
# render: strip end
import re
import time
from collections import namedtuple
from datetime import timedelta

HOST = "api.openai.com"
ADMIN_KEY_RE = re.compile(r"^sk-admin-[A-Za-z0-9_-]{20,300}$")  # an organization admin key; a project or service account key is refused
SECRET_PREFIX = "blocks/ai-control/openai/"
KILL_LIMIT = {"threshold_amount": 1, "currency": "USD", "interval": "month"}  # the kill: a project spend limit of 1 cent
LIMIT_FIELDS = tuple(KILL_LIMIT)
WRITE_SCOPES = ("api.all.write", "api.management.write")  # an admin key that lists its scopes needs one of these to set a spend limit
KEYS_PAGE_SIZE = 100
COST_PAGE_SIZE = 31
SKIPPED_STATUSES = {"archived": "skipped_archived"}
USAGE_BUCKETS = {"1m": (timedelta(hours=24), 1440), "1h": (timedelta(days=7), 168)}  # bucket_width: (longest window, buckets per request)
# OpenAI usage endpoints and the group_by each one allows (sent as repeated group_by parameters); the order is the order of reading.
BY_KEY = ("project_id", "api_key_id", "model")
SURFACES = (("completions", BY_KEY + ("batch", "service_tier")), ("embeddings", BY_KEY), ("moderations", BY_KEY), ("audio_speeches", BY_KEY),
            ("audio_transcriptions", BY_KEY), ("images", BY_KEY + ("size", "source")), ("web_search_calls", BY_KEY),
            ("file_search_calls", ("project_id", "api_key_id")), ("code_interpreter_sessions", ("project_id",)))
# Blocks field -> OpenAI field, per surface. OpenAI reports text, cached text, audio and image input as separate counts that add up to
# input_tokens, so nothing is subtracted.
SURFACE_FIELDS = {
    "completions": {"uncached_input_tokens": "input_text_tokens", "cache_read_input_tokens": "input_cached_text_tokens", "output_tokens": "output_text_tokens",
                    "input_audio_tokens": "input_audio_tokens", "cache_read_audio_tokens": "input_cached_audio_tokens", "input_image_tokens": "input_image_tokens",
                    "cache_read_image_tokens": "input_cached_image_tokens", "cache_write_tokens": "input_cache_write_tokens",
                    "output_audio_tokens": "output_audio_tokens", "output_image_tokens": "output_image_tokens"},
    "embeddings": {"uncached_input_tokens": "input_tokens"}, "moderations": {"uncached_input_tokens": "input_tokens"},
    "audio_speeches": {"characters": "characters"}, "audio_transcriptions": {"audio_seconds": "seconds"}, "images": {"images": "images"},
    "web_search_calls": {"web_search_requests": "num_requests"}, "file_search_calls": {"requests": "num_requests"},
    "code_interpreter_sessions": {"sessions": "num_sessions"}}
USAGE_FIELDS = ("uncached_input_tokens", "cache_read_input_tokens", "output_tokens", "web_search_requests", "input_audio_tokens", "input_image_tokens",
                "cache_read_audio_tokens", "cache_read_image_tokens", "cache_write_tokens", "output_audio_tokens", "output_image_tokens", "characters",
                "audio_seconds", "images", "requests", "sessions")
PARAMS = {"test": (), "read_keys": (), "delete_credential": (), "read_usage": ("start", "end", "bucket_width", "page"), "read_cost": ("start_day", "end_day", "page"),
          "engage": ("target_ids",), "release": ("target_ids", "restore"), "info": ()}
MAX_RESTORE_CHARS = 200
CLEANUP_TYPE = "Custom::BlocksAIControlOpenAIProviderSecretsCleanup"
CLEANUP_ID = "BlocksAIControlOpenAIProviderSecretsCleanup"
CLEANUP_LOGICAL_ID = "OpenAIProviderSecretsCleanup"


CONNECTION_RE = re.compile(r"^[A-Za-z0-9_-]{1,64}$")


KEY_ID_RE = re.compile(r"^[A-Za-z0-9_-]{1,64}$")


MAX_TARGETS = 50


INTAKE_QUALIFIER = ":intake"  # the alias API Gateway calls; store_credential runs only there and nothing else does


INTAKE_DEADLINE_SECONDS = 20


MAX_BODY_BYTES = 2048


MAX_PAGE_CHARS = 512


MAX_TOKEN_SECONDS = 600


STORE_SCOPE = "ai-control:store-key"


MAX_PAGES = 20


RECOVERY_DAYS = 7


DEADLINE_MARGIN_SECONDS = 10


TOP_LEVEL = {"schema_version", "action", "params", "request_id", "connection_id"}


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


def no_time_for_a_page(deadline):
    return bool(deadline) and deadline - time.monotonic() < READ_TIMEOUT


def timed_out(ctx):
    return "timeout" if time.monotonic() > ctx.deadline else None


class Context:
    def __init__(self, lambda_ctx):
        remaining = lambda_ctx.get_remaining_time_in_millis() / 1000
        self.deadline = time.monotonic() + remaining - DEADLINE_MARGIN_SECONDS
        self.account = lambda_ctx.invoked_function_arn.split(":")[4]
        self.via_intake_alias = lambda_ctx.invoked_function_arn.endswith(INTAKE_QUALIFIER)
