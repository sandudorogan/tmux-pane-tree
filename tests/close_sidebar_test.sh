#!/usr/bin/env bash
set -euo pipefail

. "$(dirname "$0")/testlib.sh"

fake_tmux_no_sidebar
fake_tmux_register_pane "%1" "work" "@1" "editor" "nvim"

bash scripts/close-sidebar.sh

assert_file_not_contains "$TEST_TMUX_DATA_DIR/commands.log" 'set-option -g @tmux_sidebar_enabled 1'
assert_file_not_contains "$TEST_TMUX_DATA_DIR/commands.log" 'split-window -h -b -d -f -l 25'
