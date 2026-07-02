#!/usr/bin/env bash
set -euo pipefail

. "$(dirname "$0")/testlib.sh"

unset TMUX_SIDEBAR_STATE_DIR
unset TMUX_PANE_TREE_STATE_DIR
unset XDG_STATE_HOME

fake_tmux_no_sidebar
fake_tmux_register_pane "%20" "work" "@1" "editor" "bash" "bash" "0" "/work/proj-a"
fake_tmux_register_pane "%21" "work" "@1" "editor" "bash" "bash" "0" "/work/proj-b"
printf '%%21\n' > "$TEST_TMUX_DATA_DIR/current_pane.txt"

export TMUX_PANE="%21"
output="$(bash scripts/core/lib.sh resolve_agent_target_pane "%20" 2>&1 || true)"
assert_eq "$output" "%20"

output="$(bash scripts/core/lib.sh resolve_agent_target_pane "" 2>&1 || true)"
assert_eq "$output" "%21"

unset TMUX_PANE
output="$(bash scripts/core/lib.sh resolve_agent_target_pane "" "/missing" "/work/proj-b" 2>&1 || true)"
assert_eq "$output" "%21"

output="$(bash scripts/core/lib.sh resolve_agent_target_pane "" "/no-match" 2>&1 || true)"
assert_eq "$output" ""

printf 'legacy-width\n' > "$TEST_TMUX_DATA_DIR/option__tmux_sidebar_width.txt"
printf 'new-width\n' > "$TEST_TMUX_DATA_DIR/option__tmux_pane_tree_width.txt"
run_script scripts/core/lib.sh get_pane_tree_option width
assert_eq "$output" "new-width"

rm -f "$TEST_TMUX_DATA_DIR/option__tmux_pane_tree_width.txt"
run_script scripts/core/lib.sh get_pane_tree_option width
assert_eq "$output" "legacy-width"

run_script scripts/core/lib.sh set_pane_tree_option session_order "alpha,beta"
assert_eq "$(cat "$TEST_TMUX_DATA_DIR/option__tmux_pane_tree_session_order.txt")" "alpha,beta"

run_script scripts/core/lib.sh print_state_dir
assert_eq "$output" "$HOME/.local/state/tmux-sidebar"

export TMUX_PANE_TREE_STATE_DIR="/tmp/pane-tree-state-override"
export TMUX_SIDEBAR_STATE_DIR="/tmp/sidebar-state-override"
run_script scripts/core/lib.sh print_state_dir
assert_eq "$output" "/tmp/pane-tree-state-override"
unset TMUX_PANE_TREE_STATE_DIR
unset TMUX_SIDEBAR_STATE_DIR

export TMUX_SIDEBAR_STATE_DIR="/tmp/only-legacy-state"
unset TMUX_PANE_TREE_STATE_DIR
run_script scripts/core/lib.sh print_state_dir
assert_eq "$output" "/tmp/only-legacy-state"
unset TMUX_SIDEBAR_STATE_DIR

export XDG_STATE_HOME="/tmp/xdg-state-test"
run_script scripts/core/lib.sh print_state_dir
assert_eq "$output" "/tmp/xdg-state-test/tmux-sidebar"

export XDG_STATE_HOME=''
run_script scripts/core/lib.sh print_state_dir
assert_eq "$output" "$HOME/.local/state/tmux-sidebar"

unset XDG_STATE_HOME

export TMUX_PANE_TREE_STATE_DIR="$TEST_TMP/state"
mkdir -p "$TMUX_PANE_TREE_STATE_DIR"

run_script scripts/core/lib.sh read_persisted_sidebar_width
assert_eq "$output" ""

run_script scripts/core/lib.sh write_persisted_sidebar_width 37
assert_eq "$(cat "$TMUX_PANE_TREE_STATE_DIR/sidebar-width.txt")" "37"

run_script scripts/core/lib.sh read_persisted_sidebar_width
assert_eq "$output" "37"

state_dir="$TEST_TMP/lib-state"
mkdir -p "$state_dir"

cat > "$state_dir/pane-%31.json" <<'EOF'
{"pane_id":"%31","app":"claude","status":"needs-input","updated_at":100}
EOF

fail_bin="$TEST_TMP/fail-bin-lib"
mkdir -p "$fail_bin"
cat > "$fail_bin/sed" <<'EOF'
#!/usr/bin/env bash
exit 1
EOF
chmod +x "$fail_bin/sed"

(
  PATH="$fail_bin:$PATH"
  . scripts/core/lib.sh
  clear_terminal_pane_state "$state_dir/pane-%31.json"
) >/dev/null 2>&1 || true

assert_file_contains "$state_dir/pane-%31.json" '"status":"needs-input"'
temp_state_count="$(find "$state_dir" -name '.pane-state.*' | wc -l | tr -d ' ')"
assert_eq "$temp_state_count" "0"

invalid_pid_file="$state_dir/sidebar-invalid.pid"
stale_pid_file="$state_dir/sidebar-stale.pid"
live_pid_file="$state_dir/sidebar-live.pid"
printf 'abc\n' > "$invalid_pid_file"
(
  trap '' USR1
  sleep 30
) &
live_pid="$!"
trap 'kill "$live_pid" 2>/dev/null || true' EXIT
printf '%s\n' "$live_pid" > "$live_pid_file"

(
  sleep 1
) &
stale_pid="$!"
wait "$stale_pid"
printf '%s\n' "$stale_pid" > "$stale_pid_file"

export TMUX_PANE_TREE_STATE_DIR="$state_dir"
. scripts/core/lib.sh
signal_sidebar_refresh

[ ! -f "$invalid_pid_file" ] || fail "expected invalid pid file to be removed"
[ ! -f "$stale_pid_file" ] || fail "expected stale pid file to be removed"
[ -f "$live_pid_file" ] || fail "expected live pid file to remain"
kill -0 "$live_pid" 2>/dev/null || fail "expected live pid to still exist"

(
  . scripts/core/lib.sh
  for cmd in python python3 python3.11 fish bash zsh sh dash ksh tcsh csh FISH Bash; do
    is_sidebar_pane_command "$cmd" || exit 1
  done
  for cmd in nvim codex codex-aarch64-apple-darwin "" cursor-aarch64-apple-darwin; do
    if is_sidebar_pane_command "$cmd"; then exit 1; fi
  done
  is_sidebar_pane "Sidebar" "fish" || exit 1
  is_sidebar_pane "Sidebar" "python3" || exit 1
  is_sidebar_pane "tmux-sidebar" "bash" || exit 1
  if is_sidebar_pane "editor" "fish"; then exit 1; fi
  if is_sidebar_pane "Sidebar" "codex-aarch64-apple-darwin"; then exit 1; fi
) || fail "is_sidebar_pane_command/is_sidebar_pane allowlist mismatch"

fake_tmux_no_sidebar
fake_tmux_register_pane "%1" "work" "@1" "editor" "nvim"
fake_tmux_add_sidebar_pane "%90" "@1"

run_script scripts/core/lib.sh list_sidebar_panes_in_window "@1"
assert_eq "$output" "%90|@1"

run_script scripts/core/lib.sh list_sidebar_panes
assert_eq "$output" "%90|@1"
