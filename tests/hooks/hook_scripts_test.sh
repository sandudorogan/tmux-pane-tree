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
export TMUX_PANE_TREE_STATE_DIR="$TEST_TMP/hook-state"
mkdir -p "$TMUX_PANE_TREE_STATE_DIR"
fake_tmux_no_sidebar
fake_tmux_register_pane "%7" "work" "@1" "editor" "bash"

export TEST_HOOK_CAPTURE="$TEST_TMP/claude-hook.txt"
printf '%s' '{"hook_event_name":"Notification","message":"Need input"}' | bash scripts/features/hooks/hook-claude.sh
assert_file_contains "$TEST_HOOK_CAPTURE" '--app claude'
assert_file_contains "$TEST_HOOK_CAPTURE" '--status needs-input'
assert_file_contains "$TEST_HOOK_CAPTURE" '--pane %7'

export TEST_HOOK_CAPTURE="$TEST_TMP/claude-hook-idle-prompt.txt"
printf '%s' '{"hook_event_name":"Notification","notification_type":"idle_prompt"}' | bash scripts/features/hooks/hook-claude.sh
assert_file_contains "$TEST_HOOK_CAPTURE" '--status idle'

export TEST_HOOK_CAPTURE="$TEST_TMP/claude-hook-start.txt"
printf '%s' '{"hook_event_name":"SessionStart"}' | bash scripts/features/hooks/hook-claude.sh
assert_file_contains "$TEST_HOOK_CAPTURE" '--status idle'

export TEST_HOOK_CAPTURE="$TEST_TMP/claude-hook-submit.txt"
printf '%s' '{"hook_event_name":"UserPromptSubmit"}' | bash scripts/features/hooks/hook-claude.sh
assert_file_contains "$TEST_HOOK_CAPTURE" '--status running'

export TEST_HOOK_CAPTURE="$TEST_TMP/claude-hook-subagent-stop.txt"
rm -f "$TEST_HOOK_CAPTURE"
printf '%s' '{"hook_event_name":"SubagentStop","message":"Finished subagent task"}' | bash scripts/features/hooks/hook-claude.sh
[ ! -f "$TEST_HOOK_CAPTURE" ] || fail "claude subagent stop should be suppressed"

export TEST_HOOK_CAPTURE="$TEST_TMP/claude-hook-subagent-start.txt"
rm -f "$TEST_HOOK_CAPTURE"
printf '%s' '{"hook_event_name":"SubagentStart","message":"Delegating"}' | bash scripts/features/hooks/hook-claude.sh
[ ! -f "$TEST_HOOK_CAPTURE" ] || fail "claude subagent start should be suppressed"

export TEST_HOOK_CAPTURE="$TEST_TMP/claude-hook-stop.txt"
printf '%s' '{"hook_event_name":"Stop","message":"Finished task"}' | bash scripts/features/hooks/hook-claude.sh
assert_file_contains "$TEST_HOOK_CAPTURE" '--status done'

export TEST_HOOK_CAPTURE="$TEST_TMP/codex-hook.txt"
export TEST_PEON_CAPTURE="$TEST_TMP/peon-argv.txt"
export TEST_PEON_STDIN_CAPTURE="$TEST_TMP/peon-stdin.txt"
export TMUX_SIDEBAR_CODEX_NOTIFY_FORWARD="$capture_peon"
printf '%s' '{"summary":"Finished task"}' | bash scripts/features/hooks/hook-codex.sh agent-turn-complete
assert_file_contains "$TEST_HOOK_CAPTURE" '--app codex'
assert_file_contains "$TEST_HOOK_CAPTURE" '--status done'
assert_file_contains "$TEST_PEON_CAPTURE" 'agent-turn-complete'
assert_file_contains "$TEST_PEON_STDIN_CAPTURE" '"summary":"Finished task"'

export TEST_HOOK_CAPTURE="$TEST_TMP/codex-hook-delegate-complete.txt"
rm -f "$TEST_HOOK_CAPTURE"
printf '%s' '{"permission_mode":"delegate","summary":"Finished delegated task"}' | bash scripts/features/hooks/hook-codex.sh agent-turn-complete
[ ! -f "$TEST_HOOK_CAPTURE" ] || fail "codex delegate completion should be suppressed"
assert_file_contains "$TEST_PEON_CAPTURE" 'agent-turn-complete'
assert_file_contains "$TEST_PEON_STDIN_CAPTURE" '"permission_mode":"delegate"'

export TEST_HOOK_CAPTURE="$TEST_TMP/codex-hook-delegate-start.txt"
printf '%s' '{"session_id":"worker-9","permission_mode":"delegate","summary":"Starting delegated task"}' | bash scripts/features/hooks/hook-codex.sh task_started
assert_file_contains "$TEST_HOOK_CAPTURE" '--status running'

export TEST_HOOK_CAPTURE="$TEST_TMP/codex-hook-tracked-complete.txt"
rm -f "$TEST_HOOK_CAPTURE"
printf '%s' '{"session_id":"worker-9","summary":"Finished delegated task"}' | bash scripts/features/hooks/hook-codex.sh agent-turn-complete
[ ! -f "$TEST_HOOK_CAPTURE" ] || fail "codex tracked completion should be suppressed"

export TEST_HOOK_CAPTURE="$TEST_TMP/codex-hook-tracked-status-complete.txt"
rm -f "$TEST_HOOK_CAPTURE"
printf '%s' '{"session_id":"worker-9","status":"completed","summary":"Finished delegated task"}' | bash scripts/features/hooks/hook-codex.sh
[ ! -f "$TEST_HOOK_CAPTURE" ] || fail "codex tracked status completion should be suppressed"

export TEST_HOOK_CAPTURE="$TEST_TMP/codex-hook-tracked-permission-prompt.txt"
rm -f "$TEST_HOOK_CAPTURE"
printf '%s' '{"session_id":"worker-9","notification_type":"permission_prompt","message":"Need approval"}' | bash scripts/features/hooks/hook-codex.sh
[ ! -f "$TEST_HOOK_CAPTURE" ] || fail "codex tracked permission prompt should be suppressed"

export TEST_HOOK_CAPTURE="$TEST_TMP/codex-hook-json-arg.txt"
python3 - <<'PY'
import os
import subprocess
import sys

env = os.environ.copy()
proc = subprocess.Popen(
    ["bash", "scripts/features/hooks/hook-codex.sh", '{"type":"agent-turn-complete","summary":"Finished task"}'],
    stdin=subprocess.PIPE,
    stdout=subprocess.PIPE,
    stderr=subprocess.PIPE,
    text=True,
    env=env,
)
try:
    proc.wait(timeout=1)
except subprocess.TimeoutExpired:
    proc.kill()
    sys.exit("hook-codex hung with open stdin and JSON arg")
stdout, stderr = proc.communicate()
if proc.returncode != 0:
    sys.stderr.write(stdout)
    sys.stderr.write(stderr)
    sys.exit(proc.returncode)
PY
assert_file_contains "$TEST_HOOK_CAPTURE" '--status done'

export TEST_HOOK_CAPTURE="$TEST_TMP/codex-hook-input.txt"
printf '%s' '{"notification_type":"permission_prompt","message":"Need approval"}' | bash scripts/features/hooks/hook-codex.sh
assert_file_contains "$TEST_HOOK_CAPTURE" '--status needs-input'

export TEST_HOOK_CAPTURE="$TEST_TMP/codex-hook-idle-prompt.txt"
printf '%s' '{"notification_type":"idle_prompt"}' | bash scripts/features/hooks/hook-codex.sh
assert_file_contains "$TEST_HOOK_CAPTURE" '--status idle'

export TEST_HOOK_CAPTURE="$TEST_TMP/codex-hook-running-status.txt"
printf '%s' '{"status":"running"}' | bash scripts/features/hooks/hook-codex.sh
assert_file_contains "$TEST_HOOK_CAPTURE" '--status running'

export TEST_HOOK_CAPTURE="$TEST_TMP/codex-hook-task-started.txt"
printf '%s' '{"summary":"Starting work"}' | bash scripts/features/hooks/hook-codex.sh task_started
assert_file_contains "$TEST_HOOK_CAPTURE" '--status running'

export TEST_HOOK_CAPTURE="$TEST_TMP/codex-hook-noise-skipped.txt"
rm -f "$TEST_HOOK_CAPTURE"
printf '' | bash scripts/features/hooks/hook-codex.sh
[ ! -f "$TEST_HOOK_CAPTURE" ] || fail "empty codex events should be skipped"

rm -f "$TEST_HOOK_CAPTURE"
printf '%s' '{"summary":"Working"}' | bash scripts/features/hooks/hook-codex.sh
[ ! -f "$TEST_HOOK_CAPTURE" ] || fail "ambiguous codex events should be skipped"

export TEST_HOOK_CAPTURE="$TEST_TMP/codex-hook-session-start.txt"
printf '%s' '{"summary":"Ready"}' | bash scripts/features/hooks/hook-codex.sh session-start
assert_file_contains "$TEST_HOOK_CAPTURE" '--status idle'

export TEST_HOOK_CAPTURE="$TEST_TMP/opencode-hook.txt"
printf '%s' '{"event":"session.created","status":"ready","message":"Ready"}' | bash scripts/features/hooks/hook-opencode.sh
assert_file_contains "$TEST_HOOK_CAPTURE" '--app opencode'
assert_file_contains "$TEST_HOOK_CAPTURE" '--status idle'
assert_file_contains "$TEST_HOOK_CAPTURE" '--message Ready'

export TEST_HOOK_CAPTURE="$TEST_TMP/opencode-hook-input.txt"
printf '%s' '{"event":"permission.asked","message":"Need approval"}' | bash scripts/features/hooks/hook-opencode.sh
assert_file_contains "$TEST_HOOK_CAPTURE" '--status needs-input'

export TEST_HOOK_CAPTURE="$TEST_TMP/opencode-hook-running.txt"
printf '%s' '{"status":"running","message":"Working"}' | bash scripts/features/hooks/hook-opencode.sh
assert_file_contains "$TEST_HOOK_CAPTURE" '--status running'

export TEST_HOOK_CAPTURE="$TEST_TMP/opencode-hook-session-status.txt"
printf '%s' '{"event":"session.status","message":"Working"}' | bash scripts/features/hooks/hook-opencode.sh
assert_file_contains "$TEST_HOOK_CAPTURE" '--status running'

export TEST_HOOK_CAPTURE="$TEST_TMP/opencode-hook-session-idle.txt"
printf '%s' '{"event":"session.idle","message":"Ready"}' | bash scripts/features/hooks/hook-opencode.sh
assert_file_contains "$TEST_HOOK_CAPTURE" '--status done'

export TEST_HOOK_CAPTURE="$TEST_TMP/pi-hook.txt"
printf '%s' '{"event":"agent_start","message":"Working"}' | bash scripts/features/hooks/hook-pi.sh
assert_file_contains "$TEST_HOOK_CAPTURE" '--app pi'
assert_file_contains "$TEST_HOOK_CAPTURE" '--status running'
assert_file_contains "$TEST_HOOK_CAPTURE" '--message Working'

export TEST_HOOK_CAPTURE="$TEST_TMP/pi-hook-needs-input.txt"
printf '%s' '{"event":"needs_input","message":"Need approval"}' | bash scripts/features/hooks/hook-pi.sh
assert_file_contains "$TEST_HOOK_CAPTURE" '--status needs-input'

export TEST_HOOK_CAPTURE="$TEST_TMP/kiro-hook.txt"
printf '%s' '{"event":"agent_end","message":"Finished"}' | bash scripts/features/hooks/hook-kiro.sh
assert_file_contains "$TEST_HOOK_CAPTURE" '--app kiro'
assert_file_contains "$TEST_HOOK_CAPTURE" '--status done'
assert_file_contains "$TEST_HOOK_CAPTURE" '--message Finished'

export TEST_HOOK_CAPTURE="$TEST_TMP/cursor-hook-session-start.txt"
rm -f "$TEST_HOOK_CAPTURE"
printf '%s' '{"hook_event_name":"sessionStart","workspace_roots":["/work/project"],"agent_message":"Ready"}' | bash scripts/features/hooks/hook-cursor.sh || true
assert_file_contains "$TEST_HOOK_CAPTURE" '--app cursor'
assert_file_contains "$TEST_HOOK_CAPTURE" '--status idle'

fake_tmux_register_pane "%9" "work" "@1" "editor" "bash"
export TEST_HOOK_CAPTURE="$TEST_TMP/cursor-hook-explicit-pane.txt"
rm -f "$TEST_HOOK_CAPTURE"
printf '%s' '{"hook_event_name":"sessionStart","pane_id":"%9","workspace_roots":["/work/project"],"agent_message":"Ready"}' | bash scripts/features/hooks/hook-cursor.sh || true
assert_file_contains "$TEST_HOOK_CAPTURE" '--pane %9'

export TEST_HOOK_CAPTURE="$TEST_TMP/cursor-hook-session-end.txt"
rm -f "$TEST_HOOK_CAPTURE"
printf '%s' '{"hook_event_name":"sessionEnd","workspace_roots":["/work/project"],"agent_message":"Done"}' | bash scripts/features/hooks/hook-cursor.sh || true
assert_file_contains "$TEST_HOOK_CAPTURE" '--status idle'

export TEST_HOOK_CAPTURE="$TEST_TMP/cursor-hook-submit.txt"
rm -f "$TEST_HOOK_CAPTURE"
printf '%s' '{"hook_event_name":"beforeSubmitPrompt","workspace_roots":["/work/project"],"agent_message":"Starting"}' | bash scripts/features/hooks/hook-cursor.sh || true
assert_file_contains "$TEST_HOOK_CAPTURE" '--status running'

export TEST_HOOK_CAPTURE="$TEST_TMP/cursor-hook-subagent-start.txt"
rm -f "$TEST_HOOK_CAPTURE"
printf '%s' '{"hook_event_name":"subagentStart","workspace_roots":["/work/project"],"agent_message":"Delegating"}' | bash scripts/features/hooks/hook-cursor.sh
[ ! -f "$TEST_HOOK_CAPTURE" ] || fail "cursor subagent start should be suppressed"

export TEST_HOOK_CAPTURE="$TEST_TMP/cursor-hook-subagent-stop.txt"
rm -f "$TEST_HOOK_CAPTURE"
printf '%s' '{"hook_event_name":"subagentStop","workspace_roots":["/work/project"],"agent_message":"Subagent finished"}' | bash scripts/features/hooks/hook-cursor.sh || true
[ ! -f "$TEST_HOOK_CAPTURE" ] || fail "cursor subagent stop should be suppressed"

export TEST_HOOK_CAPTURE="$TEST_TMP/cursor-hook-stop-completed.txt"
rm -f "$TEST_HOOK_CAPTURE"
printf '%s' '{"hook_event_name":"stop","workspace_roots":["/work/project"],"status":"completed","agent_message":"Finished task"}' | bash scripts/features/hooks/hook-cursor.sh || true
assert_file_contains "$TEST_HOOK_CAPTURE" '--status done'

export TEST_HOOK_CAPTURE="$TEST_TMP/cursor-hook-stop-aborted.txt"
rm -f "$TEST_HOOK_CAPTURE"
printf '%s' '{"hook_event_name":"stop","workspace_roots":["/work/project"],"status":"aborted","agent_message":"Stopped"}' | bash scripts/features/hooks/hook-cursor.sh || true
assert_file_contains "$TEST_HOOK_CAPTURE" '--status idle'

export TEST_HOOK_CAPTURE="$TEST_TMP/cursor-hook-stop-error.txt"
rm -f "$TEST_HOOK_CAPTURE"
printf '%s' '{"hook_event_name":"stop","workspace_roots":["/work/project"],"status":"error","agent_message":"Crashed"}' | bash scripts/features/hooks/hook-cursor.sh || true
assert_file_contains "$TEST_HOOK_CAPTURE" '--status error'

export TEST_HOOK_CAPTURE="$TEST_TMP/cursor-hook-permission-denied.txt"
rm -f "$TEST_HOOK_CAPTURE"
printf '%s' '{"hook_event_name":"postToolUseFailure","workspace_roots":["/work/project"],"failure_type":"permission_denied","error_message":"Need approval"}' | bash scripts/features/hooks/hook-cursor.sh || true
assert_file_contains "$TEST_HOOK_CAPTURE" '--status needs-input'

export TEST_HOOK_CAPTURE="$TEST_TMP/cursor-hook-timeout.txt"
rm -f "$TEST_HOOK_CAPTURE"
printf '%s' '{"hook_event_name":"postToolUseFailure","workspace_roots":["/work/project"],"failure_type":"timeout","error_message":"Timed out"}' | bash scripts/features/hooks/hook-cursor.sh || true
assert_file_contains "$TEST_HOOK_CAPTURE" '--status error'

export TEST_HOOK_CAPTURE="$TEST_TMP/cursor-hook-failure.txt"
rm -f "$TEST_HOOK_CAPTURE"
printf '%s' '{"hook_event_name":"postToolUseFailure","workspace_roots":["/work/project"],"failure_type":"error","error_message":"Exploded"}' | bash scripts/features/hooks/hook-cursor.sh || true
assert_file_contains "$TEST_HOOK_CAPTURE" '--status error'
