#!/usr/bin/env bash
set -euo pipefail

. "$(dirname "$0")/testlib.sh"

fake_tmux_no_sidebar
fake_tmux_register_pane "%1" "work" "@1" "editor" "nvim"

bash scripts/toggle-sidebar.sh

assert_file_contains "$TEST_TMUX_DATA_DIR/commands.log" 'set-option -g @tmux_sidebar_enabled 1'
assert_file_contains "$TEST_TMUX_DATA_DIR/commands.log" 'split-window -h -b -d -f -l 25'

fake_tmux_no_sidebar
fake_tmux_register_pane "%1" "work" "@1" "editor" "nvim"
printf '1\n' > "$TEST_TMUX_DATA_DIR/option__tmux_sidebar_enabled.txt"

bash scripts/ensure-sidebar-pane.sh

assert_file_contains "$TEST_TMUX_DATA_DIR/commands.log" 'split-window -h -b -d -f -l 25'
assert_file_contains "$TEST_TMUX_DATA_DIR/commands.log" 'select-pane -t %99 -T Sidebar'
assert_file_contains "$TEST_TMUX_DATA_DIR/commands.log" 'set-option -p -t %99 allow-set-title off'
assert_eq "$(fake_tmux_current_pane)" "%1"

fake_tmux_no_sidebar
fake_tmux_register_pane "%1" "work" "@1" "editor" "nvim"
fake_tmux_add_sidebar_pane "%90" "@2"
printf '1\n' > "$TEST_TMUX_DATA_DIR/option__tmux_sidebar_enabled.txt"

bash scripts/ensure-sidebar-pane.sh

assert_file_contains "$TEST_TMUX_DATA_DIR/commands.log" 'split-window -h -b -d -f -l 25'

fake_tmux_no_sidebar
fake_tmux_register_pane "%1" "work" "@1" "editor" "nvim"
fake_tmux_register_pane "%90" "work" "@1" "editor" "Sidebar" "python3"
fake_tmux_add_sidebar_pane "%90" "@1"
printf '1\n' > "$TEST_TMUX_DATA_DIR/option__tmux_sidebar_enabled.txt"
printf '%%90\n' > "$TEST_TMUX_DATA_DIR/option__tmux_sidebar_pane_w1.txt"

bash scripts/ensure-sidebar-pane.sh

assert_file_not_contains "$TEST_TMUX_DATA_DIR/commands.log" 'split-window -h -b -d -f -l 25'

fake_tmux_no_sidebar
fake_tmux_register_pane "%1" "work" "@1" "editor" "nvim"
printf '1\n' > "$TEST_TMUX_DATA_DIR/option__tmux_sidebar_enabled.txt"
printf '%%90\n' > "$TEST_TMUX_DATA_DIR/option__tmux_sidebar_pane_w1.txt"

bash scripts/ensure-sidebar-pane.sh

assert_file_contains "$TEST_TMUX_DATA_DIR/commands.log" 'split-window -h -b -d -f -l 25'

fake_tmux_no_sidebar
fake_tmux_register_pane "%1" "work" "@1" "editor" "nvim"
printf '1\n' > "$TEST_TMUX_DATA_DIR/option__tmux_sidebar_enabled.txt"
printf '1\n' > "$TEST_TMUX_DATA_DIR/option__tmux_sidebar_creating_w1.txt"

bash scripts/ensure-sidebar-pane.sh

assert_file_not_contains "$TEST_TMUX_DATA_DIR/commands.log" 'split-window -h -b -d -f -l 25'

fake_tmux_no_sidebar
fake_tmux_register_pane "%1" "work" "@1" "editor" "nvim"
printf '1\n' > "$TEST_TMUX_DATA_DIR/option__tmux_sidebar_enabled.txt"
printf '28\n' > "$TEST_TMUX_DATA_DIR/option__tmux_sidebar_width.txt"

bash scripts/ensure-sidebar-pane.sh

assert_file_contains "$TEST_TMUX_DATA_DIR/commands.log" 'split-window -h -b -d -f -l 28'
