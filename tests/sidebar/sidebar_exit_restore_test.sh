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

bash scripts/features/sidebar/handle-pane-exited.sh %99 @1

assert_file_contains "$TEST_TMUX_DATA_DIR/commands.log" 'set-option -g @tmux_sidebar_enabled 0'
assert_file_contains "$TEST_TMUX_DATA_DIR/commands.log" 'select-layout -t @1 layout-before'
assert_file_contains "$TEST_TMUX_DATA_DIR/commands.log" 'set-option -g -u @tmux_sidebar_layout_w1'
assert_file_contains "$TEST_TMUX_DATA_DIR/commands.log" 'set-option -g -u @tmux_sidebar_panes_w1'
assert_file_contains "$TEST_TMUX_DATA_DIR/commands.log" 'set-option -g -u @tmux_sidebar_pane_w1'

fake_tmux_no_sidebar
fake_tmux_register_pane "%1" "work" "@1" "editor" "nvim"
fake_tmux_register_pane "%2" "work" "@1" "editor" "shell" "zsh"
fake_tmux_register_pane "%3" "work" "@2" "logs" "tail"
fake_tmux_set_window_layout "@1" 'layout-left'
fake_tmux_set_window_layout "@2" 'layout-right'
printf '1\n' > "$TEST_TMUX_DATA_DIR/option__tmux_sidebar_enabled.txt"
printf '%%99\n' > "$TEST_TMUX_DATA_DIR/option__tmux_sidebar_pane_w1.txt"
printf 'layout-left\n' > "$TEST_TMUX_DATA_DIR/option__tmux_sidebar_layout_w1.txt"
printf '%%1,%%2\n' > "$TEST_TMUX_DATA_DIR/option__tmux_sidebar_panes_w1.txt"
printf '%%98\n' > "$TEST_TMUX_DATA_DIR/option__tmux_sidebar_pane_w2.txt"
printf 'layout-right\n' > "$TEST_TMUX_DATA_DIR/option__tmux_sidebar_layout_w2.txt"
printf '%%3\n' > "$TEST_TMUX_DATA_DIR/option__tmux_sidebar_panes_w2.txt"
fake_tmux_add_sidebar_pane "%98" "@2"

bash scripts/features/sidebar/handle-pane-exited.sh %99 @1

assert_eq "$(fake_tmux_sidebar_count)" "0"
assert_file_contains "$TEST_TMUX_DATA_DIR/commands.log" 'select-layout -t @1 layout-left'
assert_file_contains "$TEST_TMUX_DATA_DIR/commands.log" 'select-layout -t @2 layout-right'
