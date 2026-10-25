#!/usr/bin/env bash
set -euo pipefail

. "$(dirname "$0")/real_tmux_testlib.sh"

real_tmux_start_server
real_tmux_source_plugin
real_tmux set-option -g @tmux_pane_tree_close_pane_shortcut dd
real_tmux set-option -g @tmux_sidebar_enabled 1

main_window_id="$(real_tmux display-message -p -t work:editor '#{window_id}')"
main_pane_id="$(real_tmux display-message -p -t work:editor '#{pane_id}')"
real_tmux set-option -g @tmux_sidebar_main_pane "$main_pane_id"
ensure_command="$(real_tmux_shell_command bash "$REPO_ROOT/scripts/features/sidebar/ensure-sidebar-pane.sh" \
  "$main_pane_id" "$main_window_id")"
real_tmux run-shell -b "$ensure_command"
sidebar_pane_id="$(real_tmux_wait_for_sidebar_pane "$main_window_id")"
real_tmux_wait_for_capture "$sidebar_pane_id" 'editor' >/dev/null
real_tmux select-pane -t "$sidebar_pane_id"

real_tmux send-keys -t "$sidebar_pane_id" '?'
help_capture="$(real_tmux_wait_for_capture "$sidebar_pane_id" 'q close   j/k scroll')"
assert_contains "$help_capture" 'Help'
assert_contains "$help_capture" 'Navigation'
assert_contains "$help_capture" '  j / k, Up / Down'
assert_contains "$help_capture" '    Move selection'

real_tmux send-keys -t "$sidebar_pane_id" End
real_tmux_wait_for_capture "$sidebar_pane_id" 'Home / End' >/dev/null
real_tmux send-keys -t "$sidebar_pane_id" Home
real_tmux_wait_for_capture "$sidebar_pane_id" 'Navigation' >/dev/null

real_tmux resize-window -t "$main_window_id" -x 60 -y 8
real_tmux send-keys -t "$sidebar_pane_id" End
real_tmux_wait_for_capture "$sidebar_pane_id" 'page' >/dev/null
real_tmux send-keys -t "$sidebar_pane_id" q
real_tmux_wait_for_capture "$sidebar_pane_id" 'editor' >/dev/null
assert_eq "$(real_tmux display-message -p -t "$sidebar_pane_id" '#{pane_dead}')" "0"

real_tmux send-keys -t "$sidebar_pane_id" '?'
real_tmux_wait_for_capture "$sidebar_pane_id" 'Help' >/dev/null
real_tmux send-keys -t "$sidebar_pane_id" Escape
real_tmux_wait_for_capture "$sidebar_pane_id" 'editor' >/dev/null
assert_eq "$(real_tmux display-message -p -t "$sidebar_pane_id" '#{pane_dead}')" "0"
printf 'Real tmux help, custom keymaps, scrolling, resize, and return passed\n'
