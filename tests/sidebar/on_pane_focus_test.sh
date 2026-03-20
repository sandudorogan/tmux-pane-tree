#!/usr/bin/env bash
set -euo pipefail

. "$(dirname "$0")/testlib.sh"

export TMUX_SIDEBAR_STATE_DIR="$TEST_TMP/state"
mkdir -p "$TMUX_SIDEBAR_STATE_DIR"

fake_tmux_no_sidebar
fake_tmux_register_pane "%1" "work" "@1" "editor" "nvim"
fake_tmux_register_pane "%2" "work" "@1" "server" "bash" "bash"
printf '1\n' > "$TEST_TMUX_DATA_DIR/option__tmux_sidebar_enabled.txt"

bash scripts/features/sidebar/on-pane-focus.sh "%1" "@1"

assert_file_contains "$TEST_TMUX_DATA_DIR/commands.log" 'set-option -g @tmux_sidebar_main_pane %1'
assert_file_contains "$TEST_TMUX_DATA_DIR/commands.log" 'split-window -t %1 -h -b -d -f -l 25'

fake_tmux_no_sidebar
fake_tmux_register_pane "%1" "work" "@1" "editor" "nvim"

bash scripts/features/sidebar/on-pane-focus.sh "%1" "@1"

assert_file_not_contains "$TEST_TMUX_DATA_DIR/commands.log" 'split-window'

fake_tmux_no_sidebar
fake_tmux_register_pane "%1" "work" "@1" "editor" "nvim"
printf '1\n' > "$TEST_TMUX_DATA_DIR/option__tmux_sidebar_enabled.txt"

cat > "$TMUX_SIDEBAR_STATE_DIR/pane-%1.json" <<'EOF'
{"pane_id":"%1","app":"claude","status":"needs-input","updated_at":100}
EOF

bash scripts/features/sidebar/on-pane-focus.sh "%1" "@1"

assert_file_contains "$TMUX_SIDEBAR_STATE_DIR/pane-%1.json" '"status":"idle"'
assert_file_contains "$TEST_TMUX_DATA_DIR/commands.log" 'set-option -g @tmux_sidebar_main_pane %1'

fake_tmux_no_sidebar
fake_tmux_register_pane "%1" "work" "@1" "editor" "nvim"
printf '1\n' > "$TEST_TMUX_DATA_DIR/option__tmux_sidebar_enabled.txt"

cat > "$TMUX_SIDEBAR_STATE_DIR/pane-%1.json" <<'EOF'
{"pane_id":"%1","app":"claude","status":"running","updated_at":100}
EOF

bash scripts/features/sidebar/on-pane-focus.sh "%1" "@1"

assert_file_contains "$TMUX_SIDEBAR_STATE_DIR/pane-%1.json" '"status":"running"'

fake_tmux_no_sidebar
fake_tmux_register_pane "%6" "work" "@1" "editor" "codex --full-auto" "codex-aarch64-apple-darwin"
printf '1\n' > "$TEST_TMUX_DATA_DIR/option__tmux_sidebar_enabled.txt"

cat > "$TMUX_SIDEBAR_STATE_DIR/pane-%6.json" <<'EOF'
{"pane_id":"%6","app":"codex","status":"done","updated_at":100}
EOF

bash scripts/features/sidebar/on-pane-focus.sh "%6" "@1"

assert_file_contains "$TMUX_SIDEBAR_STATE_DIR/pane-%6.json" '"status":"idle"'

fake_tmux_no_sidebar
fake_tmux_register_pane "%90" "work" "@1" "editor" "Sidebar" "python3"
fake_tmux_add_sidebar_pane "%90" "@1"
printf '%%90\n' > "$TEST_TMUX_DATA_DIR/current_pane.txt"
printf '1\n' > "$TEST_TMUX_DATA_DIR/option__tmux_sidebar_enabled.txt"

bash scripts/features/sidebar/on-pane-focus.sh "%90" "@1"

assert_file_not_contains "$TEST_TMUX_DATA_DIR/commands.log" 'set-option -g @tmux_sidebar_main_pane %90'

fake_tmux_no_sidebar
fake_tmux_register_pane "%5" "work" "@1" "editor" "● project: done" "2.1.76"
printf '1\n' > "$TEST_TMUX_DATA_DIR/option__tmux_sidebar_enabled.txt"
rm -f "$TMUX_SIDEBAR_STATE_DIR/pane-%5.json"

bash scripts/features/sidebar/on-pane-focus.sh "%5" "@1"

assert_file_contains "$TMUX_SIDEBAR_STATE_DIR/pane-%5.json" '"status":"idle"'
assert_file_contains "$TMUX_SIDEBAR_STATE_DIR/pane-%5.json" '"app":"claude"'
