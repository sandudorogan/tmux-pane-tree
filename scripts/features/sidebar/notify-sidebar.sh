#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(CDPATH= cd -- "$(dirname "$0")" && pwd)"
SCRIPTS_DIR="$(CDPATH= cd -- "$SCRIPT_DIR/../.." && pwd)"
. "$SCRIPTS_DIR/core/lib.sh"

target_pane="${1:-}"
enabled="$(tmux show-options -gv @tmux_sidebar_enabled 2>/dev/null || printf '0\n')"
[ "$enabled" = "1" ] || exit 0

if [ -n "$target_pane" ]; then
  width_sync_lock='@tmux_sidebar_width_sync'
  tmux wait-for -L "$width_sync_lock"
  trap 'tmux wait-for -U "$width_sync_lock" 2>/dev/null || true' EXIT
  sync_sidebar_width_from_pane "$target_pane"
fi

signal_sidebar_refresh
