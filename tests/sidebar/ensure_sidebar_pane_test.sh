#!/usr/bin/env bash
set -euo pipefail

. "$(dirname "$0")/testlib.sh"

fake_tmux_no_sidebar
fake_tmux_register_pane "%1" "work" "@1" "editor" "nvim"

bash scripts/features/sidebar/toggle-sidebar.sh

assert_file_contains "$TEST_TMUX_DATA_DIR/commands.log" 'set-option -g @tmux_sidebar_enabled 1'
assert_file_contains "$TEST_TMUX_DATA_DIR/commands.log" 'split-window -t %1 -h -b -d -f -l 25'

fake_tmux_no_sidebar
fake_tmux_register_pane "%1" "work" "@1" "editor" "nvim"
printf '1\n' > "$TEST_TMUX_DATA_DIR/option__tmux_sidebar_enabled.txt"
export TMUX_SIDEBAR_WIDTH='41'

bash scripts/features/sidebar/ensure-sidebar-pane.sh

assert_file_contains "$TEST_TMUX_DATA_DIR/commands.log" 'split-window -t %1 -h -b -d -f -l 25'
unset TMUX_SIDEBAR_WIDTH
assert_file_contains "$TEST_TMUX_DATA_DIR/commands.log" 'select-pane -t %99 -T Sidebar'
assert_file_contains "$TEST_TMUX_DATA_DIR/commands.log" 'set-option -p -t %99 allow-set-title off'
assert_eq "$(fake_tmux_current_pane)" "%1"

fake_tmux_no_sidebar
fake_tmux_register_pane "%1" "work" "@1" "editor" "nvim"
printf '1\n' > "$TEST_TMUX_DATA_DIR/option__tmux_sidebar_enabled.txt"
printf 'shell\n' > "$TEST_TMUX_DATA_DIR/split_window_pane_title.txt"
: > "$TEST_TMUX_DATA_DIR/fail_allow_set_title.txt"

bash scripts/features/sidebar/ensure-sidebar-pane.sh

assert_file_contains "$TEST_TMUX_DATA_DIR/commands.log" 'set-option -p -t %99 allow-set-title off'
assert_file_contains "$TEST_TMUX_DATA_DIR/commands.log" 'select-pane -t %99 -T Sidebar'
assert_file_contains "$TEST_TMUX_DATA_DIR/pane_99.meta" 'pane_title=Sidebar'
assert_eq "$(fake_tmux_current_pane)" "%1"

fake_tmux_no_sidebar
fake_tmux_register_pane "%1" "work" "@1" "editor" "nvim"
fake_tmux_add_sidebar_pane "%90" "@2"
printf '1\n' > "$TEST_TMUX_DATA_DIR/option__tmux_sidebar_enabled.txt"

bash scripts/features/sidebar/ensure-sidebar-pane.sh

assert_file_contains "$TEST_TMUX_DATA_DIR/commands.log" 'split-window -t %1 -h -b -d -f -l 25'

fake_tmux_no_sidebar
fake_tmux_register_pane "%1" "work" "@1" "editor" "nvim"
fake_tmux_register_pane "%90" "work" "@1" "editor" "Sidebar" "python3"
fake_tmux_add_sidebar_pane "%90" "@1"
printf '1\n' > "$TEST_TMUX_DATA_DIR/option__tmux_sidebar_enabled.txt"
printf '%%90\n' > "$TEST_TMUX_DATA_DIR/option__tmux_sidebar_pane_w1.txt"

bash scripts/features/sidebar/ensure-sidebar-pane.sh

assert_file_not_contains "$TEST_TMUX_DATA_DIR/commands.log" 'split-window -h -b -d -f -l 25'

fake_tmux_no_sidebar
fake_tmux_register_pane "%17" "work" "@1" "editor" "tmux-sidebar" "codex-aarch64-apple-darwin"
printf '1\n' > "$TEST_TMUX_DATA_DIR/option__tmux_sidebar_enabled.txt"
printf '%%17\n' > "$TEST_TMUX_DATA_DIR/current_pane.txt"

bash scripts/features/sidebar/ensure-sidebar-pane.sh

assert_file_contains "$TEST_TMUX_DATA_DIR/commands.log" 'split-window -t %17 -h -b -d -f -l 25'

fake_tmux_no_sidebar
fake_tmux_register_pane "%1" "work" "@1" "editor" "nvim"
printf '1\n' > "$TEST_TMUX_DATA_DIR/option__tmux_sidebar_enabled.txt"
printf '%%90\n' > "$TEST_TMUX_DATA_DIR/option__tmux_sidebar_pane_w1.txt"

bash scripts/features/sidebar/ensure-sidebar-pane.sh

assert_file_contains "$TEST_TMUX_DATA_DIR/commands.log" 'split-window -t %1 -h -b -d -f -l 25'

fake_tmux_no_sidebar
fake_tmux_register_pane "%1" "work" "@1" "editor" "nvim"
printf '1\n' > "$TEST_TMUX_DATA_DIR/option__tmux_sidebar_enabled.txt"
printf '1\n' > "$TEST_TMUX_DATA_DIR/option__tmux_sidebar_creating_w1.txt"

bash scripts/features/sidebar/ensure-sidebar-pane.sh

assert_file_not_contains "$TEST_TMUX_DATA_DIR/commands.log" 'split-window -h -b -d -f -l 25'

fake_tmux_no_sidebar
fake_tmux_register_pane "%1" "work" "@1" "editor" "nvim"
printf '1\n' > "$TEST_TMUX_DATA_DIR/option__tmux_sidebar_enabled.txt"
printf '28\n' > "$TEST_TMUX_DATA_DIR/option__tmux_sidebar_width.txt"

bash scripts/features/sidebar/ensure-sidebar-pane.sh

assert_file_contains "$TEST_TMUX_DATA_DIR/commands.log" 'split-window -t %1 -h -b -d -f -l 28'

fake_tmux_no_sidebar
fake_tmux_register_pane "%1" "work" "@1" "editor" "nvim"
fake_tmux_register_pane "%2" "logs" "@2" "server" "bash" "bash"
printf '1\n' > "$TEST_TMUX_DATA_DIR/option__tmux_sidebar_enabled.txt"
fake_tmux_add_sidebar_pane "%90" "@1"
printf '%%2\n' > "$TEST_TMUX_DATA_DIR/current_pane.txt"

bash scripts/features/sidebar/ensure-sidebar-pane.sh

assert_eq "$(fake_tmux_sidebar_count)" "2"
assert_file_contains "$TEST_TMUX_DATA_DIR/commands.log" 'split-window -t %2 -h -b -d -f -l 25'

fake_tmux_no_sidebar
fake_tmux_register_pane "%1" "work" "@1" "editor" "nvim"
fake_tmux_register_pane "%2" "logs" "@2" "server" "bash" "bash"
printf '1\n' > "$TEST_TMUX_DATA_DIR/option__tmux_sidebar_enabled.txt"

bash scripts/features/sidebar/ensure-sidebar-pane.sh %2 @2

assert_eq "$(fake_tmux_sidebar_count)" "1"
assert_file_contains "$TEST_TMUX_DATA_DIR/commands.log" 'wait-for -L @tmux_sidebar_ensure_w2'
assert_file_contains "$TEST_TMUX_DATA_DIR/commands.log" 'wait-for -U @tmux_sidebar_ensure_w2'
assert_file_contains "$TEST_TMUX_DATA_DIR/commands.log" 'split-window -t %2'
assert_file_contains "$TEST_TMUX_DATA_DIR/toggle_panes.txt" '%99|Sidebar|@2'

fake_tmux_no_sidebar
fake_tmux_register_pane "%1" "work" "@1" "editor" "nvim"
fake_tmux_register_pane "%2" "logs" "@2" "server" "bash" "bash"
printf '1\n' > "$TEST_TMUX_DATA_DIR/option__tmux_sidebar_enabled.txt"

bash scripts/features/sidebar/ensure-sidebar-pane.sh "" @2

assert_eq "$(fake_tmux_sidebar_count)" "1"
assert_file_contains "$TEST_TMUX_DATA_DIR/commands.log" 'wait-for -L @tmux_sidebar_ensure_w2'
assert_file_contains "$TEST_TMUX_DATA_DIR/commands.log" 'wait-for -U @tmux_sidebar_ensure_w2'
assert_file_contains "$TEST_TMUX_DATA_DIR/commands.log" 'split-window -t %2'
assert_file_contains "$TEST_TMUX_DATA_DIR/toggle_panes.txt" '%99|Sidebar|@2'
assert_file_not_contains "$TEST_TMUX_DATA_DIR/commands.log" 'split-window -t %1'

fake_tmux_no_sidebar
fake_tmux_register_pane "%1" "work" "@1" "editor" "nvim"
printf '1\n' > "$TEST_TMUX_DATA_DIR/option__tmux_sidebar_enabled.txt"
printf '28\n' > "$TEST_TMUX_DATA_DIR/option__tmux_pane_tree_width.txt"

bash scripts/features/sidebar/ensure-sidebar-pane.sh

assert_file_contains "$TEST_TMUX_DATA_DIR/commands.log" 'split-window -t %1 -h -b -d -f -l 28'
