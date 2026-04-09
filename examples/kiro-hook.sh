#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(CDPATH= cd -- "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
. "$SCRIPT_DIR/../scripts/core/lib.sh"

# TMUX_PANE_TREE_PLUGIN_DIR overrides TMUX_SIDEBAR_PLUGIN_DIR; see scripts/core/lib.sh pane_tree_plugin_dir
PLUGIN_DIR="$(pane_tree_plugin_dir "$(CDPATH= cd -- "$SCRIPT_DIR/.." && pwd)")"
export KIRO_EVENT="${KIRO_EVENT:-}"
export KIRO_MESSAGE="${KIRO_MESSAGE:-}"
export KIRO_TOOL_NAME="${KIRO_TOOL_NAME:-}"

payload="$(
  python3 - <<'PY'
import json
import os

payload = {
    "hook_event_name": os.environ.get("KIRO_EVENT", ""),
    "message": os.environ.get("KIRO_MESSAGE", ""),
}
tool_name = os.environ.get("KIRO_TOOL_NAME", "")
if tool_name:
    payload["tool_name"] = tool_name

print(json.dumps(payload, separators=(",", ":")))
PY
)"

printf '%s' "$payload" | exec "$PLUGIN_DIR/scripts/features/hooks/hook-kiro.sh"
