#!/usr/bin/env bash
set -euo pipefail

. "$(dirname "$0")/testlib.sh"

export TMUX_SIDEBAR_STATE_DIR="$TEST_TMP/state"
fake_tmux_register_pane "%7" "work" "@2" "editor" "Claude"

bash scripts/features/state/update-pane-state.sh \
  --pane "%7" \
  --app claude \
  --status done \
  --updated-at 200

bash scripts/features/state/update-pane-state.sh \
  --pane "%7" \
  --app claude \
  --status running \
  --updated-at 100

assert_file_contains "$TMUX_SIDEBAR_STATE_DIR/pane-%7.json" '"status":"done"'
