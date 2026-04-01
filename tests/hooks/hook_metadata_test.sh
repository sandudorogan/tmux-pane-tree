#!/usr/bin/env bash
set -euo pipefail

. "$(dirname "$0")/testlib.sh"

run_metadata() {
  HOOK_PAYLOAD="$2" python3 scripts/core/hook-metadata.py "$1" "${3:-}"
}

run_parser() {
  HOOK_PAYLOAD="$2" python3 scripts/core/hook-parser.py "$1" "${3:-}"
}

codex_delegate="$(run_metadata codex '{"session_id":"abc","permission_mode":"delegate","type":"agent-turn-complete"}')"
assert_contains "$codex_delegate" '"session_id":"abc"'
assert_contains "$codex_delegate" '"delegate_session":true'

claude_subagent="$(run_metadata claude '{"hook_event_name":"SubagentStop","session_id":"s1","message":"done"}')"
assert_contains "$claude_subagent" '"event":"SubagentStop"'
assert_contains "$claude_subagent" '"explicit_subagent_event":true'

claude_env_subagent="$(HOOK_PAYLOAD='' CLAUDE_HOOK_EVENT_NAME=SubagentStop python3 scripts/core/hook-metadata.py claude)"
assert_contains "$claude_env_subagent" '"event":"SubagentStop"'
assert_contains "$claude_env_subagent" '"explicit_subagent_event":true'

claude_subagent_start_status="$(run_parser claude '{"hook_event_name":"SubagentStart","message":"Delegating"}')"
assert_eq "$(printf '%s\n' "$claude_subagent_start_status" | sed -n '1p')" "running"

cursor_stop_completed_status="$(run_parser cursor '{"hook_event_name":"stop","status":"completed","agent_message":"Finished task"}' stop)"
assert_eq "$(printf '%s\n' "$cursor_stop_completed_status" | sed -n '1p')" "done"

codex_permission_prompt_status="$(run_parser codex '{"notification_type":"permission_prompt","message":"Need approval"}')"
assert_eq "$(printf '%s\n' "$codex_permission_prompt_status" | sed -n '1p')" "needs-input"

codex_positional_delegate="$(run_metadata codex '{"session_id":"abc","permission_mode":"delegate","summary":"Finished task"}' agent-turn-complete)"
assert_contains "$codex_positional_delegate" '"event":"agent-turn-complete"'
assert_contains "$codex_positional_delegate" '"session_id":"abc"'
assert_contains "$codex_positional_delegate" '"delegate_session":true'

cursor_subagent="$(run_metadata cursor '{"hook_event_name":"subagentStart","workspace_roots":["/work/project"]}')"
assert_contains "$cursor_subagent" '"event":"subagentStart"'
assert_contains "$cursor_subagent" '"explicit_subagent_event":true'
