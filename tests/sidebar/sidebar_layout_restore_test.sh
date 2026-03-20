#!/usr/bin/env bash
set -euo pipefail

. "$(dirname "$0")/testlib.sh"

fake_tmux_no_sidebar
fake_tmux_register_pane "%1" "work" "@1" "editor" "nvim"
fake_tmux_register_pane "%2" "work" "@1" "editor" "shell" "zsh"
fake_tmux_set_window_layout "@1" 'layout-before'

bash scripts/features/sidebar/toggle-sidebar.sh

assert_file_contains "$TEST_TMUX_DATA_DIR/commands.log" 'set-option -g @tmux_sidebar_layout_w1 layout-before'
assert_file_contains "$TEST_TMUX_DATA_DIR/commands.log" 'set-option -g @tmux_sidebar_panes_w1 %1,%2'

bash scripts/features/sidebar/toggle-sidebar.sh

assert_file_contains "$TEST_TMUX_DATA_DIR/commands.log" 'select-layout -t @1 layout-before'
assert_file_contains "$TEST_TMUX_DATA_DIR/commands.log" 'set-option -g -u @tmux_sidebar_layout_w1'
assert_file_contains "$TEST_TMUX_DATA_DIR/commands.log" 'set-option -g -u @tmux_sidebar_panes_w1'

fake_tmux_no_sidebar
fake_tmux_register_pane "%1" "work" "@1" "editor" "nvim"
fake_tmux_register_pane "%2" "work" "@1" "editor" "shell" "zsh"
fake_tmux_set_window_layout "@1" 'layout-before'

bash scripts/features/sidebar/toggle-sidebar.sh

rm -f "$TEST_TMUX_DATA_DIR/pane_2.meta"

bash scripts/features/sidebar/toggle-sidebar.sh

assert_file_not_contains "$TEST_TMUX_DATA_DIR/commands.log" 'select-layout -t @1 layout-before'
