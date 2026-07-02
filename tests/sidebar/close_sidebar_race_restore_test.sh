#!/usr/bin/env bash
set -euo pipefail

. "$(dirname "$0")/testlib.sh"

fake_tmux_no_sidebar
fake_tmux_register_pane "%1" "work" "@1" "editor" "nvim"
fake_tmux_register_pane "%2" "work" "@1" "editor" "shell" "zsh"
fake_tmux_set_window_layout "@1" 'layout-before'
printf '1\n' > "$TEST_TMUX_DATA_DIR/option__tmux_sidebar_enabled.txt"
printf '%%99\n' > "$TEST_TMUX_DATA_DIR/option__tmux_sidebar_pane_w1.txt"
printf 'layout-before\n' > "$TEST_TMUX_DATA_DIR/option__tmux_sidebar_layout_w1.txt"
printf '%%1,%%2\n' > "$TEST_TMUX_DATA_DIR/option__tmux_sidebar_panes_w1.txt"

bash scripts/features/sidebar/close-sidebar.sh %99 @1

assert_file_contains "$TEST_TMUX_DATA_DIR/commands.log" 'set-option -g @tmux_sidebar_enabled 0'
assert_file_contains "$TEST_TMUX_DATA_DIR/commands.log" 'select-layout -t @1 layout-before'
assert_file_contains "$TEST_TMUX_DATA_DIR/commands.log" 'set-option -g -u @tmux_sidebar_layout_w1'
assert_file_contains "$TEST_TMUX_DATA_DIR/commands.log" 'set-option -g -u @tmux_sidebar_panes_w1'

fake_tmux_no_sidebar
fake_tmux_register_pane "%1" "work" "@1" "editor" "nvim"
fake_tmux_register_pane "%2" "logs" "@2" "server" "bash" "bash"
fake_tmux_add_sidebar_pane "%90" "@1"
fake_tmux_add_sidebar_pane "%80" "@2"
fake_tmux_set_window_layout "@1" 'layout-work'
fake_tmux_set_window_layout "@2" 'layout-logs'
printf '1\n' > "$TEST_TMUX_DATA_DIR/option__tmux_sidebar_enabled.txt"
printf 'layout-work\n' > "$TEST_TMUX_DATA_DIR/option__tmux_sidebar_layout_w1.txt"
printf '%%1\n' > "$TEST_TMUX_DATA_DIR/option__tmux_sidebar_panes_w1.txt"
printf '%%90\n' > "$TEST_TMUX_DATA_DIR/option__tmux_sidebar_pane_w1.txt"
printf 'layout-logs\n' > "$TEST_TMUX_DATA_DIR/option__tmux_sidebar_layout_w2.txt"
printf '%%2\n' > "$TEST_TMUX_DATA_DIR/option__tmux_sidebar_panes_w2.txt"
printf '%%80\n' > "$TEST_TMUX_DATA_DIR/option__tmux_sidebar_pane_w2.txt"

bash scripts/features/sidebar/close-sidebar.sh

assert_file_contains "$TEST_TMUX_DATA_DIR/commands.log" 'kill-pane -t %90'
assert_file_contains "$TEST_TMUX_DATA_DIR/commands.log" 'kill-pane -t %80'
assert_file_contains "$TEST_TMUX_DATA_DIR/commands.log" 'select-layout -t @1 layout-work'
assert_file_contains "$TEST_TMUX_DATA_DIR/commands.log" 'select-layout -t @2 layout-logs'
assert_file_contains "$TEST_TMUX_DATA_DIR/commands.log" 'set-option -g -u @tmux_sidebar_pane_w1'
assert_file_contains "$TEST_TMUX_DATA_DIR/commands.log" 'set-option -g -u @tmux_sidebar_pane_w2'
