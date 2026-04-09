#!/usr/bin/env bash
set -euo pipefail

. "$(dirname "$0")/testlib.sh"

fake_tmux_no_sidebar

bash scripts/features/sidebar/notify-sidebar.sh

assert_file_not_contains "$TEST_TMUX_DATA_DIR/commands.log" 'split-window'

fake_tmux_no_sidebar
printf '1\n' > "$TEST_TMUX_DATA_DIR/option__tmux_sidebar_enabled.txt"

bash scripts/features/sidebar/notify-sidebar.sh

assert_eq "$?" "0"

fake_tmux_no_sidebar
export TMUX_PANE_TREE_STATE_DIR="$TEST_TMP/state"
mkdir -p "$TMUX_PANE_TREE_STATE_DIR"
fake_tmux_register_pane "%1" "work" "@1" "editor" "bash" "bash"
fake_tmux_register_pane "%99" "work" "@1" "editor" "Sidebar" "python3"
fake_tmux_register_pane "%88" "logs" "@2" "server" "Sidebar" "python3"
fake_tmux_set_pane_width "%99" "41"
fake_tmux_set_pane_width "%88" "25"
printf '1\n' > "$TEST_TMUX_DATA_DIR/option__tmux_sidebar_enabled.txt"

bash scripts/features/sidebar/notify-sidebar.sh %99

assert_eq "$(cat "$TEST_TMUX_DATA_DIR/option__tmux_pane_tree_width.txt")" "41"
assert_eq "$(cat "$TMUX_PANE_TREE_STATE_DIR/sidebar-width.txt")" "41"
assert_file_contains "$TEST_TMUX_DATA_DIR/commands.log" 'resize-pane -t %88 -x 41'

fake_tmux_no_sidebar
export TMUX_PANE_TREE_STATE_DIR="$TEST_TMP/state"
mkdir -p "$TMUX_PANE_TREE_STATE_DIR"
fake_tmux_register_pane "%1" "work" "@1" "editor" "bash" "bash"
fake_tmux_set_pane_width "%1" "60"
printf '1\n' > "$TEST_TMUX_DATA_DIR/option__tmux_sidebar_enabled.txt"

bash scripts/features/sidebar/notify-sidebar.sh %1

[ ! -f "$TEST_TMUX_DATA_DIR/option__tmux_pane_tree_width.txt" ] || fail "expected no persisted width for non-sidebar panes"
