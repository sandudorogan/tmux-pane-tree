#!/usr/bin/env bash
set -euo pipefail

. "$(dirname "$0")/testlib.sh"

fake_tmux_no_sidebar
fake_tmux_register_pane "%1" "work" "@1" "editor" "nvim"
fake_tmux_register_pane "%2" "work" "@1" "editor" "shell" "zsh"
fake_tmux_add_sidebar_pane "%99" "@1"
fake_tmux_set_window_layout "@1" 'layout-before'
printf '1\n' > "$TEST_TMUX_DATA_DIR/option__tmux_sidebar_enabled.txt"
printf 'layout-before\n' > "$TEST_TMUX_DATA_DIR/option__tmux_sidebar_layout_w1.txt"
printf '%%1,%%2\n' > "$TEST_TMUX_DATA_DIR/option__tmux_sidebar_panes_w1.txt"

TMUX_PANE=%99 python3 - <<'PY'
import importlib.util
from pathlib import Path

spec = importlib.util.spec_from_file_location("sidebar_ui", Path("scripts/ui/sidebar-ui.py"))
module = importlib.util.module_from_spec(spec)
spec.loader.exec_module(module)
module.close_sidebar()
PY

assert_eq "$(fake_tmux_sidebar_count)" "0"
assert_file_contains "$TEST_TMUX_DATA_DIR/commands.log" 'run-shell -b bash '
assert_file_contains "$TEST_TMUX_DATA_DIR/commands.log" 'close-sidebar.sh'
assert_file_contains "$TEST_TMUX_DATA_DIR/commands.log" 'set-option -g @tmux_sidebar_enabled 0'
assert_file_contains "$TEST_TMUX_DATA_DIR/commands.log" 'select-layout -t @1 layout-before'
assert_file_contains "$TEST_TMUX_DATA_DIR/commands.log" 'set-option -g -u @tmux_sidebar_layout_w1'
assert_file_contains "$TEST_TMUX_DATA_DIR/commands.log" 'set-option -g -u @tmux_sidebar_panes_w1'
