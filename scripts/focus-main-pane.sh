#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(CDPATH= cd -- "$(dirname "$0")" && pwd)"
. "$SCRIPT_DIR/lib.sh"

main_pane="${1:-$(tmux show-options -gv @tmux_sidebar_main_pane 2>/dev/null || true)}"
[ -n "$main_pane" ] || exit 0

tmux select-pane -t "$main_pane"
