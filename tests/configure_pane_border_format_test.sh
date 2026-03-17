#!/usr/bin/env bash
set -euo pipefail

. "$(dirname "$0")/testlib.sh"

printf '%s\n' '#{pane_current_command} :: #{pane_current_path}' > "$TEST_TMUX_DATA_DIR/option_pane-border-format.txt"

bash scripts/features/sidebar/configure-pane-border-format.sh

assert_file_contains "$TEST_TMUX_DATA_DIR/option__tmux_sidebar_base_pane_border_format.txt" '#{pane_current_command} :: #{pane_current_path}'
assert_file_contains "$TEST_TMUX_DATA_DIR/option_pane-border-format.txt" '#{?#{m/r:^(Sidebar|tmux-sidebar)$,#{pane_title}},#{pane_title},#{E:@tmux_sidebar_base_pane_border_format}}'

printf '%s\n' '#{pane_current_command} :: #{pane_current_path}' > "$TEST_TMUX_DATA_DIR/option__tmux_sidebar_base_pane_border_format.txt"
printf '%s\n' '#{?#{m/r:^(Sidebar|tmux-sidebar)$,#{pane_title}},#{pane_title},#{E:@tmux_sidebar_base_pane_border_format}}' > "$TEST_TMUX_DATA_DIR/option_pane-border-format.txt"

bash scripts/features/sidebar/configure-pane-border-format.sh

assert_eq "$(cat "$TEST_TMUX_DATA_DIR/option__tmux_sidebar_base_pane_border_format.txt")" '#{pane_current_command} :: #{pane_current_path}'
