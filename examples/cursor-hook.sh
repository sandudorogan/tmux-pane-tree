#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(CDPATH= cd -- "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
. "$SCRIPT_DIR/../scripts/core/lib.sh"

# TMUX_PANE_TREE_PLUGIN_DIR overrides TMUX_SIDEBAR_PLUGIN_DIR; see scripts/core/lib.sh pane_tree_plugin_dir
PLUGIN_DIR="$(pane_tree_plugin_dir "$(CDPATH= cd -- "$SCRIPT_DIR/.." && pwd)")"
export CURSOR_HOOK_EVENT_NAME="${CURSOR_HOOK_EVENT_NAME:-}"
export CURSOR_WORKSPACE_ROOTS="${CURSOR_WORKSPACE_ROOTS:-}"
export CURSOR_STATUS="${CURSOR_STATUS:-}"
export CURSOR_FAILURE_TYPE="${CURSOR_FAILURE_TYPE:-}"
export CURSOR_AGENT_MESSAGE="${CURSOR_AGENT_MESSAGE:-}"

payload="$(
  python3 - <<'PY'
import json
import os

workspace_roots = [
    value
    for value in os.environ.get("CURSOR_WORKSPACE_ROOTS", "").split(":")
    if value
]

print(json.dumps({
    "hook_event_name": os.environ.get("CURSOR_HOOK_EVENT_NAME", ""),
    "workspace_roots": workspace_roots,
    "status": os.environ.get("CURSOR_STATUS", ""),
    "failure_type": os.environ.get("CURSOR_FAILURE_TYPE", ""),
    "agent_message": os.environ.get("CURSOR_AGENT_MESSAGE", ""),
}, separators=(",", ":")))
PY
)"

printf '%s' "$payload" | exec "$PLUGIN_DIR/scripts/features/hooks/hook-cursor.sh"
