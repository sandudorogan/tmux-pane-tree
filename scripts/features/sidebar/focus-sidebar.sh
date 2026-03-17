#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(CDPATH= cd -- "$(dirname "$0")" && pwd)"
SCRIPTS_DIR="$(CDPATH= cd -- "$SCRIPT_DIR/../.." && pwd)"
. "$SCRIPTS_DIR/core/lib.sh"

current_pane_title="$(tmux display-message -p '#{pane_title}' 2>/dev/null || true)"
current_window="$(tmux display-message -p '#{window_id}' 2>/dev/null || true)"
[ -n "$current_window" ] || exit 0

if printf '%s\n' "$current_pane_title" | grep -Eq "$(sidebar_title_pattern)"; then
  main_pane="$(tmux show-options -gv @tmux_sidebar_main_pane 2>/dev/null || true)"
  if [ -n "$main_pane" ]; then
    main_pane_window="$(tmux display-message -p -t "$main_pane" '#{window_id}' 2>/dev/null || true)"
    if [ "$main_pane_window" = "$current_window" ]; then
      tmux select-pane -t "$main_pane"
      exit 0
    fi
  fi
  fallback="$(
    tmux list-panes -t "$current_window" -F '#{pane_id}|#{pane_title}' 2>/dev/null \
      | awk -F'|' -v sidebar_titles="$(sidebar_title_pattern)" \
          '$2 !~ sidebar_titles { print $1; exit }' \
      || true
  )"
  if [ -n "$fallback" ]; then
    tmux select-pane -t "$fallback"
  fi
  exit 0
fi

sidebar_pane="$(
  list_sidebar_panes_in_window "$current_window" \
    | awk -F'|' '{ print $1; exit }' \
    || true
)"
if [ -n "$sidebar_pane" ]; then
  tmux select-pane -t "$sidebar_pane"
  exit 0
fi

tmux set-option -g "$(sidebar_focus_request_option "$current_window")" 1
exec bash "$SCRIPT_DIR/toggle-sidebar.sh"
