"""One part of the BlocksAIControlProvider-OpenAI Lambda (provider_openai.py joins them): the OpenAI kill: a project spend limit of 1 cent (the lever), engage and release of projects, and what is put back."""
# render: strip begin
from provider_common import ProviderError, log_event
from provider_openai_base import KEY_ID_RE, KILL_LIMIT, LIMIT_FIELDS, MAX_RESTORE_CHARS, MAX_TARGETS, SKIPPED_STATUSES, timed_out
from provider_openai_api import list_projects
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
    """"null" (no limit before) or a JSON object with exactly the three limit fields, a positive whole number of cents, and not the
    kill value itself (releasing to it would report a release that leaves the project stopped)."""
    if restore == "null":
        return True
    try:
        limit = json.loads(restore)
    except ValueError:
        return False
    return isinstance(limit, dict) and set(limit) == set(LIMIT_FIELDS) and limit != KILL_LIMIT and valid_limit_values(limit)


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
        return Step("failed", e.code, None, restore)
    return Step("engaged" if after.engaged else "failed", None if after.engaged else "provider_error", after.enforcement, restore)


def release_project(client, pid, restore):
    """The Step of the release on one project; the limit is read back, and a project that still reads as the kill value is failed."""
    if restore is None:
        return Step("failed", "invalid_input", None)
    if not lever_state(client, pid).engaged:  # someone else changed the limit: it is not ours to touch
        return Step("already_active", None, None)
    for lever in LEVERS:
        lever.release(client, pid, restore)
    after = lever_state(client, pid)
    return Step("failed", "provider_error", after.enforcement) if after.engaged else Step("released", None, None)


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
