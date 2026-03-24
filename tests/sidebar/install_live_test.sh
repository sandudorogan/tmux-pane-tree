#!/usr/bin/env bash
set -euo pipefail

. "$(dirname "$0")/../testlib.sh"

REPO_ROOT="$(CDPATH= cd -- "$(dirname "$0")/../.." && pwd)"
HOME_DIR="$TEST_TMP/home"
PLUGIN_DST="$HOME_DIR/.config/tmux/plugins/tmux-sidebar"
NORMALIZED_PLUGIN_DST="$(python3 -c 'from pathlib import Path; import sys; print(Path(sys.argv[1]))' "$PLUGIN_DST")"
TMUX_CONF="$HOME_DIR/.config/tmux/tmux.conf"
CLAUDE_SETTINGS="$HOME_DIR/.claude/settings.json"
CODEX_CONFIG="$HOME_DIR/.codex/config.toml"
OPENCODE_PLUGIN="$HOME_DIR/.config/opencode/plugins/tmux-sidebar.js"

mkdir -p "$(dirname "$TMUX_CONF")" "$(dirname "$CLAUDE_SETTINGS")" "$(dirname "$CODEX_CONFIG")"

cat > "$TMUX_CONF" <<'EOF'
run '~/.config/tmux/plugins/tpm/tpm'
run-shell '~/.config/tmux/plugins/tmux-sidebar/sidebar.tmux'
EOF

cat > "$CLAUDE_SETTINGS" <<'EOF'
{}
EOF

cat > "$CODEX_CONFIG" <<'EOF'
model = "gpt-5"
EOF

TMUX="" \
HOME="$HOME_DIR" \
PLUGIN_SRC="$REPO_ROOT" \
PLUGIN_DST="$PLUGIN_DST" \
TMUX_CONF="$TMUX_CONF" \
CLAUDE_SETTINGS="$CLAUDE_SETTINGS" \
CODEX_CONFIG="$CODEX_CONFIG" \
TIMESTAMP="20260320000000" \
bash "$REPO_ROOT/scripts/install-live.sh"

assert_file_contains "$PLUGIN_DST/sidebar.tmux" 'scripts/features/context-menu/bind-context-menu.sh'
assert_file_contains "$TMUX_CONF" "source-file $NORMALIZED_PLUGIN_DST/sidebar.tmux"
assert_file_not_contains "$TMUX_CONF" "run-shell '$NORMALIZED_PLUGIN_DST/sidebar.tmux'"
assert_file_not_contains "$TMUX_CONF" "run-shell '~/.config/tmux/plugins/tmux-sidebar/sidebar.tmux'"
assert_file_contains "$CLAUDE_SETTINGS" 'scripts/features/hooks/hook-claude.sh'
assert_file_contains "$CODEX_CONFIG" 'scripts/features/hooks/hook-codex.sh'
assert_file_contains "$OPENCODE_PLUGIN" 'examples/opencode-hook.sh'
