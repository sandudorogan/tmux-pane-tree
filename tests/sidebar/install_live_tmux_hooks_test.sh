#!/usr/bin/env bash
set -euo pipefail

. "$(dirname "$0")/../testlib.sh"

REPO_ROOT="$(CDPATH= cd -- "$(dirname "$0")/../.." && pwd)"
HOME_DIR="$TEST_TMP/home"
PLUGIN_DST="$HOME_DIR/.config/tmux/plugins/tmux-pane-tree"
NORMALIZED_PLUGIN_DST="$(python3 -c 'from pathlib import Path; import sys; print(Path(sys.argv[1]))' "$PLUGIN_DST")"
TMUX_CONF="$HOME_DIR/.config/tmux/tmux.conf"
CLAUDE_SETTINGS="$HOME_DIR/.claude/settings.json"
CODEX_CONFIG="$HOME_DIR/.codex/config.toml"

fake_tmux_no_sidebar

mkdir -p "$(dirname "$TMUX_CONF")" "$(dirname "$CLAUDE_SETTINGS")" "$(dirname "$CODEX_CONFIG")"

cat > "$TMUX_CONF" <<'EOF'
run '~/.config/tmux/plugins/tpm/tpm'
source-file ~/.config/tmux/plugins/tmux-sidebar/sidebar.tmux
EOF

cat > "$CLAUDE_SETTINGS" <<'EOF'
{}
EOF

cat > "$CODEX_CONFIG" <<'EOF'
model = "gpt-5"
EOF

TMUX="fake-session" \
HOME="$HOME_DIR" \
PLUGIN_SRC="$REPO_ROOT" \
PLUGIN_DST="$PLUGIN_DST" \
TMUX_CONF="$TMUX_CONF" \
CLAUDE_SETTINGS="$CLAUDE_SETTINGS" \
CODEX_CONFIG="$CODEX_CONFIG" \
TIMESTAMP="20260320000000" \
bash "$REPO_ROOT/scripts/install-live.sh"

assert_file_contains "$TEST_TMUX_DATA_DIR/commands.log" "source-file $TMUX_CONF"
assert_file_contains "$TMUX_CONF" "source-file $NORMALIZED_PLUGIN_DST/tmux-pane-tree.tmux"
assert_file_not_contains "$TMUX_CONF" 'tmux-sidebar/sidebar.tmux'
