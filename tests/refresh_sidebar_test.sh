#!/usr/bin/env bash
set -euo pipefail

. "$(dirname "$0")/testlib.sh"

fake_tmux_no_sidebar
fake_tmux_register_pane "%1" "work" "@1" "editor" "nvim"
printf '1\n' > "$TEST_TMUX_DATA_DIR/option__tmux_sidebar_enabled.txt"

bash scripts/refresh-sidebar.sh

assert_file_contains "$TEST_TMUX_DATA_DIR/commands.log" 'split-window -h -b -d -f -l 25'
assert_file_not_contains "$TEST_TMUX_DATA_DIR/commands.log" 'respawn-pane'
