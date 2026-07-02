#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(CDPATH= cd -- "$(dirname "$0")" && pwd)"
SCRIPTS_DIR="$(CDPATH= cd -- "$SCRIPT_DIR/../.." && pwd)"
. "$SCRIPTS_DIR/core/lib.sh"
. "$SCRIPTS_DIR/core/hook-lib.sh"
update_helper="${TMUX_SIDEBAR_UPDATE_HELPER:-$SCRIPTS_DIR/features/state/update-pane-state.sh}"

resolve_hook_input "${1:-}" "${2:-}"
parse_hook_result opencode "$hook_event"
[ -n "$hook_status" ] || exit 0
pane_id="$(resolve_agent_target_pane "${TMUX_PANE:-}")"
[ -n "$pane_id" ] || exit 0

exec "$update_helper" \
  --pane "$pane_id" \
  --app opencode \
  --status "$hook_status" \
  --message "$hook_message"
