#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(CDPATH= cd -- "$(dirname "$0")" && pwd)"
SCRIPTS_DIR="$(CDPATH= cd -- "$SCRIPT_DIR/../.." && pwd)"
. "$SCRIPTS_DIR/core/hook-lib.sh"
update_helper="${TMUX_SIDEBAR_UPDATE_HELPER:-$SCRIPTS_DIR/features/state/update-pane-state.sh}"
forward_notify="${TMUX_SIDEBAR_CODEX_NOTIFY_FORWARD:-${CLAUDE_CONFIG_DIR:-$HOME/.claude}/hooks/peon-ping/adapters/codex.sh}"

resolve_hook_input "${1:-}" "${2:-}"

if [ -x "$forward_notify" ]; then
  printf '%s' "$hook_payload" | "$forward_notify" "$hook_event" || true
fi

parse_hook_result codex "$hook_event"
[ -n "$hook_status" ] || exit 0
case "$hook_status" in
  done|needs-input)
    metadata_json="$(hook_metadata_json codex "$hook_event")"
    suppression="$(HOOK_METADATA_JSON="$metadata_json" bash "$SCRIPTS_DIR/features/hooks/filter-agent-event.sh")"
    [ "$suppression" = suppress ] && exit 0
    ;;
esac

exec "$update_helper" \
  --pane "${TMUX_PANE:-}" \
  --app codex \
  --status "$hook_status" \
  --message "$hook_message"
