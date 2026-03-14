#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(CDPATH= cd -- "$(dirname "$0")" && pwd)"
. "$SCRIPT_DIR/lib.sh"

target_pane="${1:-}"
target_window="${2:-}"

enabled="$(tmux show-options -gv @tmux_sidebar_enabled 2>/dev/null || printf '0\n')"
[ "$enabled" = "1" ] || exit 0

sidebar_panes="$(
  list_sidebar_panes
)"

tmux set-option -g @tmux_sidebar_enabled 0

if [ -z "$sidebar_panes" ]; then
  if [ -n "$target_window" ]; then
    restore_sidebar_window_snapshot_if_unchanged "$target_window"
    tmux set-option -g -u "$(sidebar_window_option "pane" "$target_window")" 2>/dev/null || true
  fi
  clear_sidebar_state_options
  exit 0
fi

printf '%s\n' "$sidebar_panes" \
  | while IFS='|' read -r pane_id window_id; do
      [ -n "$pane_id" ] || continue
      tmux kill-pane -t "$pane_id"
      [ -n "$window_id" ] || continue
      restore_sidebar_window_snapshot_if_unchanged "$window_id"
    done

if [ -n "$target_window" ]; then
  restore_sidebar_window_snapshot_if_unchanged "$target_window"
  tmux set-option -g -u "$(sidebar_window_option "pane" "$target_window")" 2>/dev/null || true
fi

clear_sidebar_state_options
