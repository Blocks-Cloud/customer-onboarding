"""One part of the BlocksAIControlProvider-OpenAI Lambda (provider_openai.py joins them): the spend alerts of a project. OpenAI refuses a hard spend limit below any spend alert of the project (400), so the kill of a project that has one first brings its alerts down with the limit, and the release puts them back."""
# render: strip begin
from provider_common import ProviderError, log_event
from provider_openai_base import KEY_ID_RE, KILL_LIMIT
from provider_openai_api import listed
# render: strip end
import json
import time

KILL_AMOUNT = KILL_LIMIT["threshold_amount"]
ALERT_FIELDS = ("threshold_amount", "currency", "interval", "notification_channel")  # OpenAI wants every field of the alert in each change
# How far an alert falls at a time, the biggest step first. OpenAI refuses an alert far below the limit ("too small relative to the current monthly budget"):
# with the limit at 200000, 200000 -> 1 was refused 10 of 10 times, but 20 (1/10,000 of the limit) was accepted, and so were 2000, 1000, 400 and 200; 1333 (not an
# exact fraction) was refused. So a $2,000 alert takes two rounds (200000 -> 20 -> 1); the smaller steps are for amounts OpenAI cannot store exactly.
RATIOS = (10000, 100, 10, 2)
MAX_ROUNDS = 40  # enough to halve any amount down to 1 (the time left stops a step down long before this)
RETRY_TRIES = 4
RETRY_PAUSE = 0.5  # seconds between tries of a change OpenAI says raced with another one
MAX_SAVED_ALERTS = 5  # the restore of a project is at most MAX_RESTORE_CHARS: more alerts than this cannot be put back from it
ID_CHARS = 8  # a restore keeps this many characters of an alert id (real ids have 24): 5 alerts and a limit then fit in 200 characters
START_SECONDS = 30  # time needed to start a step down: it took 7 s for one alert, and a put back after a failure needs time too
ROUND_SECONDS = 15  # time that must be left to begin another round, so a failure can still be put back
SHAPE_ERRORS = (KeyError, TypeError, ValueError, AttributeError)  # an answer of an unexpected shape: that project fails, the batch goes on


def time_left(client):
    """Seconds before the Lambda deadline the client works to (a lot when it has none)."""
    return 1e9 if client.deadline is None else client.deadline - time.monotonic()


def alerts_path(project_id):
    return f"/v1/organization/projects/{project_id}/spend_alerts"


def list_alerts(client, project_id):
    try:
        return listed(client, alerts_path(project_id), lambda a: a)
    except SHAPE_ERRORS:
        raise ProviderError("provider_error", "OpenAI answered with spend alerts of an unexpected shape")


def above_kill(alerts):
    """{alert id: alert} of the alerts above the kill value: the ones that stop the kill and must be brought down."""
    return {a["id"]: a for a in alerts if isinstance(a.get("id"), str) and type(a.get("threshold_amount")) is int and a["threshold_amount"] > KILL_AMOUNT}


def key_of(alert_id):
    return alert_id[:ID_CHARS]


def code_of(e):
    """The code of a ProviderError; an answer of an unexpected shape (SHAPE_ERRORS) is a provider_error."""
    return getattr(e, "code", "provider_error")


def saved_amounts(alerts):
    """{key of the id: amount} of the alerts above the kill value. Two alerts whose ids start alike cannot be told apart in a restore: raises."""
    keys = [key_of(a["id"]) for a in alerts if isinstance(a.get("id"), str)]
    if len(set(keys)) != len(keys):
        raise ProviderError("provider_error", "two spend alerts of the project have ids that start alike")
    return {key_of(i): a["threshold_amount"] for i, a in above_kill(alerts).items()}


def message_of(e):
    return (e.message or "").lower() if e.status == 400 else ""


def refused_by_alert(e):
    """OpenAI refused the limit because of an alert of the project (hard_spend_limit_below_spend_alert)."""
    return "spend alert" in message_of(e)


def is_race(e):
    return "please retry" in message_of(e) or "changed while updating" in message_of(e)


def is_too_small(e):
    return "too small" in message_of(e)


def retrying(change):
    """The answer of `change()`, tried again when OpenAI says it raced with another change (a limit and an alert are changed one after the other)."""
    for attempt in range(RETRY_TRIES):
        try:
            return change()
        except ProviderError as e:
            if not is_race(e) or attempt == RETRY_TRIES - 1:
                raise
            time.sleep(RETRY_PAUSE)


def set_alert(client, project_id, alert, amount):
    if not all(f in alert for f in ALERT_FIELDS):
        raise ProviderError("provider_error", "a spend alert came without all its fields")
    alert_id = alert["id"]
    body = {**{f: alert[f] for f in ALERT_FIELDS}, "threshold_amount": amount}
    return retrying(lambda: client.post_json(f"{alerts_path(project_id)}/{alert_id}", body))


def lower_alert(client, project_id, alert, amount):
    """The alert brought down one step; returns its new amount. A step OpenAI finds too small is tried again with a smaller one."""
    for ratio in RATIOS:
        new = max(KILL_AMOUNT, amount // ratio)
        try:
            set_alert(client, project_id, alert, new)
            return new
        except ProviderError as e:
            if not is_too_small(e):
                raise
    raise ProviderError("provider_error", "OpenAI refused every step down of a spend alert")


def cover_limit(alerts, limit_amount, set_limit):
    """The project limit at the highest alert when it is above it or not there: the alerts may not exceed it, and a limit above them lets them come down."""
    top = max(a["threshold_amount"] for a in alerts.values())
    if limit_amount is None or limit_amount > top:
        set_limit(top)


def lower_round(client, project_id, alerts, now):
    for alert_id in [i for i, v in now.items() if v > KILL_AMOUNT]:
        now[alert_id] = lower_alert(client, project_id, alerts[alert_id], now[alert_id])


def step_down(client, project_id, alerts, set_limit):
    """Every alert (id -> alert) down to the kill value and the project limit with it, so the limit never sits below an alert: each round lowers the
    alerts, then the limit to the highest of them. The last round sets the kill value itself. Raises ProviderError."""
    now = {i: a["threshold_amount"] for i, a in alerts.items()}
    for _ in range(MAX_ROUNDS):
        if max(now.values()) <= KILL_AMOUNT:
            return
        if time_left(client) < ROUND_SECONDS:
            raise ProviderError("timeout", "no time left for another round of the step down")
        lower_round(client, project_id, alerts, now)
        set_limit(max(now.values()))
    raise ProviderError("provider_error", "a spend alert did not reach the kill value")


def pending_alerts(client, project_id, saved, ours):
    """{key: alert} of the saved alerts to put back: the ones at the kill value and, when the limit was ours (`ours`), any one below its saved amount (a kill
    that stopped half way leaves them part of the way down). With a limit of the customer's, an alert between is theirs. One the customer deleted is skipped."""
    now = {}
    for a in list_alerts(client, project_id):
        now.setdefault(key_of(a["id"]) if isinstance(a.get("id"), str) else None, []).append(a)
    found = {key: now.get(key, []) for key in saved}
    amount = lambda key: found[key][0].get("threshold_amount") if len(found[key]) == 1 else None  # a key two alerts share is not touched
    return {key: found[key][0] for key, was in saved.items() if type(amount(key)) is int and (amount(key) == KILL_AMOUNT or (ours and amount(key) < was))}


def restore_alerts(client, project_id, saved, ours):
    """Puts the saved alerts back (the limit must already be released: an alert may not exceed it); returns how many are still to put back."""
    for key, alert in pending_alerts(client, project_id, saved, ours).items():
        set_alert(client, project_id, alert, saved[key])
    left = pending_alerts(client, project_id, saved, ours)
    if left:
        log_event("spend_alert_not_restored", project_id=project_id, alerts=len(left))
    return len(left)


def valid_saved_alerts(saved):
    """{key of an alert id: amount above the kill value}, 1 to MAX_SAVED_ALERTS of them."""
    return (isinstance(saved, dict) and 1 <= len(saved) <= MAX_SAVED_ALERTS and all(
        isinstance(i, str) and len(i) == ID_CHARS and KEY_ID_RE.fullmatch(i) and type(v) is int and v > KILL_AMOUNT for i, v in saved.items()))
