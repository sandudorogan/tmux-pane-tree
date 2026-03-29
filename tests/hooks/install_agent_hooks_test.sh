#!/usr/bin/env bash
set -euo pipefail

. "$(dirname "$0")/../testlib.sh"

REPO_ROOT="$(CDPATH= cd -- "$(dirname "$0")/../.." && pwd)"
HOME_DIR="$TEST_TMP/home"
PLUGIN_DST="$HOME_DIR/.config/tmux/plugins/tmux-sidebar"
NORMALIZED_PLUGIN_DST="$(python3 -c 'from pathlib import Path; import sys; print(Path(sys.argv[1]))' "$PLUGIN_DST")"
CLAUDE_SETTINGS="$HOME_DIR/.claude/settings.json"
CODEX_CONFIG="$HOME_DIR/.codex/config.toml"
CURSOR_HOOKS="$HOME_DIR/.cursor/hooks.json"
EXPLICIT_OPENCODE_PLUGIN="$HOME_DIR/.config/opencode/plugins/tmux-pane-tree.js"

mkdir -p "$PLUGIN_DST" "$(dirname "$CLAUDE_SETTINGS")" "$(dirname "$CODEX_CONFIG")" "$(dirname "$CURSOR_HOOKS")"
cp -R "$REPO_ROOT"/. "$PLUGIN_DST"/

cat > "$CLAUDE_SETTINGS" <<'EOF'
{}
EOF

cat > "$CODEX_CONFIG" <<'EOF'
model = "gpt-5"
EOF

HOME="$HOME_DIR" \
PLUGIN_DST="$PLUGIN_DST" \
CURSOR_HOOKS="$CURSOR_HOOKS" \
OPENCODE_PLUGIN="$EXPLICIT_OPENCODE_PLUGIN" \
TIMESTAMP="20260320000000" \
bash "$REPO_ROOT/scripts/features/hooks/install-agent-hooks.sh"

assert_file_contains "$CLAUDE_SETTINGS" 'scripts/features/hooks/hook-claude.sh'
assert_file_contains "$CLAUDE_SETTINGS" '"SubagentStop"'
assert_file_contains "$CODEX_CONFIG" 'scripts/features/hooks/hook-codex.sh'
assert_file_contains "$CURSOR_HOOKS" "$NORMALIZED_PLUGIN_DST/scripts/features/hooks/hook-cursor.sh"
assert_file_contains "$CURSOR_HOOKS" '"sessionStart"'
assert_file_contains "$CURSOR_HOOKS" '"postToolUseFailure"'
assert_file_contains "$CURSOR_HOOKS" '"subagentStop"'
assert_file_contains "$EXPLICIT_OPENCODE_PLUGIN" 'scripts/features/hooks/hook-opencode.sh'
assert_file_contains "$EXPLICIT_OPENCODE_PLUGIN" 'properties?.status?.type'
assert_file_contains "$EXPLICIT_OPENCODE_PLUGIN" 'JSON.stringify'

BAD_CURSOR_HOOKS="$HOME_DIR/.cursor/bad-hooks.json"
cat > "$BAD_CURSOR_HOOKS" <<'EOF'
{"version":1,"hooks":[]}
EOF

if HOME="$HOME_DIR" \
  PLUGIN_DST="$PLUGIN_DST" \
  CURSOR_HOOKS="$BAD_CURSOR_HOOKS" \
  TIMESTAMP="20260320000001" \
  bash "$REPO_ROOT/scripts/features/hooks/install-agent-hooks.sh"
then
  fail "install-agent-hooks should reject non-object Cursor hooks"
fi

assert_file_contains "$BAD_CURSOR_HOOKS" '"hooks":[]'

DEFAULT_HOME_DIR="$TEST_TMP/default-home"
DEFAULT_PLUGIN_DST="$DEFAULT_HOME_DIR/.config/tmux/plugins/tmux-sidebar"
DEFAULT_CLAUDE_SETTINGS="$DEFAULT_HOME_DIR/.claude/settings.json"
DEFAULT_CODEX_CONFIG="$DEFAULT_HOME_DIR/.codex/config.toml"
DEFAULT_CURSOR_HOOKS="$DEFAULT_HOME_DIR/.cursor/hooks.json"
DEFAULT_OPENCODE_PLUGIN="$DEFAULT_HOME_DIR/.config/opencode/plugins/tmux-pane-tree.js"

mkdir -p "$DEFAULT_PLUGIN_DST" "$(dirname "$DEFAULT_CLAUDE_SETTINGS")" "$(dirname "$DEFAULT_CODEX_CONFIG")" "$(dirname "$DEFAULT_CURSOR_HOOKS")"
cp -R "$REPO_ROOT"/. "$DEFAULT_PLUGIN_DST"/

cat > "$DEFAULT_CLAUDE_SETTINGS" <<'EOF'
{}
EOF

cat > "$DEFAULT_CODEX_CONFIG" <<'EOF'
model = "gpt-5"
EOF

(
  unset OPENCODE_PLUGIN
  HOME="$DEFAULT_HOME_DIR" \
  PLUGIN_DST="$DEFAULT_PLUGIN_DST" \
  CLAUDE_SETTINGS="$DEFAULT_CLAUDE_SETTINGS" \
  CODEX_CONFIG="$DEFAULT_CODEX_CONFIG" \
  CURSOR_HOOKS="$DEFAULT_CURSOR_HOOKS" \
  TIMESTAMP="20260320000002" \
  bash "$REPO_ROOT/scripts/features/hooks/install-agent-hooks.sh"
)

[ -f "$DEFAULT_OPENCODE_PLUGIN" ] || fail "expected default OpenCode plugin at $DEFAULT_OPENCODE_PLUGIN"
assert_file_contains "$DEFAULT_OPENCODE_PLUGIN" 'scripts/features/hooks/hook-opencode.sh'
