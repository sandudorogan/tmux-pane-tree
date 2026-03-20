#!/usr/bin/env bash
set -euo pipefail

. "$(dirname "$0")/testlib.sh"

export TMUX_SIDEBAR_STATE_DIR="$TEST_TMP/state"
mkdir -p "$TMUX_SIDEBAR_STATE_DIR"

cat > "$TMUX_SIDEBAR_STATE_DIR/pane-%7.json" <<'EOF'
{"pane_id":"%7","app":"claude","status":"needs-input","updated_at":100}
EOF

bash scripts/features/state/clear-pane-state.sh "%7"

assert_file_contains "$TMUX_SIDEBAR_STATE_DIR/pane-%7.json" '"status":"idle"'

cat > "$TMUX_SIDEBAR_STATE_DIR/pane-%8.json" <<'EOF'
{"pane_id":"%8","app":"claude","status":"running","updated_at":100}
EOF

bash scripts/features/state/clear-pane-state.sh "%8"

assert_file_contains "$TMUX_SIDEBAR_STATE_DIR/pane-%8.json" '"status":"running"'

cat > "$TMUX_SIDEBAR_STATE_DIR/pane-%9.json" <<'EOF'
{"pane_id":"%9","app":"codex","status":"done","updated_at":100}
EOF

bash scripts/features/state/clear-pane-state.sh "%9"

assert_file_contains "$TMUX_SIDEBAR_STATE_DIR/pane-%9.json" '"status":"idle"'

cat > "$TMUX_SIDEBAR_STATE_DIR/pane-%10.json" <<'EOF'
{"pane_id":"%10","app":"codex","status":"running","updated_at":100}
EOF

bash scripts/features/state/clear-pane-state.sh "%10"

assert_file_contains "$TMUX_SIDEBAR_STATE_DIR/pane-%10.json" '"status":"running"'
