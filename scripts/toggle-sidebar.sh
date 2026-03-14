#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(CDPATH= cd -- "$(dirname "$0")" && pwd)"
. "$SCRIPT_DIR/lib.sh"
ensure_script="$SCRIPT_DIR/ensure-sidebar-pane.sh"
close_script="$SCRIPT_DIR/close-sidebar.sh"

enabled="$(tmux show-options -gv @tmux_sidebar_enabled 2>/dev/null || printf '0\n')"
sidebar_panes="$(
  list_sidebar_panes
)"

if [ "$enabled" = "1" ] && [ -z "$sidebar_panes" ]; then
  clear_sidebar_state_options
  enabled="0"
fi

if [ "$enabled" = "1" ]; then
  bash "$close_script"
  exit 0
fi

current_pane="$(tmux display-message -p '#{pane_id}' 2>/dev/null || true)"
current_title="$(tmux display-message -p '#{pane_title}' 2>/dev/null || true)"
current_window="$(tmux display-message -p '#{window_id}' 2>/dev/null || true)"
if [ -n "$current_pane" ] && ! printf '%s\n' "$current_title" | grep -Eq "$(sidebar_title_pattern)"; then
  tmux set-option -g @tmux_sidebar_main_pane "$current_pane"
fi

tmux set-option -g @tmux_sidebar_enabled 1
focus_on_open="$(tmux show-options -gv @tmux_sidebar_focus_on_open 2>/dev/null || true)"
if [ -n "$current_window" ] && option_is_enabled "$focus_on_open" "1"; then
  tmux set-option -g "$(sidebar_focus_request_option "$current_window")" 1
fi
bash "$ensure_script"
