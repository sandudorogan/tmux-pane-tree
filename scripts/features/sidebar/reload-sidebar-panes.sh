#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(CDPATH= cd -- "$(dirname "$0")" && pwd)"
SCRIPTS_DIR="$(CDPATH= cd -- "$SCRIPT_DIR/../.." && pwd)"
. "$SCRIPTS_DIR/core/lib.sh"

sidebar_command="$(sidebar_ui_command "$SCRIPTS_DIR")"

list_sidebar_panes \
  | while IFS='|' read -r pane_id _window_id; do
      [ -n "$pane_id" ] || continue
      tmux respawn-pane -k -t "$pane_id" "$sidebar_command"
      tmux set-option -p -t "$pane_id" allow-set-title off 2>/dev/null || true
    done
