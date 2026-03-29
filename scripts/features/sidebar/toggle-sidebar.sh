#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(CDPATH= cd -- "$(dirname "$0")" && pwd)"
SCRIPTS_DIR="$(CDPATH= cd -- "$SCRIPT_DIR/../.." && pwd)"
. "$SCRIPTS_DIR/core/lib.sh"
ensure_script="$SCRIPT_DIR/ensure-sidebar-pane.sh"
close_script="$SCRIPT_DIR/close-sidebar.sh"

current_window="$(tmux display-message -p '#{window_id}' 2>/dev/null || true)"
enabled="$(tmux show-options -gv @tmux_sidebar_enabled 2>/dev/null || printf '0\n')"
sidebar_panes="$(list_sidebar_panes)"
current_window_sidebar_panes=""
if [ -n "$current_window" ]; then
  current_window_sidebar_panes="$(list_sidebar_panes_in_window "$current_window")"
fi

if [ "$enabled" = "1" ] && [ -z "$sidebar_panes" ]; then
  tmux set-option -g @tmux_sidebar_enabled 0
  if [ -n "$current_window" ]; then
    clear_sidebar_window_state_options "$current_window"
  fi
  enabled="0"
fi

if [ "$enabled" = "1" ]; then
  if [ -n "$current_window_sidebar_panes" ]; then
    bash "$close_script"
    exit 0
  fi
fi

current_pane="$(tmux display-message -p '#{pane_id}' 2>/dev/null || true)"
current_title="$(tmux display-message -p '#{pane_title}' 2>/dev/null || true)"
if [ -n "$current_pane" ] && ! printf '%s\n' "$current_title" | grep -Eq "$(sidebar_title_pattern)"; then
  tmux set-option -g @tmux_sidebar_main_pane "$current_pane"
fi

tmux set-option -g @tmux_sidebar_enabled 1
focus_on_open="$(get_pane_tree_option focus_on_open)"
if [ -n "$current_window" ] && option_is_enabled "$focus_on_open" "1"; then
  tmux set-option -g "$(sidebar_focus_request_option "$current_window")" 1
fi
bash "$ensure_script"
