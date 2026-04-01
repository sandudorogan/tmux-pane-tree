#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(CDPATH= cd -- "$(dirname "$0")" && pwd)"
SCRIPTS_DIR="$(CDPATH= cd -- "$SCRIPT_DIR/../.." && pwd)"
. "$SCRIPTS_DIR/core/hook-lib.sh"
update_helper="${TMUX_SIDEBAR_UPDATE_HELPER:-$SCRIPTS_DIR/features/state/update-pane-state.sh}"

resolve_hook_input "${1:-}" "${2:-}"
parse_hook_result claude
metadata_json="$(hook_metadata_json claude "$hook_event")"
suppression="$(HOOK_METADATA_JSON="$metadata_json" bash "$SCRIPTS_DIR/features/hooks/filter-agent-event.sh")"
[ "$suppression" = suppress ] && exit 0

exec "$update_helper" \
  --pane "${TMUX_PANE:-}" \
  --app claude \
  --status "$hook_status" \
  --message "$hook_message"
