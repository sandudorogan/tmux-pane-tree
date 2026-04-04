#!/usr/bin/env bash
set -euo pipefail

. "$(dirname "$0")/testlib.sh"

STATE_DIR="$TEST_TMP/state"
mkdir -p "$STATE_DIR"

run_filter() {
  TMUX_PANE_TREE_STATE_DIR="$STATE_DIR" \
  HOOK_METADATA_JSON="$1" \
  bash scripts/features/hooks/filter-agent-event.sh
}

run_filter_from_metadata() {
  local app="$1"
  local event="$2"
  local payload="$3"
  TMUX_PANE_TREE_STATE_DIR="$STATE_DIR" \
  HOOK_METADATA_JSON="$(HOOK_PAYLOAD="$payload" python3 scripts/core/hook-metadata.py "$app" "$event")" \
  bash scripts/features/hooks/filter-agent-event.sh
}

assert_eq "suppress" "$(run_filter '{"app":"claude","event":"SubagentStop","session_id":"sub-1","permission_mode":"","explicit_subagent_event":true,"delegate_session":false}')"
[ ! -e "$STATE_DIR/agent-hook-state.json" ] || fail "explicit claude subagent lifecycle should not create tracked session state"

assert_eq "allow" "$(run_filter '{"app":"claude","event":"Stop","session_id":"sub-1","permission_mode":"","explicit_subagent_event":false,"delegate_session":false}')"

assert_eq "suppress" "$(run_filter '{"app":"claude","event":"SubagentStart","session_id":"shared-1","permission_mode":"","explicit_subagent_event":true,"delegate_session":false}')"
assert_eq "suppress" "$(run_filter '{"app":"claude","event":"SubagentStop","session_id":"shared-1","permission_mode":"","explicit_subagent_event":true,"delegate_session":false}')"
assert_eq "allow" "$(run_filter '{"app":"claude","event":"Stop","session_id":"shared-1","permission_mode":"","explicit_subagent_event":false,"delegate_session":false}')"

assert_eq "allow" "$(run_filter '{"app":"claude","event":"Stop","session_id":"main-1","permission_mode":"","explicit_subagent_event":false,"delegate_session":false}')"
assert_eq "allow" "$(run_filter '{"app":"claude","event":"PermissionRequest","session_id":"main-1","permission_mode":"","explicit_subagent_event":false,"delegate_session":false}')"

assert_eq "allow" "$(run_filter '{"app":"codex","event":"agent-turn-start","session_id":"worker-1","permission_mode":"delegate","explicit_subagent_event":false,"delegate_session":true}')"
assert_file_contains "$STATE_DIR/agent-hook-state.json" '"codex:worker-1":'
assert_file_not_contains "$STATE_DIR/agent-hook-state.json" '"claude:sub-1":'

assert_eq "suppress" "$(run_filter_from_metadata codex agent-turn-complete '{"session_id":"worker-2","permission_mode":"delegate","summary":"Finished task"}')"
assert_file_contains "$STATE_DIR/agent-hook-state.json" '"codex:worker-2":'

assert_eq "suppress" "$(run_filter '{"app":"codex","event":"agent-turn-complete","session_id":"worker-1","permission_mode":"delegate","explicit_subagent_event":false,"delegate_session":true}')"
assert_eq "suppress" "$(run_filter '{"app":"codex","event":"PermissionRequest","session_id":"worker-1","permission_mode":"delegate","explicit_subagent_event":false,"delegate_session":true}')"

assert_eq "allow" "$(run_filter_from_metadata codex task_started '{"session_id":"worker-3","permission_mode":"delegate","summary":"Starting delegated task"}')"
assert_eq "suppress" "$(run_filter_from_metadata codex '' '{"session_id":"worker-3","status":"completed","summary":"Finished delegated task"}')"

assert_eq "allow" "$(run_filter_from_metadata codex task_started '{"session_id":"worker-4","permission_mode":"delegate","summary":"Starting delegated task"}')"
assert_eq "suppress" "$(run_filter_from_metadata codex '' '{"session_id":"worker-4","notification_type":"permission_prompt","message":"Need approval"}')"

CONCURRENT_STATE_DIR="$TEST_TMP/concurrent-state"
mkdir -p "$CONCURRENT_STATE_DIR"

STATE_DIR="$CONCURRENT_STATE_DIR" python3 - <<'PY'
from __future__ import annotations

import json
import os
import subprocess
import sys

state_dir = os.environ["STATE_DIR"]
payloads = [
    {
        "app": "codex",
        "event": "agent-turn-start",
        "session_id": f"worker-{index}",
        "permission_mode": "delegate",
        "explicit_subagent_event": False,
        "delegate_session": True,
    }
    for index in range(8)
]
env = os.environ.copy()
env["TMUX_PANE_TREE_STATE_DIR"] = state_dir
procs = []
for payload in payloads:
    proc_env = env.copy()
    proc_env["HOOK_METADATA_JSON"] = json.dumps(payload, separators=(",", ":"))
    procs.append(
        subprocess.Popen(
            ["bash", "scripts/features/hooks/filter-agent-event.sh"],
            env=proc_env,
            stdout=subprocess.PIPE,
            stderr=subprocess.PIPE,
            text=True,
        )
    )

outputs = []
for proc in procs:
    stdout, stderr = proc.communicate()
    if proc.returncode != 0:
        sys.stderr.write(stdout)
        sys.stderr.write(stderr)
        sys.exit(proc.returncode)
    outputs.append(stdout.strip())

if any(output != "allow" for output in outputs):
    sys.exit(f"unexpected filter outputs: {outputs!r}")
PY

for index in 0 1 2 3 4 5 6 7; do
  assert_file_contains "$CONCURRENT_STATE_DIR/agent-hook-state.json" "\"codex:worker-$index\":"
done
