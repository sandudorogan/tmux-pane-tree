#!/usr/bin/env bash
set -euo pipefail

. "$(dirname "$0")/testlib.sh"

fake_tmux_no_sidebar
fake_tmux_register_pane "%1" "work" "@1" "editor" "nvim"
fake_tmux_register_pane "%90" "work" "@1" "editor" "Sidebar" "python3"
fake_tmux_add_sidebar_pane "%90" "@1"

bash scripts/features/sidebar/reload-sidebar-panes.sh

assert_file_contains "$TEST_TMUX_DATA_DIR/commands.log" 'respawn-pane -k -t %90 python3'
assert_file_contains "$TEST_TMUX_DATA_DIR/commands.log" 'sidebar-ui.py'
assert_file_contains "$TEST_TMUX_DATA_DIR/commands.log" 'set-option -p -t %90 allow-set-title off'
assert_file_not_contains "$TEST_TMUX_DATA_DIR/commands.log" 'split-window -h -b -d -f -l 25'

fake_tmux_no_sidebar
fake_tmux_register_pane "%1" "work" "@1" "editor" "nvim"
fake_tmux_register_pane "%90" "work" "@1" "editor" "Sidebar" "python3"
fake_tmux_add_sidebar_pane "%90" "@1"
: > "$TEST_TMUX_DATA_DIR/fail_allow_set_title.txt"

bash scripts/features/sidebar/reload-sidebar-panes.sh

assert_file_contains "$TEST_TMUX_DATA_DIR/commands.log" 'respawn-pane -k -t %90 python3'
assert_file_contains "$TEST_TMUX_DATA_DIR/commands.log" 'set-option -p -t %90 allow-set-title off'

fake_tmux_no_sidebar
fake_tmux_register_pane "%17" "work" "@1" "editor" "tmux-sidebar" "codex-aarch64-apple-darwin"

bash scripts/features/sidebar/reload-sidebar-panes.sh

assert_file_not_contains "$TEST_TMUX_DATA_DIR/commands.log" 'respawn-pane -k -t %17'
