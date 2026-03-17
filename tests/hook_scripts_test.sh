#!/usr/bin/env bash
set -euo pipefail

. "$(dirname "$0")/testlib.sh"

capture_helper="$TEST_TMP/capture-helper.sh"
cat > "$capture_helper" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail
printf '%s\n' "$*" > "${TEST_HOOK_CAPTURE:?}"
EOF
chmod +x "$capture_helper"

capture_peon="$TEST_TMP/capture-peon.sh"
cat > "$capture_peon" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail
printf '%s\n' "${1:-}" > "${TEST_PEON_CAPTURE:?}"
if [ ! -t 0 ]; then
  cat > "${TEST_PEON_STDIN_CAPTURE:?}"
fi
EOF
chmod +x "$capture_peon"

export TMUX_PANE="%7"
export TMUX_SIDEBAR_UPDATE_HELPER="$capture_helper"

export TEST_HOOK_CAPTURE="$TEST_TMP/claude-hook.txt"
printf '%s' '{"hook_event_name":"Notification","message":"Need input"}' | bash scripts/hook-claude.sh
assert_file_contains "$TEST_HOOK_CAPTURE" '--app claude'
assert_file_contains "$TEST_HOOK_CAPTURE" '--status needs-input'
assert_file_contains "$TEST_HOOK_CAPTURE" '--pane %7'

export TEST_HOOK_CAPTURE="$TEST_TMP/claude-hook-idle-prompt.txt"
printf '%s' '{"hook_event_name":"Notification","notification_type":"idle_prompt"}' | bash scripts/hook-claude.sh
assert_file_contains "$TEST_HOOK_CAPTURE" '--status idle'

export TEST_HOOK_CAPTURE="$TEST_TMP/claude-hook-start.txt"
printf '%s' '{"hook_event_name":"SessionStart"}' | bash scripts/hook-claude.sh
assert_file_contains "$TEST_HOOK_CAPTURE" '--status idle'

export TEST_HOOK_CAPTURE="$TEST_TMP/claude-hook-submit.txt"
printf '%s' '{"hook_event_name":"UserPromptSubmit"}' | bash scripts/hook-claude.sh
assert_file_contains "$TEST_HOOK_CAPTURE" '--status running'

export TEST_HOOK_CAPTURE="$TEST_TMP/codex-hook.txt"
export TEST_PEON_CAPTURE="$TEST_TMP/peon-argv.txt"
export TEST_PEON_STDIN_CAPTURE="$TEST_TMP/peon-stdin.txt"
export TMUX_SIDEBAR_CODEX_NOTIFY_FORWARD="$capture_peon"
printf '%s' '{"summary":"Finished task"}' | bash scripts/hook-codex.sh agent-turn-complete
assert_file_contains "$TEST_HOOK_CAPTURE" '--app codex'
assert_file_contains "$TEST_HOOK_CAPTURE" '--status done'
assert_file_contains "$TEST_PEON_CAPTURE" 'agent-turn-complete'
assert_file_contains "$TEST_PEON_STDIN_CAPTURE" '"summary":"Finished task"'

export TEST_HOOK_CAPTURE="$TEST_TMP/codex-hook-json-arg.txt"
bash scripts/hook-codex.sh '{"type":"agent-turn-complete","summary":"Finished task"}'
assert_file_contains "$TEST_HOOK_CAPTURE" '--status done'

export TEST_HOOK_CAPTURE="$TEST_TMP/codex-hook-input.txt"
printf '%s' '{"notification_type":"permission_prompt","message":"Need approval"}' | bash scripts/hook-codex.sh
assert_file_contains "$TEST_HOOK_CAPTURE" '--status needs-input'

export TEST_HOOK_CAPTURE="$TEST_TMP/codex-hook-idle-prompt.txt"
printf '%s' '{"notification_type":"idle_prompt"}' | bash scripts/hook-codex.sh
assert_file_contains "$TEST_HOOK_CAPTURE" '--status idle'

export TEST_HOOK_CAPTURE="$TEST_TMP/codex-hook-running-status.txt"
printf '%s' '{"status":"running"}' | bash scripts/hook-codex.sh
assert_file_contains "$TEST_HOOK_CAPTURE" '--status running'

export TEST_HOOK_CAPTURE="$TEST_TMP/codex-hook-noise-skipped.txt"
rm -f "$TEST_HOOK_CAPTURE"
printf '' | bash scripts/hook-codex.sh
[ ! -f "$TEST_HOOK_CAPTURE" ] || fail "empty codex events should be skipped"

rm -f "$TEST_HOOK_CAPTURE"
printf '%s' '{"summary":"Working"}' | bash scripts/hook-codex.sh
[ ! -f "$TEST_HOOK_CAPTURE" ] || fail "ambiguous codex events should be skipped"

rm -f "$TEST_HOOK_CAPTURE"
printf '%s' '{"summary":"Ready"}' | bash scripts/hook-codex.sh session-start
[ ! -f "$TEST_HOOK_CAPTURE" ] || fail "session-start noise should be skipped"
