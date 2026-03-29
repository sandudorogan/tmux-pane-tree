#!/usr/bin/env bash
set -euo pipefail

. "$(dirname "$0")/testlib.sh"

unset TMUX_PANE_TREE_STATE_DIR
unset TMUX_SIDEBAR_FONT_DIRS

export TMUX_SIDEBAR_STATE_DIR="$TEST_TMP/state"
export TMUX_PANE_TREE_FONT_DIRS="$TEST_TMP/no-fonts"
mkdir -p "$TMUX_SIDEBAR_STATE_DIR"

fake_tmux_set_tree <<'EOF'
work|@1|editor|%1|nvim|shell|0
work|@1|editor|%2|claude|claude|1
work|@1|editor|%99|python3|Sidebar|0
ops|@3|logs|%9|tail|tail|0
solo|@5|sidebar-only|%77|python3|Sidebar|0
EOF

output="$(python3 scripts/ui/sidebar-ui.py --dump-render 2>&1)"

case "$output" in
  *'invalid option:'* ) fail "sidebar UI should not leak tmux stderr for missing options" ;;
esac

fake_tmux_register_main_pane "%9"

output="$(python3 scripts/ui/sidebar-ui.py --dump-render 2>&1)"

assert_contains "$output" '├─ work'
assert_contains "$output" '│     └─ C claude'
assert_contains "$output" '▶       └─ : tail'
case "$output" in
  *'%99 Sidebar'* ) fail "sidebar pane should be hidden when window has other panes" ;;
esac
case "$output" in
  *'└─ solo'* ) fail "sidebar-only sessions should be hidden from the mirrored tree" ;;
esac

fake_tmux_set_tree <<'EOF'
work|@1|editor|%1|nvim|shell|0
work|@1|editor|%99|python3|tmux-sidebar|0
EOF

output="$(python3 scripts/ui/sidebar-ui.py --dump-render 2>&1)"

case "$output" in
  *'%99 tmux-sidebar'* ) fail "legacy sidebar pane titles should still be hidden when window has other panes" ;;
esac

fake_tmux_set_tree <<'EOF'
work|@1|editor|%3|codex-aarch64-apple-darwin|codex-aarch64-apple-darwin|1
EOF
rm -f "$TMUX_SIDEBAR_STATE_DIR"/pane-*.json

output="$(python3 scripts/ui/sidebar-ui.py --dump-render 2>&1)"

assert_contains "$output" 'codex'
assert_not_contains "$output" '⏳'
case "$output" in
  *'codex-aarch64-apple-darwin'* ) fail "codex target-triple binary names should normalize to codex" ;;
esac

fake_tmux_set_tree <<'EOF'
work|@1|codex-aarch64-apple-darwin|%33|codex-aarch64-apple-darwin|codex --full-auto|1
EOF
rm -f "$TMUX_SIDEBAR_STATE_DIR"/pane-*.json

output="$(python3 scripts/ui/sidebar-ui.py --dump-render 2>&1)"

assert_contains "$output" '└─ codex'
assert_not_contains "$output" '└─ codex-aarch64-apple-darwin'

fake_tmux_set_tree <<'EOF'
work|@1|env|%34|env|codex --full-auto|1
EOF
rm -f "$TMUX_SIDEBAR_STATE_DIR"/pane-*.json

output="$(python3 scripts/ui/sidebar-ui.py --dump-render 2>&1)"

assert_contains "$output" '└─ codex'
assert_not_contains "$output" '└─ env'

fake_tmux_set_tree <<'EOF'
work|@1|editor|%4|2.1.76|2.1.76|1
work|@1|editor|%5|2.1.76|2.1.76|0
EOF
cat > "$TMUX_SIDEBAR_STATE_DIR/pane-%4.json" <<'EOF'
{"pane_id":"%4","app":"claude","status":"running","updated_at":100}
EOF
rm -f "$TMUX_SIDEBAR_STATE_DIR/pane-%5.json"

output="$(python3 scripts/ui/sidebar-ui.py --dump-render 2>&1)"

assert_contains "$output" 'claude'
assert_not_contains "$output" '2.1.76'

fake_tmux_set_tree <<'EOF'
work|@1|editor|%6|zsh|zsh|1
EOF
cat > "$TMUX_SIDEBAR_STATE_DIR/pane-%6.json" <<'EOF'
{"pane_id":"%6","app":"claude","status":"idle","updated_at":100}
EOF

output="$(python3 scripts/ui/sidebar-ui.py --dump-render 2>&1)"

assert_contains "$output" 'zsh'
case "$output" in
  *'│     └─ claude'* ) fail "stale claude state should not relabel obvious shell panes" ;;
esac

fake_tmux_set_tree <<'EOF'
work|@1|editor|%7|zsh|sandu.dorogan@host:~/workdir/tmux-sidebar|1
EOF
cat > "$TMUX_SIDEBAR_STATE_DIR/pane-%7.json" <<'EOF'
{"pane_id":"%7","app":"codex","status":"running","updated_at":100}
EOF

output="$(python3 scripts/ui/sidebar-ui.py --dump-render 2>&1)"

assert_contains "$output" 'zsh'
case "$output" in
  *'⏳'* ) fail "stale codex state should not show a running badge on obvious shell panes" ;;
esac

fake_tmux_set_tree <<'EOF'
work|@1|editor|%10|python3|assistant runner|1
EOF
cat > "$TMUX_SIDEBAR_STATE_DIR/pane-%10.json" <<'EOF'
{"pane_id":"%10","app":"claude","status":"running","updated_at":100}
EOF

output="$(python3 scripts/ui/sidebar-ui.py --dump-render 2>&1)"

assert_contains "$output" 'C claude ⏳'

fake_tmux_set_tree <<'EOF'
work|@1|editor|%11|node|repo worker|1
EOF
cat > "$TMUX_SIDEBAR_STATE_DIR/pane-%11.json" <<'EOF'
{"pane_id":"%11","app":"codex","status":"running","updated_at":100}
EOF

output="$(python3 scripts/ui/sidebar-ui.py --dump-render 2>&1)"

assert_contains "$output" 'X codex ⏳'

fake_tmux_set_tree <<'EOF'
work|@1|editor|%111|node|repo worker|1
EOF
cat > "$TMUX_SIDEBAR_STATE_DIR/pane-%111.json" <<'EOF'
{"pane_id":"%111","app":"opencode","status":"running","updated_at":100}
EOF

output="$(python3 scripts/ui/sidebar-ui.py --dump-render 2>&1)"

assert_contains "$output" 'O opencode ⏳'

fake_tmux_set_tree <<'EOF'
work|@1|editor|%112|zsh|zsh|1
EOF
cat > "$TMUX_SIDEBAR_STATE_DIR/pane-%112.json" <<'EOF'
{"pane_id":"%112","app":"cursor","status":"running","updated_at":100}
EOF

output="$(python3 scripts/ui/sidebar-ui.py --dump-render 2>&1)"

assert_contains "$output" 'U cursor ⏳'

fake_tmux_set_tree <<'EOF'
work|@1|editor|%113|zsh|zsh|1
EOF
cat > "$TMUX_SIDEBAR_STATE_DIR/pane-%113.json" <<'EOF'
{"pane_id":"%113","app":"cursor","status":"needs-input","updated_at":100}
EOF

output="$(python3 scripts/ui/sidebar-ui.py --dump-render 2>&1)"

assert_contains "$output" 'U cursor ❓'

fake_tmux_set_tree <<'EOF'
work|@1|editor|%114|zsh|zsh|1
EOF
cat > "$TMUX_SIDEBAR_STATE_DIR/pane-%114.json" <<'EOF'
{"pane_id":"%114","app":"cursor","status":"done","updated_at":100}
EOF

output="$(python3 scripts/ui/sidebar-ui.py --dump-render 2>&1)"

assert_contains "$output" 'U cursor ✅'

fake_tmux_set_tree <<'EOF'
work|@1|editor|%115|zsh|zsh|1
EOF
cat > "$TMUX_SIDEBAR_STATE_DIR/pane-%115.json" <<'EOF'
{"pane_id":"%115","app":"cursor","status":"error","updated_at":100}
EOF

output="$(python3 scripts/ui/sidebar-ui.py --dump-render 2>&1)"

assert_contains "$output" 'U cursor ❌'

fake_tmux_set_tree <<'EOF'
work|@1|zsh|%116|zsh|zsh|1
EOF
cat > "$TMUX_SIDEBAR_STATE_DIR/pane-%116.json" <<'EOF'
{"pane_id":"%116","app":"cursor","status":"running","updated_at":100}
EOF

output="$(python3 scripts/ui/sidebar-ui.py --dump-render 2>&1)"

assert_contains "$output" '└─ cursor'
assert_not_contains "$output" '└─ zsh'

fake_tmux_set_tree <<'EOF'
work|@1|editor|%117|zsh|zsh|1
EOF
cat > "$TMUX_SIDEBAR_STATE_DIR/pane-%117.json" <<'EOF'
{"pane_id":"%117","app":"cursor","status":"idle","updated_at":100}
EOF

output="$(python3 scripts/ui/sidebar-ui.py --dump-render 2>&1)"

assert_contains "$output" 'zsh'
assert_not_contains "$output" 'cursor'

fake_tmux_set_tree <<'EOF'
work|@1|editor|%8|codex-aarch64-apple-darwin|● project: done|1
EOF
cat > "$TMUX_SIDEBAR_STATE_DIR/pane-%8.json" <<'EOF'
{"pane_id":"%8","app":"codex","status":"running","updated_at":100}
EOF

output="$(python3 scripts/ui/sidebar-ui.py --dump-render 2>&1)"

assert_contains "$output" 'X codex ⏳'

fake_tmux_set_tree <<'EOF'
work|@1|editor|%9|codex-aarch64-apple-darwin|codex --full-auto|1
EOF
cat > "$TMUX_SIDEBAR_STATE_DIR/pane-%9.json" <<'EOF'
{"pane_id":"%9","app":"codex","status":"done","updated_at":100}
EOF

output="$(python3 scripts/ui/sidebar-ui.py --dump-render 2>&1)"

assert_contains "$output" 'X codex ✅'

fake_tmux_set_tree <<'EOF'
work|@1|editor|%12|codex-aarch64-apple-darwin|codex --full-auto|1
EOF
cat > "$TMUX_SIDEBAR_STATE_DIR/pane-%12.json" <<'EOF'
{"pane_id":"%12","app":"codex","status":"idle","updated_at":100}
EOF

output="$(python3 scripts/ui/sidebar-ui.py --dump-render 2>&1)"

assert_contains "$output" 'codex'
assert_not_contains "$output" '⏳'

fake_tmux_set_tree <<'EOF'
work|@1|editor|%13|codex-aarch64-apple-darwin|● project: done|1
EOF
cat > "$TMUX_SIDEBAR_STATE_DIR/pane-%13.json" <<'EOF'
{"pane_id":"%13","app":"codex","status":"idle","updated_at":100}
EOF

output="$(python3 scripts/ui/sidebar-ui.py --dump-render 2>&1)"

assert_contains "$output" 'codex'
assert_not_contains "$output" '✅'
assert_not_contains "$output" '⏳'

fake_tmux_set_tree <<'EOF'
work|@1|editor|%14|codex-aarch64-apple-darwin|● project: working on task|1
EOF
cat > "$TMUX_SIDEBAR_STATE_DIR/pane-%14.json" <<'EOF'
{"pane_id":"%14","app":"codex","status":"idle","pane_title":"● project: done","updated_at":100}
EOF
fake_tmux_set_capture "%14" <<'EOF'
• Working (15s • esc to interrupt)
EOF

output="$(python3 scripts/ui/sidebar-ui.py --dump-render 2>&1)"

assert_contains "$output" 'codex'
assert_contains "$output" '⏳'

fake_tmux_set_tree <<'EOF'
work|@1|editor|%15|codex-aarch64-apple-darwin|● project: working on task|1
EOF
cat > "$TMUX_SIDEBAR_STATE_DIR/pane-%15.json" <<'EOF'
{"pane_id":"%15","app":"codex","status":"idle","pane_title":"● project: working on task","updated_at":100}
EOF

output="$(python3 scripts/ui/sidebar-ui.py --dump-render 2>&1)"

assert_contains "$output" 'codex'
assert_not_contains "$output" '⏳'

fake_tmux_set_tree <<'EOF'
work|@1|editor|%40|bash|bash|1
work|@1|editor|%41|node|node|0
work|@1|editor|%42|lazygit|lazygit|0
work|@1|editor|%43|yazi|yazi|0
work|@1|editor|%44|ranger|ranger|0
work|@1|editor|%45|bb|bb|0
work|@1|editor|%46|clojure|clojure|0
work|@1|editor|%47|java|java|0
work|@1|editor|%48|mytool|mytool|0
EOF
rm -f "$TMUX_SIDEBAR_STATE_DIR"/pane-*.json

output="$(python3 scripts/ui/sidebar-ui.py --dump-render 2>&1)"

assert_contains "$output" '$ bash'
assert_contains "$output" 'N node'
assert_contains "$output" 'G lazygit'
assert_contains "$output" 'Y yazi'
assert_contains "$output" 'R ranger'
assert_contains "$output" 'B bb'
assert_contains "$output" 'L clojure'
assert_contains "$output" 'J java'
assert_contains "$output" '? mytool'

fake_tmux_set_tree <<'EOF'
work|@1|editor|%49|bash|bash|1
work|@1|editor|%50|python3|assistant runner|0
EOF
cat > "$TMUX_SIDEBAR_STATE_DIR/pane-%50.json" <<'EOF'
{"pane_id":"%50","app":"claude","status":"running","updated_at":100}
EOF
printf 'unicode\n' > "$TEST_TMUX_DATA_DIR/option__tmux_pane_tree_icon_theme.txt"

output="$(python3 scripts/ui/sidebar-ui.py --dump-render 2>&1)"

assert_contains "$output" '› bash'
assert_contains "$output" '◎ claude ⏳'

printf 's\n' > "$TEST_TMUX_DATA_DIR/option__tmux_pane_tree_icon_shell.txt"

output="$(python3 scripts/ui/sidebar-ui.py --dump-render 2>&1)"

assert_contains "$output" 's bash'
rm -f "$TEST_TMUX_DATA_DIR/option__tmux_pane_tree_icon_theme.txt" \
  "$TEST_TMUX_DATA_DIR/option__tmux_pane_tree_icon_shell.txt"

printf 'ascii\n' > "$TEST_TMUX_DATA_DIR/option__tmux_sidebar_icon_theme.txt"
printf 'unicode\n' > "$TEST_TMUX_DATA_DIR/option__tmux_pane_tree_icon_theme.txt"
printf 'l\n' > "$TEST_TMUX_DATA_DIR/option__tmux_sidebar_icon_shell.txt"
printf 'n\n' > "$TEST_TMUX_DATA_DIR/option__tmux_pane_tree_icon_shell.txt"

output="$(python3 scripts/ui/sidebar-ui.py --dump-render 2>&1)"

assert_contains "$output" 'n bash'
assert_contains "$output" '◎ claude ⏳'
assert_not_contains "$output" 'l bash'
rm -f "$TEST_TMUX_DATA_DIR/option__tmux_sidebar_icon_theme.txt" \
  "$TEST_TMUX_DATA_DIR/option__tmux_pane_tree_icon_theme.txt" \
  "$TEST_TMUX_DATA_DIR/option__tmux_sidebar_icon_shell.txt" \
  "$TEST_TMUX_DATA_DIR/option__tmux_pane_tree_icon_shell.txt"

fake_tmux_set_tree <<'EOF'
work|@1|editor|%60|sh|sh|1
work|@1|editor|%61|less|less|0
work|@1|editor|%62|cat|cat|0
work|@1|editor|%63|htop|htop|0
work|@1|editor|%64|bpytop|bpytop|0
work|@1|editor|%65|python3|assistant runner|0
work|@1|editor|%66|lazygit|lazygit|0
work|@1|editor|%67|python3|assistant runner|0
work|@1|editor|%68|python3|assistant runner|0
work|@1|editor|%69|python3|assistant runner|0
EOF
cat > "$TMUX_SIDEBAR_STATE_DIR/pane-%65.json" <<'EOF'
{"pane_id":"%65","app":"claude","status":"running","updated_at":100}
EOF
cat > "$TMUX_SIDEBAR_STATE_DIR/pane-%67.json" <<'EOF'
{"pane_id":"%67","app":"claude","status":"needs-input","updated_at":100}
EOF
cat > "$TMUX_SIDEBAR_STATE_DIR/pane-%68.json" <<'EOF'
{"pane_id":"%68","app":"claude","status":"done","updated_at":100}
EOF
cat > "$TMUX_SIDEBAR_STATE_DIR/pane-%69.json" <<'EOF'
{"pane_id":"%69","app":"claude","status":"error","updated_at":100}
EOF
mkdir -p "$TEST_TMP/fonts/NerdFonts"
touch "$TEST_TMP/fonts/NerdFonts/JetBrainsMono Nerd Font Mono.ttf"
export TMUX_PANE_TREE_FONT_DIRS="$TEST_TMP/no-fonts"
export TMUX_SIDEBAR_FONT_DIRS="$TEST_TMP/no-fonts"
export TMUX_PANE_TREE_FONT_DIRS="$TEST_TMP/fonts"

output="$(python3 scripts/ui/sidebar-ui.py --dump-render 2>&1)"

assert_contains "$output" '󰅬 sh'
assert_contains "$output" ' less'
assert_contains "$output" '󰄛 cat'
assert_contains "$output" '󱔓 htop'
assert_contains "$output" '󱔓 bpytop'
assert_contains "$output" '󰊢 lazygit'
assert_contains "$output" '󰵰 claude '
assert_contains "$output" '󰵰 claude '
assert_contains "$output" '󰵰 claude '
assert_contains "$output" '󰵰 claude '
unset TMUX_PANE_TREE_FONT_DIRS
unset TMUX_SIDEBAR_FONT_DIRS
export TMUX_PANE_TREE_FONT_DIRS="$TEST_TMP/no-fonts"

fake_tmux_set_tree <<'EOF'
work|@1|editor|%2|superlongpanecommand|superlongpanecommand|1
EOF
printf '14\n' > "$TEST_TMUX_DATA_DIR/option__tmux_sidebar_width.txt"

output="$(python3 scripts/ui/sidebar-ui.py --dump-render 2>&1)"

assert_contains "$output" '…'
case "$output" in
  *'superlongpanecommand'* ) fail "sidebar UI should truncate long rows for narrow widths" ;;
esac

rm -f "$TEST_TMUX_DATA_DIR/option__tmux_sidebar_width.txt"
export TMUX_SIDEBAR_WIDTH='41'
python_width="$(
python3 - <<'PY'
import importlib.util
from pathlib import Path

spec = importlib.util.spec_from_file_location("sidebar_ui", Path("scripts/ui/sidebar-ui.py"))
module = importlib.util.module_from_spec(spec)
spec.loader.exec_module(module)
print(module.configured_sidebar_width())
PY
)"

assert_eq "$python_width" "25"

rm -f "$TEST_TMUX_DATA_DIR/option__tmux_sidebar_width.txt"
export TMUX_SIDEBAR_WIDTH=''

rm -f "$TEST_TMUX_DATA_DIR/option__tmux_sidebar_width.txt"
rm -f "$TEST_TMUX_DATA_DIR/option__tmux_pane_tree_width.txt"
rm -f "$TEST_TMUX_DATA_DIR/option__tmux_pane_tree_session_order.txt"
printf 'legacy-width\n' > "$TEST_TMUX_DATA_DIR/option__tmux_sidebar_width.txt"
printf 'new-width\n' > "$TEST_TMUX_DATA_DIR/option__tmux_pane_tree_width.txt"

python_helper_output="$(
python3 - <<'PY'
import importlib.util
import json
import os
from pathlib import Path

spec = importlib.util.spec_from_file_location("sidebar_ui_core", Path("scripts/ui/sidebar_ui_lib/core.py"))
module = importlib.util.module_from_spec(spec)
spec.loader.exec_module(module)

preferred_width = module.tmux_option_value("width")
Path(os.environ["TEST_TMUX_DATA_DIR"]).joinpath("option__tmux_pane_tree_width.txt").unlink()
legacy_width = module.tmux_option_value("width")
module.set_tmux_option_value("session_order", "alpha,beta")

print(json.dumps({
    "aliases": list(module.option_aliases("width")),
    "preferred_width": preferred_width,
    "legacy_width": legacy_width,
}))
PY
)"

assert_eq "$python_helper_output" '{"aliases": ["@tmux_pane_tree_width", "@tmux_sidebar_width"], "preferred_width": "new-width", "legacy_width": "legacy-width"}'
assert_eq "$(cat "$TEST_TMUX_DATA_DIR/option__tmux_pane_tree_session_order.txt")" 'alpha,beta'

fake_tmux_set_tree <<'EOF'
work|@1|2.1.76|%20|2.1.76|2.1.76|1
work|@1|2.1.76|%21|lazygit|lazygit|0
work|@1|2.1.76|%22|2.1.76|2.1.76|0
EOF
rm -f "$TMUX_SIDEBAR_STATE_DIR"/pane-*.json
cat > "$TMUX_SIDEBAR_STATE_DIR/pane-%20.json" <<'EOF'
{"pane_id":"%20","app":"claude","status":"needs-input","updated_at":100}
EOF

output="$(python3 scripts/ui/sidebar-ui.py --dump-render 2>&1)"

assert_contains "$output" 'claude ❓'
assert_not_contains "$output" '└─ 2.1.76'

fake_tmux_set_tree <<'EOF'
work|@1|2.1.76|%23|2.1.76|2.1.76|1
EOF
rm -f "$TMUX_SIDEBAR_STATE_DIR"/pane-*.json

output="$(python3 scripts/ui/sidebar-ui.py --dump-render 2>&1)"

assert_contains "$output" 'claude'
assert_not_contains "$output" '2.1.76'

fake_tmux_set_tree <<'EOF'
work|@1|myproject|%24|2.1.76|2.1.76|1
EOF
cat > "$TMUX_SIDEBAR_STATE_DIR/pane-%24.json" <<'EOF'
{"pane_id":"%24","app":"claude","status":"running","updated_at":100}
EOF

output="$(python3 scripts/ui/sidebar-ui.py --dump-render 2>&1)"

assert_contains "$output" '└─ myproject'
assert_contains "$output" 'C claude ⏳'

fake_tmux_set_tree <<'EOF'
work|@1|2.1.76|%25|2.1.76|2.1.76|1
work|@1|2.1.76|%26|lazygit|lazygit|0
work|@1|2.1.76|%27|2.1.76|2.1.76|0
EOF
rm -f "$TMUX_SIDEBAR_STATE_DIR"/pane-*.json
cat > "$TMUX_SIDEBAR_STATE_DIR/pane-%27.json" <<'EOF'
{"pane_id":"%27","app":"claude","status":"running","updated_at":100}
EOF

output="$(python3 scripts/ui/sidebar-ui.py --dump-render 2>&1)"

assert_contains "$output" 'claude ⏳'
assert_not_contains "$output" '└─ 2.1.76'

fake_tmux_set_tree <<'EOF'
work|@1|editor|%30|2.1.76|⠂ Claude Code|1
EOF
rm -f "$TMUX_SIDEBAR_STATE_DIR"/pane-*.json

output="$(python3 scripts/ui/sidebar-ui.py --dump-render 2>&1)"

assert_contains "$output" 'C claude ⏳'
assert_not_contains "$output" '2.1.76'

fake_tmux_set_tree <<'EOF'
work|@1|editor|%31|2.1.76|● sandu.dorogan: done|1
EOF
rm -f "$TMUX_SIDEBAR_STATE_DIR"/pane-*.json

output="$(python3 scripts/ui/sidebar-ui.py --dump-render 2>&1)"

assert_contains "$output" 'C claude ✅'
assert_not_contains "$output" '2.1.76'

fake_tmux_set_tree <<'EOF'
work|@1|editor|%32|2.1.76|● project: error|1
EOF
rm -f "$TMUX_SIDEBAR_STATE_DIR"/pane-*.json

output="$(python3 scripts/ui/sidebar-ui.py --dump-render 2>&1)"

assert_contains "$output" 'C claude ❌'

unset TMUX_SIDEBAR_STATE_DIR
export TMUX_PANE_TREE_STATE_DIR="$TEST_TMP/pane-tree-state-alias"
mkdir -p "$TMUX_PANE_TREE_STATE_DIR"

fake_tmux_set_tree <<'EOF'
work|@1|editor|%200|python3|assistant runner|1
EOF
cat > "$TMUX_PANE_TREE_STATE_DIR/pane-%200.json" <<'EOF'
{"pane_id":"%200","app":"claude","status":"running","updated_at":100}
EOF

output="$(python3 scripts/ui/sidebar-ui.py --dump-render 2>&1)"

assert_contains "$output" 'claude ⏳'

unset TMUX_PANE_TREE_STATE_DIR
export TMUX_SIDEBAR_STATE_DIR="$TEST_TMP/state"
mkdir -p "$TMUX_SIDEBAR_STATE_DIR"

unset TMUX_SIDEBAR_STATE_DIR
export XDG_STATE_HOME=''
python_state_dir="$(
python3 - <<'PY'
import importlib.util
from pathlib import Path

spec = importlib.util.spec_from_file_location("sidebar_ui", Path("scripts/ui/sidebar-ui.py"))
module = importlib.util.module_from_spec(spec)
spec.loader.exec_module(module)
print(module.STATE_DIR)
PY
)"

assert_eq "$python_state_dir" "$HOME/.local/state/tmux-sidebar"

unset XDG_STATE_HOME
export TMUX_SIDEBAR_STATE_DIR="$TEST_TMP/state"
mkdir -p "$TMUX_SIDEBAR_STATE_DIR"
