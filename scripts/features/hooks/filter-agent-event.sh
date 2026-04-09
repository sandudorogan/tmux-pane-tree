#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(CDPATH= cd -- "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
. "$SCRIPT_DIR/../../core/lib.sh"

HOOK_METADATA_JSON="${HOOK_METADATA_JSON:-}" \
HOOK_SESSION_STATE_FILE="$(hook_session_state_file)" \
python3 - <<'PY'
from __future__ import annotations

import json
import os
import tempfile
import time
from pathlib import Path
from typing import Any
from contextlib import contextmanager
import fcntl


MAX_AGE_SECONDS = 7 * 24 * 60 * 60


def load_payload(raw_payload: str) -> dict[str, Any]:
    payload = raw_payload.strip()
    if not payload:
        return {}
    try:
        loaded = json.loads(payload)
    except Exception:
        return {}
    return loaded if isinstance(loaded, dict) else {}


def normalize_event(value: str) -> str:
    return "".join(ch for ch in value.lower() if ch.isalnum())


def session_key(app: str, session_id: str) -> str:
    if app and session_id:
        return f"{app}:{session_id}"
    return session_id


def normalize_state(raw_state: Any) -> dict[str, dict[str, int]]:
    state: dict[str, dict[str, int]] = {
        "subagent_sessions": {},
        "pending_parent_sessions": {},
    }
    if not isinstance(raw_state, dict):
        return state

    for key in ("subagent_sessions", "pending_parent_sessions"):
        value = raw_state.get(key)
        if isinstance(value, dict):
            cleaned: dict[str, int] = {}
            for name, timestamp in value.items():
                try:
                    cleaned[str(name)] = int(timestamp)
                except Exception:
                    continue
            state[key] = cleaned
    return state


def prune_state(state: dict[str, dict[str, int]], now: int) -> bool:
    changed = False
    cutoff = now - MAX_AGE_SECONDS
    for key in ("subagent_sessions", "pending_parent_sessions"):
        entries = state[key]
        kept: dict[str, int] = {}
        for name, timestamp in entries.items():
            if timestamp >= cutoff:
                kept[name] = timestamp
            else:
                changed = True
        if kept != entries:
            state[key] = kept
    return changed


def write_state(path: Path, state: dict[str, dict[str, int]]) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    tmp_fd, tmp_name = tempfile.mkstemp(prefix=".agent-hook-state.", dir=str(path.parent))
    try:
        with os.fdopen(tmp_fd, "w", encoding="utf-8") as handle:
            json.dump(state, handle, separators=(",", ":"))
            handle.write("\n")
        os.replace(tmp_name, path)
    finally:
        try:
            os.unlink(tmp_name)
        except FileNotFoundError:
            pass


def classify_event(metadata: dict[str, Any]) -> str:
    normalized = normalize_event(str(metadata.get("event") or ""))
    if normalized in {"subagentstart", "subagentstop"}:
        return "subagent"
    if normalized in {
        "agentturncomplete",
        "complete",
        "completed",
        "done",
        "finish",
        "finished",
        "sessionend",
        "stop",
        "stopped",
        "taskcomplete",
        "turncomplete",
    }:
        return "done"
    if normalized in {
        "approvalneeded",
        "approvalrequested",
        "inputrequired",
        "permissionasked",
        "permissionrequest",
    }:
        return "needs-input"

    if str(metadata.get("app") or "").strip().lower() == "codex":
        notification_type = str(metadata.get("notification_type") or "").strip().lower()
        if notification_type == "permission_prompt":
            return "needs-input"

        status = str(metadata.get("status") or "").strip().lower().replace("_", "-")
        if status in {
            "complete",
            "completed",
            "done",
            "finished",
            "stopped",
        }:
            return "done"

    return ""


@contextmanager
def with_locked_state(path: Path):
    lock_path = path.with_name(path.name + ".lock")
    lock_path.parent.mkdir(parents=True, exist_ok=True)
    lock_handle = open(lock_path, "a+", encoding="utf-8")
    fcntl.flock(lock_handle, fcntl.LOCK_EX)
    try:
        yield
    finally:
        fcntl.flock(lock_handle, fcntl.LOCK_UN)
        lock_handle.close()


metadata = load_payload(os.environ.get("HOOK_METADATA_JSON", ""))
app = str(metadata.get("app") or "").strip().lower()
event = str(metadata.get("event") or "").strip()
session_id = str(metadata.get("session_id") or "").strip()
explicit_subagent_event = bool(metadata.get("explicit_subagent_event"))
delegate_session = bool(metadata.get("delegate_session"))
permission_mode = str(metadata.get("permission_mode") or "").strip().lower()

state_path = Path(os.environ["HOOK_SESSION_STATE_FILE"])
event_kind = classify_event(metadata)
delegate_session = delegate_session or permission_mode in {"delegate", "dangerouslyskippermissions"}

with with_locked_state(state_path):
    now = int(time.time())
    state = normalize_state({})
    if state_path.exists():
        try:
            state = normalize_state(json.loads(state_path.read_text(encoding="utf-8")))
        except Exception:
            state = normalize_state({})

    changed = prune_state(state, now)
    key = session_key(app, session_id)
    tracked_session = bool(key) and key in state["subagent_sessions"]
    # Explicit Claude/Cursor subagent lifecycle hooks are emitted on the
    # delegator session, so suppress the lifecycle event itself without
    # permanently tagging that session as a subagent.
    should_store = bool(key) and (delegate_session or tracked_session)
    should_suppress = explicit_subagent_event or (
        event_kind in {"done", "needs-input"} and (delegate_session or tracked_session)
    )

    if should_store and state["subagent_sessions"].get(key) != now:
        state["subagent_sessions"][key] = now
        changed = True

    if changed or should_store:
        write_state(state_path, state)

    print("suppress" if should_suppress else "allow")
PY
