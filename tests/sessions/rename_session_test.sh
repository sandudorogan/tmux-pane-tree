#!/usr/bin/env bash
set -euo pipefail

. "$(dirname "$0")/testlib.sh"

fake_tmux_no_sidebar
fake_tmux_register_pane "%1" "session1" "@1" "editor" "nvim"
printf 'session2,session1,session3\n' > "$TEST_TMUX_DATA_DIR/option__tmux_sidebar_session_order.txt"

bash scripts/features/sessions/rename-session.sh --pane "%1" --name "renamed-session"

assert_file_contains "$TEST_TMUX_DATA_DIR/commands.log" 'rename-session -t session1 renamed-session'
assert_eq "$(cat "$TEST_TMUX_DATA_DIR/option__tmux_pane_tree_session_order.txt")" 'session2,renamed-session,session3'

fake_tmux_no_sidebar
fake_tmux_register_pane "%1" "session1" "@1" "editor" "nvim"

bash scripts/features/sessions/rename-session.sh --pane "%1" --name ""

assert_file_not_contains "$TEST_TMUX_DATA_DIR/commands.log" 'rename-session'

fake_tmux_no_sidebar
fake_tmux_register_pane "%1" "session1" "@1" "editor" "nvim"
printf 'session2,session1,session3\n' > "$TEST_TMUX_DATA_DIR/option__tmux_pane_tree_session_order.txt"

bash scripts/features/sessions/rename-session.sh --pane "%1" --name "renamed-session"

assert_file_contains "$TEST_TMUX_DATA_DIR/commands.log" 'rename-session -t session1 renamed-session'
assert_eq "$(cat "$TEST_TMUX_DATA_DIR/option__tmux_pane_tree_session_order.txt")" 'session2,renamed-session,session3'

fake_tmux_no_sidebar
fake_tmux_register_pane "%1" "session1" "@1" "editor" "nvim"
printf 'session2,session1,session3\n' > "$TEST_TMUX_DATA_DIR/option__tmux_sidebar_session_order.txt"
printf 'session3,session1,session2\n' > "$TEST_TMUX_DATA_DIR/option__tmux_pane_tree_session_order.txt"

bash scripts/features/sessions/rename-session.sh --pane "%1" --name "renamed-session"

assert_file_contains "$TEST_TMUX_DATA_DIR/commands.log" 'rename-session -t session1 renamed-session'
assert_eq "$(cat "$TEST_TMUX_DATA_DIR/option__tmux_pane_tree_session_order.txt")" 'session3,renamed-session,session2'
