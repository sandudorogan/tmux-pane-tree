#!/usr/bin/env bash
set -euo pipefail

. "$(dirname "$0")/testlib.sh"

# Test 1: In sidebar -> focuses main pane
fake_tmux_no_sidebar
fake_tmux_register_pane "%1" "work" "@1" "editor" "nvim"
fake_tmux_register_pane "%99" "work" "@1" "editor" "Sidebar" "python3"
fake_tmux_add_sidebar_pane "%99" "@1"
printf '1\n' > "$TEST_TMUX_DATA_DIR/option__tmux_sidebar_enabled.txt"
fake_tmux_register_main_pane "%1"
printf '%%99\n' > "$TEST_TMUX_DATA_DIR/current_pane.txt"

bash scripts/features/sidebar/focus-sidebar.sh

assert_file_contains "$TEST_TMUX_DATA_DIR/commands.log" 'select-pane -t %1'
assert_eq "$(fake_tmux_current_pane)" "%1"

# Test 2: In sidebar, main pane in different window -> falls back to first non-sidebar pane in current window
fake_tmux_no_sidebar
fake_tmux_register_pane "%1" "work" "@1" "editor" "nvim"
fake_tmux_register_pane "%2" "logs" "@2" "server" "bash" "bash"
fake_tmux_register_pane "%99" "work" "@1" "editor" "Sidebar" "python3"
fake_tmux_add_sidebar_pane "%99" "@1"
printf '1\n' > "$TEST_TMUX_DATA_DIR/option__tmux_sidebar_enabled.txt"
fake_tmux_register_main_pane "%2"
printf '%%99\n' > "$TEST_TMUX_DATA_DIR/current_pane.txt"

bash scripts/features/sidebar/focus-sidebar.sh

assert_file_contains "$TEST_TMUX_DATA_DIR/commands.log" 'select-pane -t %1'
assert_eq "$(fake_tmux_current_pane)" "%1"

# Test 3: In sidebar, main pane is stale (no meta file) -> falls back to first non-sidebar pane
fake_tmux_no_sidebar
fake_tmux_register_pane "%1" "work" "@1" "editor" "nvim"
fake_tmux_register_pane "%99" "work" "@1" "editor" "Sidebar" "python3"
fake_tmux_add_sidebar_pane "%99" "@1"
printf '1\n' > "$TEST_TMUX_DATA_DIR/option__tmux_sidebar_enabled.txt"
fake_tmux_register_main_pane "%50"
printf '%%99\n' > "$TEST_TMUX_DATA_DIR/current_pane.txt"

bash scripts/features/sidebar/focus-sidebar.sh

assert_file_contains "$TEST_TMUX_DATA_DIR/commands.log" 'select-pane -t %1'
assert_eq "$(fake_tmux_current_pane)" "%1"

# Test 4: In sidebar, no main pane stored -> falls back to first non-sidebar pane
fake_tmux_no_sidebar
fake_tmux_register_pane "%1" "work" "@1" "editor" "nvim"
fake_tmux_register_pane "%99" "work" "@1" "editor" "Sidebar" "python3"
fake_tmux_add_sidebar_pane "%99" "@1"
printf '1\n' > "$TEST_TMUX_DATA_DIR/option__tmux_sidebar_enabled.txt"
printf '%%99\n' > "$TEST_TMUX_DATA_DIR/current_pane.txt"

bash scripts/features/sidebar/focus-sidebar.sh

assert_file_contains "$TEST_TMUX_DATA_DIR/commands.log" 'select-pane -t %1'
assert_eq "$(fake_tmux_current_pane)" "%1"

# Test 5: Not in sidebar, sidebar open -> focuses sidebar pane
fake_tmux_no_sidebar
fake_tmux_register_pane "%1" "work" "@1" "editor" "nvim"
fake_tmux_register_pane "%99" "work" "@1" "editor" "Sidebar" "python3"
fake_tmux_add_sidebar_pane "%99" "@1"
printf '1\n' > "$TEST_TMUX_DATA_DIR/option__tmux_sidebar_enabled.txt"

bash scripts/features/sidebar/focus-sidebar.sh

assert_file_contains "$TEST_TMUX_DATA_DIR/commands.log" 'select-pane -t %99'
assert_eq "$(fake_tmux_current_pane)" "%99"

# Test 6: Not in sidebar, sidebar closed -> opens sidebar via toggle
fake_tmux_no_sidebar
fake_tmux_register_pane "%1" "work" "@1" "editor" "nvim"

bash scripts/features/sidebar/focus-sidebar.sh

assert_eq "$(fake_tmux_sidebar_count)" "1"
assert_file_contains "$TEST_TMUX_DATA_DIR/commands.log" 'set-option -g @tmux_sidebar_enabled 1'
assert_file_contains "$TEST_TMUX_DATA_DIR/commands.log" 'split-window'

# Test 7: Not in sidebar, sidebar closed, focus_on_open=0 -> still sets focus request
fake_tmux_no_sidebar
fake_tmux_register_pane "%1" "work" "@1" "editor" "nvim"
printf '0\n' > "$TEST_TMUX_DATA_DIR/option__tmux_sidebar_focus_on_open.txt"

bash scripts/features/sidebar/focus-sidebar.sh

assert_eq "$(fake_tmux_sidebar_count)" "1"
assert_file_contains "$TEST_TMUX_DATA_DIR/commands.log" 'set-option -g @tmux_sidebar_focus_w1 1'
