#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(CDPATH= cd -- "$(dirname "$0")" && pwd)"
SCRIPTS_DIR="$(CDPATH= cd -- "$SCRIPT_DIR/../.." && pwd)"
. "$SCRIPTS_DIR/core/lib.sh"
. "$SCRIPTS_DIR/core/hook-lib.sh"
update_helper="${TMUX_SIDEBAR_UPDATE_HELPER:-$SCRIPTS_DIR/features/state/update-pane-state.sh}"

resolve_hook_input "${1:-}" "${2:-}"
parse_hook_result claude
[ -n "$hook_status" ] || exit 0
pane_id="$(resolve_agent_target_pane "${TMUX_PANE:-}")"
[ -n "$pane_id" ] || exit 0
metadata_json="$(hook_metadata_json claude "$hook_event")"
suppression="$(HOOK_METADATA_JSON="$metadata_json" HOOK_SUBAGENT_TRACKING=1 bash "$SCRIPTS_DIR/features/hooks/filter-agent-event.sh")"
[ "$suppression" = suppress ] && exit 0

update_args=(
  --pane "$pane_id" \
  --app claude \
  --status "$hook_status" \
  --message "$hook_message"
)
if [ -n "$hook_subagent_event" ]; then
  update_args+=(--subagent-event "$hook_subagent_event")
fi

exec "$update_helper" "${update_args[@]}"
