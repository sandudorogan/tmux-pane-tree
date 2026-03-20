#!/usr/bin/env bash
set -euo pipefail

. "$(dirname "$0")/testlib.sh"

fake_tmux_set_tree <<'EOF'
work|@1|editor|%1|shell|shell|0
work|@1|editor|%2|claude|claude|1
ops|@3|logs|%9|tail|tail|0
ops|@3|logs|%10|codex-aarch64-apple-darwin|● build: done|0
ops|@3|logs|%11|codex-aarch64-apple-darwin|codex --full-auto|0
EOF

export TMUX_SIDEBAR_STATE_DIR="$TEST_TMP/state"
mkdir -p "$TMUX_SIDEBAR_STATE_DIR"
cat > "$TMUX_SIDEBAR_STATE_DIR/pane-%2.json" <<'EOF'
{"pane_id":"%2","app":"claude","status":"needs-input","updated_at":100}
EOF
cat > "$TMUX_SIDEBAR_STATE_DIR/pane-%10.json" <<'EOF'
{"pane_id":"%10","app":"codex","status":"done","updated_at":100}
EOF
cat > "$TMUX_SIDEBAR_STATE_DIR/pane-%11.json" <<'EOF'
{"pane_id":"%11","app":"codex","status":"running","updated_at":100}
EOF

output="$(bash scripts/features/sidebar/render-sidebar.sh)"

case "$output" in
  *"├─ work"* ) ;;
  * ) fail "expected session name in renderer output" ;;
esac

case "$output" in
  *"│  └─ editor"* ) ;;
  * ) fail "expected window name in renderer output" ;;
esac

case "$output" in
  *"│     └─ claude ❓"* ) ;;
  * ) fail "expected needs-input badge in renderer output" ;;
esac

case "$output" in
  *"│     └─ claude ❓"* ) ;;
  * ) fail "expected active pane marker in renderer output" ;;
esac

case "$output" in
  *"└─ ops"* ) ;;
  * ) fail "expected unicode pane branch continuation in renderer output" ;;
esac

case "$output" in
  *"        ├─ codex ✅"* ) ;;
  * ) fail "expected done badge in renderer output" ;;
esac

case "$output" in
  *"        └─ codex ⏳"* ) ;;
  * ) fail "expected running badge in renderer output" ;;
esac

fake_tmux_set_tree <<'EOF'
work|@1|editor|%1|shell|shell|0
ops|@3|logs|%9|tail|tail|0
EOF
printf 'ops,work\n' > "$TEST_TMUX_DATA_DIR/option__tmux_sidebar_session_order.txt"

output="$(bash scripts/features/sidebar/render-sidebar.sh)"
first_session_line="$(printf '%s\n' "$output" | grep -E '^[[:space:]]*[├└]─ ' | head -n 1)"

assert_eq "$first_session_line" '  ├─ ops'
