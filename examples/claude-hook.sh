#!/usr/bin/env bash
set -euo pipefail

PLUGIN_DIR="${TMUX_SIDEBAR_PLUGIN_DIR:-$HOME/.tmux/plugins/tmux-sidebar}"
EVENT_NAME="${CLAUDE_HOOK_EVENT_NAME:-}"
NOTIFICATION_TYPE="${CLAUDE_NOTIFICATION_TYPE:-}"

status="running"
message=""

case "$EVENT_NAME" in
  Notification)
    if [ "$NOTIFICATION_TYPE" = "idle_prompt" ]; then
      status="idle"
    else
      status="needs-input"
      message="${CLAUDE_NOTIFICATION_MESSAGE:-$EVENT_NAME}"
    fi
    ;;
  PermissionRequest)
    status="needs-input"
    message="${CLAUDE_NOTIFICATION_MESSAGE:-$EVENT_NAME}"
    ;;
  PostToolUseFailure)
    status="error"
    message="${CLAUDE_NOTIFICATION_MESSAGE:-tool failure}"
    ;;
  Stop)
    status="done"
    ;;
  UserPromptSubmit)
    status="running"
    ;;
  SessionStart|SessionEnd)
    status="idle"
    ;;
esac

exec "$PLUGIN_DIR/scripts/features/state/update-pane-state.sh" \
  --pane "${TMUX_PANE:-}" \
  --app claude \
  --status "$status" \
  --message "$message"
