#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(CDPATH= cd -- "$(dirname "$0")" && pwd)"
SCRIPTS_DIR="$(CDPATH= cd -- "$SCRIPT_DIR/../.." && pwd)"
. "$SCRIPTS_DIR/core/lib.sh"
. "$SCRIPTS_DIR/core/hook-lib.sh"
update_helper="${TMUX_SIDEBAR_UPDATE_HELPER:-$SCRIPTS_DIR/features/state/update-pane-state.sh}"

resolve_hook_input "${1:-}" "${2:-}"
hook_event="$(cursor_hook_event)"
explicit_pane="$(cursor_explicit_pane)"
mapfile -t workspace_roots < <(cursor_workspace_roots)
pane_id="$(resolve_agent_target_pane "$explicit_pane" "${workspace_roots[@]}")"
[ -n "$pane_id" ] || exit 0

parse_hook_result cursor "$hook_event"
[ -n "$hook_status" ] || exit 0
case "$hook_status" in
  done|needs-input)
    metadata_json="$(hook_metadata_json cursor "$hook_event")"
    suppression="$(HOOK_METADATA_JSON="$metadata_json" bash "$SCRIPTS_DIR/features/hooks/filter-agent-event.sh")"
    [ "$suppression" = suppress ] && exit 0
    ;;
esac

exec "$update_helper" \
  --pane "$pane_id" \
  --app cursor \
  --status "$hook_status" \
  --message "$hook_message"
