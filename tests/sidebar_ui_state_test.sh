#!/usr/bin/env bash
set -euo pipefail

. "$(dirname "$0")/testlib.sh"

export TMUX_SIDEBAR_STATE_DIR="$TEST_TMP/state"
mkdir -p "$TMUX_SIDEBAR_STATE_DIR"

fake_tmux_set_tree <<'EOF'
work|@1|editor|%1|nvim|shell|0
work|@1|editor|%2|claude|claude|1
work|@1|editor|%99|python3|Sidebar|0
ops|@3|logs|%9|tail|tail|0
solo|@5|sidebar-only|%77|python3|Sidebar|0
EOF

output="$(python3 scripts/sidebar-ui.py --dump-render 2>&1)"

case "$output" in
  *'invalid option:'* ) fail "sidebar UI should not leak tmux stderr for missing options" ;;
esac

fake_tmux_register_main_pane "%9"

output="$(python3 scripts/sidebar-ui.py --dump-render 2>&1)"

assert_contains "$output" '├─ work'
assert_contains "$output" '│     └─ claude'
assert_contains "$output" '▶ │     └─ tail'
case "$output" in
  *'%99 Sidebar'* ) fail "sidebar pane should be hidden when window has other panes" ;;
esac
assert_contains "$output" '└─ solo'
assert_contains "$output" 'python3'

fake_tmux_set_tree <<'EOF'
work|@1|editor|%1|nvim|shell|0
work|@1|editor|%99|python3|tmux-sidebar|0
EOF

output="$(python3 scripts/sidebar-ui.py --dump-render 2>&1)"

case "$output" in
  *'%99 tmux-sidebar'* ) fail "legacy sidebar pane titles should still be hidden when window has other panes" ;;
esac

fake_tmux_set_tree <<'EOF'
work|@1|editor|%3|codex-aarch64-apple-darwin|codex-aarch64-apple-darwin|1
EOF
rm -f "$TMUX_SIDEBAR_STATE_DIR"/pane-*.json

output="$(python3 scripts/sidebar-ui.py --dump-render 2>&1)"

assert_contains "$output" 'codex'
case "$output" in
  *'codex-aarch64-apple-darwin'* ) fail "codex target-triple binary names should normalize to codex" ;;
esac

fake_tmux_set_tree <<'EOF'
work|@1|editor|%4|2.1.76|2.1.76|1
work|@1|editor|%5|2.1.76|2.1.76|0
EOF
cat > "$TMUX_SIDEBAR_STATE_DIR/pane-%4.json" <<'EOF'
{"pane_id":"%4","app":"claude","status":"running","updated_at":100}
EOF
rm -f "$TMUX_SIDEBAR_STATE_DIR/pane-%5.json"

output="$(python3 scripts/sidebar-ui.py --dump-render 2>&1)"

assert_contains "$output" 'claude'
assert_contains "$output" '2.1.76'

fake_tmux_set_tree <<'EOF'
work|@1|editor|%6|zsh|zsh|1
EOF
cat > "$TMUX_SIDEBAR_STATE_DIR/pane-%6.json" <<'EOF'
{"pane_id":"%6","app":"claude","status":"idle","updated_at":100}
EOF

output="$(python3 scripts/sidebar-ui.py --dump-render 2>&1)"

assert_contains "$output" 'zsh'
case "$output" in
  *'│     └─ claude'* ) fail "stale claude state should not relabel obvious shell panes" ;;
esac

fake_tmux_set_tree <<'EOF'
work|@1|editor|%2|superlongpanecommand|superlongpanecommand|1
EOF
printf '14\n' > "$TEST_TMUX_DATA_DIR/option__tmux_sidebar_width.txt"

output="$(python3 scripts/sidebar-ui.py --dump-render 2>&1)"

assert_contains "$output" '…'
case "$output" in
  *'superlongpanecommand'* ) fail "sidebar UI should truncate long rows for narrow widths" ;;
esac

rm -f "$TEST_TMUX_DATA_DIR/option__tmux_sidebar_width.txt"
export TMUX_SIDEBAR_WIDTH=''
python_width="$(
python3 - <<'PY'
import importlib.util
from pathlib import Path

spec = importlib.util.spec_from_file_location("sidebar_ui", Path("scripts/sidebar-ui.py"))
module = importlib.util.module_from_spec(spec)
spec.loader.exec_module(module)
print(module.configured_sidebar_width())
PY
)"

assert_eq "$python_width" "25"
