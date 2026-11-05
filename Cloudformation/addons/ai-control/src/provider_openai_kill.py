"""One part of the BlocksAIControlProvider-OpenAI Lambda (provider_openai.py joins them): the OpenAI kill: a project spend limit of 1 cent (the lever), engage and release of projects, and what is put back. A project with spend alerts above the kill value gets its alerts brought down with the limit (provider_openai_alerts.py) and back on the release."""
# render: strip begin
from provider_common import ProviderError, log_event
from provider_openai_base import KEY_ID_RE, KILL_LIMIT, LIMIT_FIELDS, MAX_RESTORE_CHARS, MAX_TARGETS, SKIPPED_STATUSES, timed_out
from provider_openai_api import list_projects
from provider_openai_alerts import (SHAPE_ERRORS, START_SECONDS, above_kill, code_of, cover_limit, list_alerts, pending_alerts, refused_by_alert, restore_alerts, retrying,
                                    saved_amounts, step_down, time_left, valid_saved_alerts)
# render: strip end
import json
from collections import namedtuple

LeverState = namedtuple("LeverState", "engaged enforcement restore")  # at the kill value; OpenAI's enforcement status; what to put back


def limit_path(project_id):
    return f"/v1/organization/projects/{project_id}/spend_limit"


def limit_of(answer):
    return {f: answer.get(f) for f in LIMIT_FIELDS}


class SpendLimitLever:
    """The only lever: GET, POST and DELETE of /v1/organization/projects/{id}/spend_limit (D-17: one place per kill mechanism)."""

    def read(self, client, project_id):
        try:
            return client.get_json(limit_path(project_id))
        except ProviderError as e:
            if e.status == 404:  # no spend limit is set
                return None
            raise

    def state(self, client, project_id):
        current = self.read(client, project_id)
        if current is None:
            return LeverState(False, None, "null")
        limit = limit_of(current)
        return LeverState(limit == KILL_LIMIT, (current.get("enforcement") or {}).get("status"), json.dumps(limit))

    def engage(self, client, project_id):
        client.post_json(limit_path(project_id), KILL_LIMIT)

    def release(self, client, project_id, restore):
        if restore == "null":
            client.delete_json(limit_path(project_id))
        else:
            client.post_json(limit_path(project_id), json.loads(restore))


LEVERS = (SpendLimitLever(),)


def lever_state(client, project_id):
    """The state of the project over every lever: engaged only when all are; restore and enforcement come from the first lever."""
    states = [lever.state(client, project_id) for lever in LEVERS]
    return LeverState(all(s.engaged for s in states), states[0].enforcement, states[0].restore)


def valid_restore(restore):
    """"null" (no limit before), or a JSON object with exactly the three limit fields, a positive whole number of cents, and not the
    kill value itself (releasing to it would report a release that leaves the project stopped), or, for a project with spend alerts,
    {"limit": null or such an object, "alerts": {alert id: its amount before the kill}}."""
    if restore == "null":
        return True
    try:
        value = json.loads(restore)
    except ValueError:
        return False
    if isinstance(value, dict) and set(value) == {"limit", "alerts"}:
        return valid_saved_alerts(value["alerts"]) and (value["limit"] is None or valid_limit(value["limit"]))
    return valid_limit(value)


def valid_limit(limit):
    return isinstance(limit, dict) and set(limit) == set(LIMIT_FIELDS) and limit != KILL_LIMIT and valid_limit_values(limit)


def split_restore(restore):
    """(what to put back as the limit: "null" or the limit as JSON, {alert id: amount} of the alerts to put back) of a valid restore."""
    value = json.loads(restore)
    if isinstance(value, dict) and set(value) == {"limit", "alerts"}:
        return ("null" if value["limit"] is None else json.dumps(value["limit"])), value["alerts"]
    return restore, {}


def restore_text(limit_restore, saved):
    """The restore of a project with spend alerts; it must fit what the caller stores, or nothing is changed."""
    text = json.dumps({"limit": json.loads(limit_restore), "alerts": saved}, separators=(",", ":"))
    if len(text) > MAX_RESTORE_CHARS or not valid_restore(text):  # what a release would refuse to read must not be handed out
        raise ProviderError("provider_error", "the restore of the project would not fit")
    return text


def limit_is_ours(state, limit, saved):
    """The limit is the kill value; or, for a project with saved alerts, a value a kill that stopped half way left, or any limit at or below the highest saved
    alert (the alerts cannot go back above it). A limit above every saved alert stands in nobody's way and is left alone."""
    if state.engaged:
        return True
    now = json.loads(state.restore)
    amount = now.get("threshold_amount") if now else None
    return bool(saved) and type(amount) is int and now != json.loads(limit) and amount <= max(saved.values())

def valid_limit_values(limit):
    amount = limit["threshold_amount"]
    return type(amount) is int and amount > 0 and all(isinstance(limit[f], str) for f in ("currency", "interval"))


def is_project_id(value):
    return isinstance(value, str) and bool(KEY_ID_RE.fullmatch(value))


def valid_ids(ids):
    return isinstance(ids, list) and 1 <= len(ids) <= MAX_TARGETS and all(map(is_project_id, ids))


def target_ids(p):
    ids = p.get("target_ids")
    if not valid_ids(ids):
        raise ProviderError("invalid_input", f"target_ids must be 1 to {MAX_TARGETS} project ids")
    return list(dict.fromkeys(ids))


def restores_of(p, ids):
    """{project id: restore string} of the release params; an id with no valid restore is left out (it fails on its own)."""
    restore = p.get("restore")
    if not isinstance(restore, dict):
        raise ProviderError("invalid_input", "restore must map project ids to what to put back")
    return {i: r for i, r in restore.items() if i in ids and isinstance(r, str) and len(r) <= MAX_RESTORE_CHARS and valid_restore(r)}


Step = namedtuple("Step", "outcome code enforcement restore", defaults=(None, None))  # one project's result; restore: the limit an engage replaced


def engage_project(client, pid, project):
    """The Step of the kill on one project; the limit is read back, and engaged means it reads as the kill value. An engaged project
    also returns the limit it replaced (`restore`), read just before the kill: the value to put back, whatever an earlier read said."""
    if project is None:
        return Step("skipped_unknown", "invalid_input", None)
    if project["status"] in SKIPPED_STATUSES:
        return Step(SKIPPED_STATUSES[project["status"]], None, None)
    before = lever_state(client, pid)
    if before.engaged:
        return Step("already_inactive", None, before.enforcement)
    return engage_and_read_back(client, pid, before.restore)


def engage_and_read_back(client, pid, restore):
    """The Step of sending the kill and reading it back: every answer carries the limit it replaced, also a failed call or read-back
    (OpenAI may have applied a call that timed out)."""
    try:
        for lever in LEVERS:
            lever.engage(client, pid)
        after = lever_state(client, pid)
    except ProviderError as e:
        return engage_through_alerts(client, pid, restore) if refused_by_alert(e) else Step("failed", e.code, None, restore)
    return Step("engaged" if after.engaged else "failed", None if after.engaged else "provider_error", after.enforcement, restore)


def put_back(client, pid, restore):
    """The limit, then the alerts (an alert may not exceed the limit), as the restore says. True when the project reads as before the kill."""
    limit, saved = split_restore(restore)
    for lever in LEVERS:
        lever.release(client, pid, limit)
    return not lever_state(client, pid).engaged and not (saved and restore_alerts(client, pid, saved, True))


def failed_and_put_back(client, pid, step):
    """The failed Step, after the project was put back as the restore of the Step says. The restore still goes back to the caller: the product keeps the
    first one of a kill (domain/ai_control_connection_kill._keep_first_restore), so a retried engage that reads a half-done project cannot replace it."""
    try:
        undone = put_back(client, pid, step.restore)
    except (ProviderError, *SHAPE_ERRORS):
        undone = False
    if not undone:
        log_event("kill_not_undone", project_id=pid)  # a release finishes it
    return step


def engage_through_alerts(client, pid, restore):
    """The Step of a kill OpenAI refused because of the project's spend alerts: the limit and the alerts come down together (provider_openai_alerts.step_down)
    to the kill value. The answer carries the restore with the alerts' amounts. A kill that fails half way puts the project back as it was."""
    if time_left(client) < START_SECONDS:  # nothing is changed: the product tries again
        return Step("failed", "timeout", None, restore)
    try:
        listed = list_alerts(client, pid)
        alerts = above_kill(listed)
        if not alerts:
            return Step("failed", "provider_error", None, restore)
        combined = restore_text(restore, saved_amounts(listed))
    except (ProviderError, *SHAPE_ERRORS) as e:
        return Step("failed", code_of(e), None, restore)
    log_event("spend_alerts_stepped_down", project_id=pid, alerts=len(alerts))
    limit = json.loads(restore)
    amount = limit.get("threshold_amount") if limit else None
    set_limit = lambda value: retrying(lambda: client.post_json(limit_path(pid), {**KILL_LIMIT, "threshold_amount": value}))
    try:
        cover_limit(alerts, amount if type(amount) is int else None, set_limit)
        step_down(client, pid, alerts, set_limit)
        after = lever_state(client, pid)
    except (ProviderError, *SHAPE_ERRORS) as e:
        return failed_and_put_back(client, pid, Step("failed", code_of(e), None, combined))
    if after.engaged:
        return Step("engaged", None, after.enforcement, combined)
    return failed_and_put_back(client, pid, Step("failed", "provider_error", after.enforcement, combined))


def release_project(client, pid, restore):
    """The Step of the release on one project; the limit is read back, and a project that still reads as the kill value is failed."""
    if restore is None:
        return Step("failed", "invalid_input", None)
    limit, saved = split_restore(restore)
    ours = limit_is_ours(lever_state(client, pid), limit, saved)
    pending = saved and pending_alerts(client, pid, saved, ours)
    if not (ours or pending):  # someone else changed the limit and none of our alerts is left lowered: not ours to touch
        return Step("already_active", None, None)
    if ours:
        for lever in LEVERS:
            lever.release(client, pid, limit)
    left = restore_alerts(client, pid, saved, ours) if saved else 0  # after the limit: an alert may not exceed it
    after = lever_state(client, pid)
    return Step("failed", "provider_error", after.enforcement) if after.engaged or left else Step("released", None, None)


def project_result(pid, step):
    try:
        outcome, code, enforcement, restore = step()
    except ProviderError as e:
        return {"id": pid, "outcome": "failed", "code": e.code}
    if enforcement is not None:
        log_event("project_enforcement", project_id=pid, outcome=outcome, enforcement=enforcement)
    extra = {"enforcement": enforcement} if enforcement is not None else {}
    return {"id": pid, "outcome": outcome, "code": code, **extra, **({"restore": restore} if restore is not None else {})}


def run_each(ctx, ids, step_of):
    """One result per id, in order. Stops at the first 429 (that project failed, the rest are not tried) or at the deadline."""
    results, stop = [], None
    for pid in ids:
        stop = stop or timed_out(ctx)
        result = {"id": pid, "outcome": "not_attempted", "code": stop} if stop else project_result(pid, step_of(pid))
        results.append(result)
        stop = stop or ("provider_throttled" if result["code"] == "provider_throttled" else None)
    return {"results": results}


def act_engage(ctx, client, secret, p):
    ids = target_ids(p)
    by_id = {x["id"]: x for x in list_projects(client)}
    return run_each(ctx, ids, lambda pid: lambda: engage_project(client, pid, by_id.get(pid)))


def act_release(ctx, client, secret, p):
    ids = target_ids(p)
    restores = restores_of(p, ids)
    return run_each(ctx, ids, lambda pid: lambda: release_project(client, pid, restores.get(pid)))
