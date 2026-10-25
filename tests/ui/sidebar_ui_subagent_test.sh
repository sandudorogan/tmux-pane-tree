#!/usr/bin/env bash
set -euo pipefail

. "$(dirname "$0")/testlib.sh"

export TMUX_PANE_TREE_STATE_DIR="$TEST_TMP/state"
mkdir -p "$TMUX_PANE_TREE_STATE_DIR"
fake_tmux_no_sidebar
fake_tmux_set_tree <<'EOF'
work|@1|editor|%1|2.1.310|✳ Delegated task|1
EOF
cat > "$TMUX_PANE_TREE_STATE_DIR/pane-%1.json" <<'EOF'
{"app":"claude","status":"idle","subagent_count":0}
EOF
fake_tmux_set_capture "%1" <<'EOF'
✻ Waiting for 1 background agent to finish

────────────────────────────────────────────────────────────
❯
────────────────────────────────────────────────────────────
  ⏵⏵ auto mode on (shift+tab to cycle) · ← 5 agents · ↓ to manage

  ⏺ main
  ◯ general-purpose  Reading plan.md and api.md    58s · ↓ 124.6k tokens
EOF

output="$(python3 scripts/ui/sidebar-ui.py --dump-render)"
assert_contains "$output" 'C claude ↳⏳'

fake_tmux_set_capture "%1" <<'EOF'
✻ Waiting for 1 background agent to finish
⏺ Agent "Build review page" finished · 2m
────────────────────────────────────────────────────────────
❯
────────────────────────────────────────────────────────────
  ⏵⏵ auto mode on (shift+tab to cycle) · ← 5 agents
EOF
output="$(python3 scripts/ui/sidebar-ui.py --dump-render)"
assert_not_contains "$output" '↳⏳'

python3 - <<'PY'
from unittest.mock import patch

from scripts.ui.sidebar_ui_lib.status import effective_pane_status

footer = "  ⏵⏵ auto mode on (shift+tab to cycle) · ← 5 agents · ↓ to manage\n"
active = "❯\n────────────────────────\n" + footer + "  ◯ worker  Reading files\n" * 8
for title in ("✳ Delegated task", "⠂ Claude Code"):
    for state_status in (None, "idle", "done", "running", "subagent-running"):
        state = {"status": state_status} if state_status else None
        with patch("scripts.ui.sidebar_ui_lib.status.run_tmux", return_value=active):
            assert effective_pane_status("%1", "2.1.310", title, state) == "subagent-running"

for state_status in ("needs-input", "error"):
    with patch("scripts.ui.sidebar_ui_lib.status.run_tmux", return_value=active):
        assert effective_pane_status("%1", "claude", "project", {"status": state_status}) == state_status

wrapped = "❯\n────────────────────────\n  ⏵⏵ auto mode on · ← 5 agents ·\n  ↓ to manage\n"
with patch("scripts.ui.sidebar_ui_lib.status.run_tmux", return_value=wrapped):
    assert effective_pane_status("%1", "claude", "✳ Idle", None) == "subagent-running"

for capture in (
    "› The hint is ↓ to manage\n",
    "✻ Waiting for 2 background agents to finish\n",
    "  ⏵⏵ auto mode on · ← 5 agents\n",
    footer + "old transcript\n" * 6 + "❯\n────────────────────────\n  ⏵⏵ auto mode on\n",
):
    with patch("scripts.ui.sidebar_ui_lib.status.run_tmux", return_value=capture):
        assert effective_pane_status("%1", "claude", "✳ Idle", {"status": "idle"}) == ""

with patch("scripts.ui.sidebar_ui_lib.status.run_tmux", return_value=active):
    assert effective_pane_status("%1", "zsh", "zsh", None) == ""
    assert effective_pane_status("%1", "codex", "project", None) == ""
PY
