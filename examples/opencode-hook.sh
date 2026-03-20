#!/usr/bin/env bash
set -euo pipefail

PLUGIN_DIR="${TMUX_SIDEBAR_PLUGIN_DIR:-$HOME/.tmux/plugins/tmux-sidebar}"
EVENT="${OPENCODE_EVENT:-}"
RAW_STATUS="${OPENCODE_STATUS:-}"
MESSAGE="${OPENCODE_MESSAGE:-}"

status=""
case "$EVENT" in
  error|fail|failure)
    status="error"
    ;;
  permission*|approve*|input-required)
    status="needs-input"
    ;;
  session-start|idle-prompt)
    status="idle"
    ;;
  start)
    status="running"
    ;;
  complete|completed|done|finish|finished|stop|stopped|session-end)
    status="done"
    ;;
esac

if [ -z "$status" ]; then
  case "$RAW_STATUS" in
    running)        status="running" ;;
    error|failed)   status="error" ;;
    idle|ready)     status="idle" ;;
    done|completed|finished|stopped) status="done" ;;
    needs-input)    status="needs-input" ;;
    *)              status="${RAW_STATUS:-needs-input}" ;;
  esac
fi

exec "$PLUGIN_DIR/scripts/features/state/update-pane-state.sh" \
  --pane "${TMUX_PANE:-}" \
  --app opencode \
  --status "$status" \
  --message "$MESSAGE"
