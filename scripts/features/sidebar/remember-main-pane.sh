#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(CDPATH= cd -- "$(dirname "$0")" && pwd)"
SCRIPTS_DIR="$(CDPATH= cd -- "$SCRIPT_DIR/../.." && pwd)"
. "$SCRIPTS_DIR/core/lib.sh"

pane_id="${1:-}"
[ -n "$pane_id" ] || exit 0

pane_title="$(tmux display-message -p -t "$pane_id" '#{pane_title}' 2>/dev/null || true)"
if printf '%s\n' "$pane_title" | grep -Eq "$(sidebar_title_pattern)"; then
  exit 0
fi

tmux set-option -g @tmux_sidebar_main_pane "$pane_id"
