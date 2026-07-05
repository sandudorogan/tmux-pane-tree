#!/usr/bin/env bash
set -euo pipefail

. "$(dirname "$0")/testlib.sh"

export TMUX_SIDEBAR_STATE_DIR="$TEST_TMP/state"
fake_tmux_register_pane "%7" "work" "@2" "editor" "Claude"
printf '%%7\n' > "$TEST_TMUX_DATA_DIR/current_pane.txt"

bash scripts/features/state/update-pane-state.sh \
  --pane "%7" \
  --app claude \
  --status needs-input \
  --message "Permission request"

assert_file_contains "$TMUX_SIDEBAR_STATE_DIR/pane-%7.json" '"status":"needs-input"'
assert_file_contains "$TMUX_SIDEBAR_STATE_DIR/pane-%7.json" '"app":"claude"'
assert_file_contains "$TMUX_SIDEBAR_STATE_DIR/pane-%7.json" '"session_name":"work"'

bash scripts/features/state/update-pane-state.sh \
  --pane "%8" \
  --app codex \
  --status running \
  --message "Working"

assert_file_contains "$TMUX_SIDEBAR_STATE_DIR/pane-%8.json" '"pane_id":"%8"'
assert_file_contains "$TMUX_SIDEBAR_STATE_DIR/pane-%8.json" '"app":"codex"'
assert_file_contains "$TMUX_SIDEBAR_STATE_DIR/pane-%8.json" '"status":"running"'

bash scripts/features/state/update-pane-state.sh \
  --pane "" \
  --app codex \
  --status done \
  --message "Finished"

assert_file_contains "$TMUX_SIDEBAR_STATE_DIR/pane-%7.json" '"pane_id":"%7"'
assert_file_contains "$TMUX_SIDEBAR_STATE_DIR/pane-%7.json" '"app":"codex"'
assert_file_contains "$TMUX_SIDEBAR_STATE_DIR/pane-%7.json" '"status":"done"'

fail_bin="$TEST_TMP/fail-bin-update-pane-state"
mkdir -p "$fail_bin"
cat > "$fail_bin/mv" <<'EOF'
#!/usr/bin/env bash
exit 1
EOF
chmod +x "$fail_bin/mv"

fake_tmux_register_pane "%9" "work" "@3" "ops" "Claude"

if PATH="$fail_bin:$PATH" bash scripts/features/state/update-pane-state.sh \
  --pane "%9" \
  --app claude \
  --status running \
  --message "Fail the move"
then
  fail "update-pane-state should fail when mv fails"
fi

temp_state_count="$(find "$TMUX_SIDEBAR_STATE_DIR" -name '.pane-state.*' | wc -l | tr -d ' ')"
assert_eq "$temp_state_count" "0"

fake_tmux_register_pane "%10" "work" "@4" "agents" "Claude"

bash scripts/features/state/update-pane-state.sh \
  --pane "%10" \
  --app claude \
  --status running \
  --subagent-event start \
  --updated-at 300

assert_file_contains "$TMUX_SIDEBAR_STATE_DIR/pane-%10.json" '"status":"subagent-running"'
assert_file_contains "$TMUX_SIDEBAR_STATE_DIR/pane-%10.json" '"subagent_count":1'

bash scripts/features/state/update-pane-state.sh \
  --pane "%10" \
  --app claude \
  --status running \
  --subagent-event start \
  --updated-at 301

assert_file_contains "$TMUX_SIDEBAR_STATE_DIR/pane-%10.json" '"subagent_count":2'

bash scripts/features/state/update-pane-state.sh \
  --pane "%10" \
  --app claude \
  --status running \
  --subagent-event stop \
  --updated-at 302

assert_file_contains "$TMUX_SIDEBAR_STATE_DIR/pane-%10.json" '"status":"subagent-running"'
assert_file_contains "$TMUX_SIDEBAR_STATE_DIR/pane-%10.json" '"subagent_count":1'

bash scripts/features/state/update-pane-state.sh \
  --pane "%10" \
  --app claude \
  --status running \
  --subagent-event stop \
  --updated-at 303

assert_file_contains "$TMUX_SIDEBAR_STATE_DIR/pane-%10.json" '"status":"running"'
assert_file_contains "$TMUX_SIDEBAR_STATE_DIR/pane-%10.json" '"subagent_count":0'

bash scripts/features/state/update-pane-state.sh \
  --pane "%10" \
  --app claude \
  --status running \
  --subagent-event start \
  --updated-at 304

assert_file_contains "$TMUX_SIDEBAR_STATE_DIR/pane-%10.json" '"subagent_count":1'

bash scripts/features/state/update-pane-state.sh \
  --pane "%10" \
  --app claude \
  --status done \
  --updated-at 305

assert_file_contains "$TMUX_SIDEBAR_STATE_DIR/pane-%10.json" '"status":"done"'
assert_file_contains "$TMUX_SIDEBAR_STATE_DIR/pane-%10.json" '"subagent_count":0'
