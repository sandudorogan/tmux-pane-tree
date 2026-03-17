#!/usr/bin/env bash
set -euo pipefail

. "$(dirname "$0")/testlib.sh"

fake_tmux_no_sidebar
fake_tmux_register_main_pane "%1"

bash scripts/features/sidebar/focus-main-pane.sh

assert_file_contains "$TEST_TMUX_DATA_DIR/commands.log" 'select-pane -t %1'
