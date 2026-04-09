#!/usr/bin/env python3
from __future__ import annotations

import json
import os
import sys
from typing import Any


def load_payload(raw_payload: str) -> dict[str, Any]:
    payload = raw_payload.strip()
    if not payload:
        return {}
    try:
        loaded = json.loads(payload)
    except Exception:
        return {}
    return loaded if isinstance(loaded, dict) else {}


def main() -> None:
    app = str(sys.argv[1] if len(sys.argv) > 1 else "").strip()
    fallback_event = str(sys.argv[2] if len(sys.argv) > 2 else "").strip()
    data = load_payload(os.environ.get("HOOK_PAYLOAD", ""))

    event = str(data.get("hook_event_name") or data.get("event") or data.get("type") or fallback_event).strip()
    if app == "claude" and not event:
        event = str(os.environ.get("CLAUDE_HOOK_EVENT_NAME") or "").strip()
    session_id = str(data.get("session_id") or data.get("conversation_id") or "").strip()
    permission_mode = str(data.get("permission_mode") or "").strip()
    notification_type = str(data.get("notification_type") or "").strip()
    status = str(data.get("status") or data.get("state") or "").strip()
    explicit_subagent_event = event in {"SubagentStart", "SubagentStop", "subagentStart", "subagentStop"}
    delegate_session = app == "codex" and permission_mode in {"delegate", "dangerouslySkipPermissions"}

    print(
        json.dumps(
            {
                "app": app,
                "event": event,
                "session_id": session_id,
                "permission_mode": permission_mode,
                "notification_type": notification_type,
                "status": status,
                "explicit_subagent_event": explicit_subagent_event,
                "delegate_session": delegate_session,
            },
            separators=(",", ":"),
        )
    )


if __name__ == "__main__":
    main()
