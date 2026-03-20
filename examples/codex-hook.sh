#!/usr/bin/env bash
set -euo pipefail

PLUGIN_DIR="${TMUX_SIDEBAR_PLUGIN_DIR:-$HOME/.tmux/plugins/tmux-sidebar}"
EVENT="${CODEX_EVENT:-}"
RAW_STATUS="${CODEX_STATUS:-}"
MESSAGE="${CODEX_MESSAGE:-}"

status=""
case "$EVENT" in
  agent-turn-complete|complete|completed|done|finish|finished|stop|stopped|task-complete|turn-complete|session-end)
    status="done"
    ;;
  error|fail|failure)
    status="error"
    ;;
  permission*|approve*|approval-requested|input-required)
    status="needs-input"
    ;;
  idle-prompt)
    status="idle"
    ;;
esac

if [ -z "$status" ]; then
  case "$RAW_STATUS" in
    running)        status="running" ;;
    error|failed)   status="error" ;;
    done|completed|finished|stopped) status="done" ;;
    needs-input)    status="needs-input" ;;
  esac
fi

[ -n "$status" ] || exit 0

exec "$PLUGIN_DIR/scripts/features/state/update-pane-state.sh" \
  --pane "${TMUX_PANE:-}" \
  --app codex \
  --status "$status" \
  --message "$MESSAGE"
