#!/usr/bin/env bash
set -euo pipefail

. "$(dirname "$0")/testlib.sh"

fake_tmux_no_sidebar
fake_tmux_register_pane "%1" "session1" "@1" "editor" "nvim"
fake_tmux_set_tree <<'EOF'
session1|@1|editor|%1|nvim|shell|1
session2|@2|logs|%2|tail|tail|0
EOF

bash scripts/features/sessions/add-session.sh --pane "%1" --name "my-session"

assert_file_contains "$TEST_TMUX_DATA_DIR/commands.log" 'new-session -d -s my-session'
assert_eq "$(cat "$TEST_TMUX_DATA_DIR/option__tmux_pane_tree_session_order.txt")" 'session1,my-session,session2'

fake_tmux_no_sidebar
fake_tmux_register_pane "%1" "session1" "@1" "editor" "nvim"
fake_tmux_set_tree <<'EOF'
session1|@1|editor|%1|nvim|shell|1
session2|@2|logs|%2|tail|tail|0
session3|@3|misc|%3|bash|bash|0
EOF
printf 'session2,session1,session3\n' > "$TEST_TMUX_DATA_DIR/option__tmux_sidebar_session_order.txt"

bash scripts/features/sessions/add-session.sh --pane "%1" --name "my-session"

assert_eq "$(cat "$TEST_TMUX_DATA_DIR/option__tmux_pane_tree_session_order.txt")" 'session2,session1,my-session,session3'

fake_tmux_no_sidebar
fake_tmux_register_pane "%1" "session1" "@1" "editor" "nvim"

bash scripts/features/sessions/add-session.sh --pane "%1" --name ""

assert_file_not_contains "$TEST_TMUX_DATA_DIR/commands.log" 'new-session'

fake_tmux_no_sidebar
fake_tmux_register_pane "%1" "session1" "@1" "editor" "nvim"
fake_tmux_set_tree <<'EOF'
session1|@1|editor|%1|nvim|shell|1
session2|@2|logs|%2|tail|tail|0
session3|@3|misc|%3|bash|bash|0
EOF
printf 'session2,session1,session3\n' > "$TEST_TMUX_DATA_DIR/option__tmux_sidebar_session_order.txt"
printf 'session3,session1,session2\n' > "$TEST_TMUX_DATA_DIR/option__tmux_pane_tree_session_order.txt"

bash scripts/features/sessions/add-session.sh --pane "%1" --name "my-session"

assert_eq "$(cat "$TEST_TMUX_DATA_DIR/option__tmux_pane_tree_session_order.txt")" 'session3,session1,my-session,session2'

fake_tmux_no_sidebar
fake_tmux_register_pane "%1" "session1" "@1" "editor" "nvim"
fake_tmux_set_tree <<'EOF'
session1|@1|editor|%1|nvim|shell|1
session2|@2|logs|%2|tail|tail|0
session3|@3|misc|%3|bash|bash|0
EOF
printf 'session2,session1,session3\n' > "$TEST_TMUX_DATA_DIR/option__tmux_pane_tree_session_order.txt"

bash scripts/features/sessions/add-session.sh --pane "%1" --name "my-session"

assert_eq "$(cat "$TEST_TMUX_DATA_DIR/option__tmux_pane_tree_session_order.txt")" 'session2,session1,my-session,session3'
