#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(CDPATH= cd -- "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
. "$SCRIPT_DIR/../scripts/core/lib.sh"

# TMUX_PANE_TREE_PLUGIN_DIR overrides TMUX_SIDEBAR_PLUGIN_DIR; see scripts/core/lib.sh pane_tree_plugin_dir
PLUGIN_DIR="$(pane_tree_plugin_dir "$(CDPATH= cd -- "$SCRIPT_DIR/.." && pwd)")"
export CODEX_EVENT="${CODEX_EVENT:-}"
export CODEX_STATUS="${CODEX_STATUS:-}"
export CODEX_MESSAGE="${CODEX_MESSAGE:-}"

payload="$(
  python3 - <<'PY'
import json
import os

print(json.dumps({
    "event": os.environ.get("CODEX_EVENT", ""),
    "status": os.environ.get("CODEX_STATUS", ""),
    "message": os.environ.get("CODEX_MESSAGE", ""),
}, separators=(",", ":")))
PY
)"

printf '%s' "$payload" | exec "$PLUGIN_DIR/scripts/features/hooks/hook-codex.sh"
