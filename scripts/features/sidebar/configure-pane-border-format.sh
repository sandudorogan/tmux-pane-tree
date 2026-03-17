#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(CDPATH= cd -- "$(dirname "$0")" && pwd)"
SCRIPTS_DIR="$(CDPATH= cd -- "$SCRIPT_DIR/../.." && pwd)"
. "$SCRIPTS_DIR/core/lib.sh"

base_option='@tmux_sidebar_base_pane_border_format'
wrapped_format="$(sidebar_pane_border_format)"
current_format="$(tmux show-options -gv pane-border-format 2>/dev/null || true)"

if [ "$current_format" = "$wrapped_format" ]; then
  exit 0
fi

tmux set-option -g "$base_option" "$current_format"
tmux set-option -g pane-border-format "$wrapped_format"
