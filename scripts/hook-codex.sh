#!/usr/bin/env bash
set -euo pipefail

printf '[%s] args=%s stdin=%s\n' "$(date +%H:%M:%S)" "${1:-}${2:+ $2}" "$([ -t 0 ] && echo no || echo yes)" >> /tmp/codex-hook-debug.log

SCRIPT_DIR="$(CDPATH= cd -- "$(dirname "$0")" && pwd)"
update_helper="${TMUX_SIDEBAR_UPDATE_HELPER:-$SCRIPT_DIR/update-pane-state.sh}"
forward_notify="${TMUX_SIDEBAR_CODEX_NOTIFY_FORWARD:-${CLAUDE_CONFIG_DIR:-$HOME/.claude}/hooks/peon-ping/adapters/codex.sh}"

looks_like_json() {
  case "${1:-}" in
    \{*|\[*)
      return 0
      ;;
    *)
      return 1
      ;;
  esac
}

codex_event=""
payload=""
arg1="${1:-}"
arg2="${2:-}"
if [ -t 0 ]; then
  if looks_like_json "$arg1"; then
    payload="$arg1"
    codex_event="$arg2"
  else
    codex_event="$arg1"
    if looks_like_json "$arg2"; then
      payload="$arg2"
    fi
  fi
else
  codex_event="$arg1"
  payload="$(cat)"
  if [ -z "$payload" ]; then
    if looks_like_json "$arg1"; then
      payload="$arg1"
      codex_event="$arg2"
    elif looks_like_json "$arg2"; then
      payload="$arg2"
    fi
  fi
fi

if [ -x "$forward_notify" ]; then
  printf '%s' "$payload" | "$forward_notify" "$codex_event" || true
fi

parsed="$(
  CODEX_EVENT="$codex_event" PAYLOAD="$payload" python3 - <<'PY'
import json
import os

payload = os.environ.get("PAYLOAD", "").strip()
data = {}
if payload:
    try:
        loaded = json.loads(payload)
        if isinstance(loaded, dict):
            data = loaded
    except Exception:
        data = {}

raw_event = str(
    os.environ.get("CODEX_EVENT")
    or data.get("hook_event_name")
    or data.get("event")
    or data.get("type")
    or ""
).strip().lower().replace("_", "-")

notif_type = str(data.get("notification_type") or "").strip().lower()
status_hint = str(data.get("status") or data.get("state") or "").strip().lower().replace("_", "-")
message = str(data.get("summary") or data.get("transcript_summary") or data.get("message") or "").strip()
message_hint = message.lower()

done_events = {
    "agent-turn-complete",
    "complete",
    "completed",
    "done",
    "finish",
    "finished",
    "session-end",
    "stop",
    "stopped",
    "task-complete",
    "turn-complete",
}
done_statuses = {
    "complete",
    "completed",
    "done",
    "finished",
    "stopped",
}
idle_statuses = {
    "idle",
    "ready",
    "waiting",
}

if raw_event in done_events or status_hint in done_statuses:
    status = "done"
elif (
    raw_event.startswith("permission")
    or raw_event.startswith("approve")
    or raw_event in ("approval-requested", "approval-needed", "input-required")
    or notif_type == "permission_prompt"
):
    status = "needs-input"
elif raw_event.startswith("error") or raw_event.startswith("fail"):
    status = "error"
elif notif_type == "idle_prompt" or raw_event == "idle-prompt":
    status = "idle"
elif status_hint == "running":
    status = "running"
else:
    status = ""

print(status)
print(message)
PY
)"

status="$(printf '%s\n' "$parsed" | sed -n '1p')"
message="$(printf '%s\n' "$parsed" | sed -n '2p')"

printf '  -> status=%s pane=%s\n' "$status" "${TMUX_PANE:-}" >> /tmp/codex-hook-debug.log

[ -n "$status" ] || exit 0

exec "$update_helper" \
  --pane "${TMUX_PANE:-}" \
  --app codex \
  --status "$status" \
  --message "$message"
