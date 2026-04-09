#!/usr/bin/env bash
set -euo pipefail

. "$(dirname "$0")/testlib.sh"

plugin_dir="$TEST_TMP/plugin"
mkdir -p "$plugin_dir/scripts/features/hooks"

cat > "$plugin_dir/scripts/features/hooks/hook-claude.sh" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail
printf '%s\n' "${1:-}" > "${TEST_HOOK_ARGV_CAPTURE:?}"
cat > "${TEST_HOOK_STDIN_CAPTURE:?}"
EOF
chmod +x "$plugin_dir/scripts/features/hooks/hook-claude.sh"

cat > "$plugin_dir/scripts/features/hooks/hook-codex.sh" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail
printf '%s\n' "${1:-}" > "${TEST_HOOK_ARGV_CAPTURE:?}"
cat > "${TEST_HOOK_STDIN_CAPTURE:?}"
EOF
chmod +x "$plugin_dir/scripts/features/hooks/hook-codex.sh"

cat > "$plugin_dir/scripts/features/hooks/hook-pi.sh" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail
printf '%s\n' "${1:-}" > "${TEST_HOOK_ARGV_CAPTURE:?}"
cat > "${TEST_HOOK_STDIN_CAPTURE:?}"
EOF
chmod +x "$plugin_dir/scripts/features/hooks/hook-pi.sh"

cat > "$plugin_dir/scripts/features/hooks/hook-kiro.sh" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail
printf '%s\n' "${1:-}" > "${TEST_HOOK_ARGV_CAPTURE:?}"
cat > "${TEST_HOOK_STDIN_CAPTURE:?}"
EOF
chmod +x "$plugin_dir/scripts/features/hooks/hook-kiro.sh"

cat > "$plugin_dir/scripts/features/hooks/hook-opencode.sh" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail
printf '%s\n' "${1:-}" > "${TEST_HOOK_ARGV_CAPTURE:?}"
cat > "${TEST_HOOK_STDIN_CAPTURE:?}"
EOF
chmod +x "$plugin_dir/scripts/features/hooks/hook-opencode.sh"

cat > "$plugin_dir/scripts/features/hooks/hook-cursor.sh" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail
printf '%s\n' "${1:-}" > "${TEST_HOOK_ARGV_CAPTURE:?}"
cat > "${TEST_HOOK_STDIN_CAPTURE:?}"
EOF
chmod +x "$plugin_dir/scripts/features/hooks/hook-cursor.sh"

export TMUX_SIDEBAR_PLUGIN_DIR="$plugin_dir"

export TEST_HOOK_ARGV_CAPTURE="$TEST_TMP/claude-argv.txt"
export TEST_HOOK_STDIN_CAPTURE="$TEST_TMP/claude-stdin.json"
export CLAUDE_HOOK_EVENT_NAME="Notification"
export CLAUDE_NOTIFICATION_TYPE="idle_prompt"
export CLAUDE_NOTIFICATION_MESSAGE="Waiting"
bash examples/claude-hook.sh
assert_file_contains "$TEST_HOOK_STDIN_CAPTURE" '"hook_event_name":"Notification"'
assert_file_contains "$TEST_HOOK_STDIN_CAPTURE" '"notification_type":"idle_prompt"'
assert_file_contains "$TEST_HOOK_STDIN_CAPTURE" '"message":"Waiting"'
assert_eq "$(cat "$TEST_HOOK_ARGV_CAPTURE")" ""

export TEST_HOOK_ARGV_CAPTURE="$TEST_TMP/codex-argv.txt"
export TEST_HOOK_STDIN_CAPTURE="$TEST_TMP/codex-stdin.json"
export CODEX_EVENT="agent-turn-complete"
export CODEX_STATUS="completed"
export CODEX_MESSAGE="Finished task"
bash examples/codex-hook.sh
assert_file_contains "$TEST_HOOK_STDIN_CAPTURE" '"event":"agent-turn-complete"'
assert_file_contains "$TEST_HOOK_STDIN_CAPTURE" '"status":"completed"'
assert_file_contains "$TEST_HOOK_STDIN_CAPTURE" '"message":"Finished task"'
assert_eq "$(cat "$TEST_HOOK_ARGV_CAPTURE")" ""

export TEST_HOOK_ARGV_CAPTURE="$TEST_TMP/pi-argv.txt"
export TEST_HOOK_STDIN_CAPTURE="$TEST_TMP/pi-stdin.json"
export PI_EVENT="agent_start"
export PI_MESSAGE="Working"
bash examples/pi-hook.sh
assert_file_contains "$TEST_HOOK_STDIN_CAPTURE" '"event":"agent_start"'
assert_file_contains "$TEST_HOOK_STDIN_CAPTURE" '"message":"Working"'
assert_eq "$(cat "$TEST_HOOK_ARGV_CAPTURE")" ""

export TEST_HOOK_ARGV_CAPTURE="$TEST_TMP/kiro-argv.txt"
export TEST_HOOK_STDIN_CAPTURE="$TEST_TMP/kiro-stdin.json"
export KIRO_EVENT="stop"
export KIRO_MESSAGE="Finished"
bash examples/kiro-hook.sh
assert_file_contains "$TEST_HOOK_STDIN_CAPTURE" '"hook_event_name":"stop"'
assert_file_contains "$TEST_HOOK_STDIN_CAPTURE" '"message":"Finished"'
assert_eq "$(cat "$TEST_HOOK_ARGV_CAPTURE")" ""

export TEST_HOOK_ARGV_CAPTURE="$TEST_TMP/opencode-argv.txt"
export TEST_HOOK_STDIN_CAPTURE="$TEST_TMP/opencode-stdin.json"
export OPENCODE_EVENT="session-start"
export OPENCODE_STATUS="ready"
export OPENCODE_MESSAGE="Ready"
bash examples/opencode-hook.sh
assert_file_contains "$TEST_HOOK_STDIN_CAPTURE" '"event":"session-start"'
assert_file_contains "$TEST_HOOK_STDIN_CAPTURE" '"status":"ready"'
assert_file_contains "$TEST_HOOK_STDIN_CAPTURE" '"message":"Ready"'
assert_eq "$(cat "$TEST_HOOK_ARGV_CAPTURE")" ""

export TEST_HOOK_ARGV_CAPTURE="$TEST_TMP/cursor-argv.txt"
export TEST_HOOK_STDIN_CAPTURE="$TEST_TMP/cursor-stdin.json"
export CURSOR_HOOK_EVENT_NAME="postToolUseFailure"
export CURSOR_WORKSPACE_ROOTS="/tmp/project-a:/tmp/project-b"
export CURSOR_STATUS="error"
export CURSOR_FAILURE_TYPE="permission_denied"
export CURSOR_AGENT_MESSAGE="Need approval"
bash examples/cursor-hook.sh
assert_file_contains "$TEST_HOOK_STDIN_CAPTURE" '"hook_event_name":"postToolUseFailure"'
assert_file_contains "$TEST_HOOK_STDIN_CAPTURE" '"/tmp/project-a","/tmp/project-b"'
assert_file_contains "$TEST_HOOK_STDIN_CAPTURE" '"status":"error"'
assert_file_contains "$TEST_HOOK_STDIN_CAPTURE" '"failure_type":"permission_denied"'
assert_file_contains "$TEST_HOOK_STDIN_CAPTURE" '"agent_message":"Need approval"'
assert_eq "$(cat "$TEST_HOOK_ARGV_CAPTURE")" ""

relative_plugin_dir="$TEST_TMP/relative-plugin"
mkdir -p "$relative_plugin_dir/examples" \
  "$relative_plugin_dir/scripts/core" \
  "$relative_plugin_dir/scripts/features/hooks"
cp examples/claude-hook.sh "$relative_plugin_dir/examples/claude-hook.sh"
cp examples/codex-hook.sh "$relative_plugin_dir/examples/codex-hook.sh"
cp examples/pi-hook.sh "$relative_plugin_dir/examples/pi-hook.sh"
cp examples/kiro-hook.sh "$relative_plugin_dir/examples/kiro-hook.sh"
cp examples/cursor-hook.sh "$relative_plugin_dir/examples/cursor-hook.sh"
cp examples/opencode-hook.sh "$relative_plugin_dir/examples/opencode-hook.sh"
cp scripts/core/lib.sh "$relative_plugin_dir/scripts/core/lib.sh"
cat > "$relative_plugin_dir/scripts/features/hooks/hook-claude.sh" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail
printf '%s\n' "${1:-}" > "${TEST_HOOK_ARGV_CAPTURE:?}"
cat > "${TEST_HOOK_STDIN_CAPTURE:?}"
EOF
chmod +x "$relative_plugin_dir/scripts/features/hooks/hook-claude.sh"
cat > "$relative_plugin_dir/scripts/features/hooks/hook-codex.sh" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail
printf '%s\n' "${1:-}" > "${TEST_HOOK_ARGV_CAPTURE:?}"
cat > "${TEST_HOOK_STDIN_CAPTURE:?}"
EOF
chmod +x "$relative_plugin_dir/scripts/features/hooks/hook-codex.sh"
cat > "$relative_plugin_dir/scripts/features/hooks/hook-pi.sh" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail
printf '%s\n' "${1:-}" > "${TEST_HOOK_ARGV_CAPTURE:?}"
cat > "${TEST_HOOK_STDIN_CAPTURE:?}"
EOF
chmod +x "$relative_plugin_dir/scripts/features/hooks/hook-pi.sh"
cat > "$relative_plugin_dir/scripts/features/hooks/hook-kiro.sh" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail
printf '%s\n' "${1:-}" > "${TEST_HOOK_ARGV_CAPTURE:?}"
cat > "${TEST_HOOK_STDIN_CAPTURE:?}"
EOF
chmod +x "$relative_plugin_dir/scripts/features/hooks/hook-kiro.sh"
cat > "$relative_plugin_dir/scripts/features/hooks/hook-cursor.sh" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail
printf '%s\n' "${1:-}" > "${TEST_HOOK_ARGV_CAPTURE:?}"
cat > "${TEST_HOOK_STDIN_CAPTURE:?}"
EOF
chmod +x "$relative_plugin_dir/scripts/features/hooks/hook-cursor.sh"
cat > "$relative_plugin_dir/scripts/features/hooks/hook-opencode.sh" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail
printf '%s\n' "${1:-}" > "${TEST_HOOK_ARGV_CAPTURE:?}"
cat > "${TEST_HOOK_STDIN_CAPTURE:?}"
EOF
chmod +x "$relative_plugin_dir/scripts/features/hooks/hook-opencode.sh"

unset TMUX_PANE_TREE_PLUGIN_DIR
unset TMUX_SIDEBAR_PLUGIN_DIR
export TEST_HOOK_ARGV_CAPTURE="$TEST_TMP/claude-relative-argv.txt"
export TEST_HOOK_STDIN_CAPTURE="$TEST_TMP/claude-relative-stdin.json"
export CLAUDE_HOOK_EVENT_NAME="Notification"
export CLAUDE_NOTIFICATION_TYPE="relative"
export CLAUDE_NOTIFICATION_MESSAGE="From script path"
HOME="$TEST_TMP/fallback-home" bash "$relative_plugin_dir/examples/claude-hook.sh"
assert_file_contains "$TEST_HOOK_STDIN_CAPTURE" '"hook_event_name":"Notification"'
assert_file_contains "$TEST_HOOK_STDIN_CAPTURE" '"notification_type":"relative"'
assert_file_contains "$TEST_HOOK_STDIN_CAPTURE" '"message":"From script path"'
assert_eq "$(cat "$TEST_HOOK_ARGV_CAPTURE")" ""

export TEST_HOOK_ARGV_CAPTURE="$TEST_TMP/codex-relative-argv.txt"
export TEST_HOOK_STDIN_CAPTURE="$TEST_TMP/codex-relative-stdin.json"
export CODEX_EVENT="relative-codex"
export CODEX_STATUS="running"
export CODEX_MESSAGE="From script path"
HOME="$TEST_TMP/fallback-home" bash "$relative_plugin_dir/examples/codex-hook.sh"
assert_file_contains "$TEST_HOOK_STDIN_CAPTURE" '"event":"relative-codex"'
assert_file_contains "$TEST_HOOK_STDIN_CAPTURE" '"status":"running"'
assert_file_contains "$TEST_HOOK_STDIN_CAPTURE" '"message":"From script path"'
assert_eq "$(cat "$TEST_HOOK_ARGV_CAPTURE")" ""

export TEST_HOOK_ARGV_CAPTURE="$TEST_TMP/pi-relative-argv.txt"
export TEST_HOOK_STDIN_CAPTURE="$TEST_TMP/pi-relative-stdin.json"
export PI_EVENT="relative-pi"
export PI_MESSAGE="From script path"
HOME="$TEST_TMP/fallback-home" bash "$relative_plugin_dir/examples/pi-hook.sh"
assert_file_contains "$TEST_HOOK_STDIN_CAPTURE" '"event":"relative-pi"'
assert_file_contains "$TEST_HOOK_STDIN_CAPTURE" '"message":"From script path"'
assert_eq "$(cat "$TEST_HOOK_ARGV_CAPTURE")" ""

export TEST_HOOK_ARGV_CAPTURE="$TEST_TMP/kiro-relative-argv.txt"
export TEST_HOOK_STDIN_CAPTURE="$TEST_TMP/kiro-relative-stdin.json"
export KIRO_EVENT="relative-kiro"
export KIRO_MESSAGE="From script path"
HOME="$TEST_TMP/fallback-home" bash "$relative_plugin_dir/examples/kiro-hook.sh"
assert_file_contains "$TEST_HOOK_STDIN_CAPTURE" '"hook_event_name":"relative-kiro"'
assert_file_contains "$TEST_HOOK_STDIN_CAPTURE" '"message":"From script path"'
assert_eq "$(cat "$TEST_HOOK_ARGV_CAPTURE")" ""

export TEST_HOOK_ARGV_CAPTURE="$TEST_TMP/cursor-relative-argv.txt"
export TEST_HOOK_STDIN_CAPTURE="$TEST_TMP/cursor-relative-stdin.json"
export CURSOR_HOOK_EVENT_NAME="relative-cursor"
export CURSOR_WORKSPACE_ROOTS="/tmp/relative"
export CURSOR_STATUS="waiting"
export CURSOR_FAILURE_TYPE=""
export CURSOR_AGENT_MESSAGE="From script path"
HOME="$TEST_TMP/fallback-home" bash "$relative_plugin_dir/examples/cursor-hook.sh"
assert_file_contains "$TEST_HOOK_STDIN_CAPTURE" '"hook_event_name":"relative-cursor"'
assert_file_contains "$TEST_HOOK_STDIN_CAPTURE" '"/tmp/relative"'
assert_file_contains "$TEST_HOOK_STDIN_CAPTURE" '"status":"waiting"'
assert_file_contains "$TEST_HOOK_STDIN_CAPTURE" '"agent_message":"From script path"'
assert_eq "$(cat "$TEST_HOOK_ARGV_CAPTURE")" ""

export TEST_HOOK_ARGV_CAPTURE="$TEST_TMP/opencode-relative-argv.txt"
export TEST_HOOK_STDIN_CAPTURE="$TEST_TMP/opencode-relative-stdin.json"
export OPENCODE_EVENT="relative-opencode"
export OPENCODE_STATUS="ready"
export OPENCODE_MESSAGE="From script path"
HOME="$TEST_TMP/fallback-home" bash "$relative_plugin_dir/examples/opencode-hook.sh"
assert_file_contains "$TEST_HOOK_STDIN_CAPTURE" '"event":"relative-opencode"'
assert_file_contains "$TEST_HOOK_STDIN_CAPTURE" '"status":"ready"'
assert_file_contains "$TEST_HOOK_STDIN_CAPTURE" '"message":"From script path"'
assert_eq "$(cat "$TEST_HOOK_ARGV_CAPTURE")" ""
