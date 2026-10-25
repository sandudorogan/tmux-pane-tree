#!/usr/bin/env bash
set -euo pipefail

. "$(dirname "$0")/testlib.sh"

export TMUX_SIDEBAR_STATE_DIR="$TEST_TMP/state"
mkdir -p "$TMUX_SIDEBAR_STATE_DIR"
fake_tmux_no_sidebar
fake_tmux_set_tree <<'EOF'
work|@1|editor|%1|codex|project|1
work|@1|editor|%2|2.1.309|5 awaiting input · claude agents|0
work|@1|editor|%3|zsh|zsh|0
EOF
fake_tmux_set_capture "%1" <<'EOF'
  Agent command center  Group: Project  g
   All 3   Needs you 1   Working 1   Ready 1   Inactive 0
  ────────────────────────────────────────────────────
      Tasks                            Status  Updated
    ● Working task                     Working     now
  ? help  esc back  ↑/↓ move  enter open  n new
EOF
cat > "$TMUX_SIDEBAR_STATE_DIR/pane-%1.json" <<'EOF'
{"app":"codex","status":"done"}
EOF
cat > "$TMUX_SIDEBAR_STATE_DIR/pane-%2.json" <<'EOF'
{"app":"claude","status":"running"}
EOF

output="$(python3 scripts/ui/sidebar-ui.py --dump-render)"
assert_contains "$output" 'X codex ≡'
assert_contains "$output" 'C claude ≡'
assert_not_contains "$output" '✅'
assert_not_contains "$output" '⏳'

printf 'on\n' > "$TEST_TMUX_DATA_DIR/option__tmux_pane_tree_hide_panes.txt"
output="$(python3 - <<'PY'
from unittest.mock import call, patch

from scripts.ui.sidebar_ui_lib import status
from scripts.ui.sidebar_ui_lib.tree import load_tree, render_rows

with patch.object(status, "run_tmux", wraps=status.run_tmux) as run_tmux:
    print("\n".join(render_rows(load_tree())))
    assert run_tmux.call_args_list.count(call("capture-pane", "-pt", "%1")) == 1
PY
)"
assert_contains "$output" 'X codex ≡'
assert_contains "$output" 'C claude ≡'
assert_not_contains "$output" 'zsh'
rm "$TEST_TMUX_DATA_DIR/option__tmux_pane_tree_hide_panes.txt"

fake_tmux_set_tree <<'EOF'
work|@1|editor|%1|codex|project|1
work|@1|editor|%2|2.1.309|⠂ Claude Code|0
EOF
fake_tmux_set_capture "%1" <<'EOF'
› Continue with the task
  ← for agents · ? for shortcuts
EOF
output="$(python3 scripts/ui/sidebar-ui.py --dump-render)"
assert_contains "$output" 'X codex ✅'
assert_contains "$output" 'C claude ⏳'
assert_not_contains "$output" '≡'

rm "$TMUX_SIDEBAR_STATE_DIR"/pane-*.json
fake_tmux_set_capture "%1" <<'EOF'
  Agent command center  Group: Projec…
   All 0   Needs you 0   Working 0   ›
  ────────────────────────────────────
  No tasks yet
  ? help  esc back  ↑/↓ move  enter open  n n…
EOF
fake_tmux_set_capture "%2" <<'EOF'

 ▐▛███▛█   Claude Code v2.1.309
▝▜██████▀  New sessions: Opus 5.5 (1M context) · high effort · ~/project
 ▝▝   ▝▝   0 awaiting input · 0 working · 0 completed

❯ describe a task for a new session
────────────────────────────────────────────────────────────────
  ⏵⏵ auto mode · enter to open · space to reply · ctrl+x to delete
EOF
output="$(python3 scripts/ui/sidebar-ui.py --dump-render)"
assert_contains "$output" 'X codex ≡'
assert_contains "$output" 'C claude ≡'

for theme in ascii unicode nerdfont; do
  printf '%s\n' "$theme" > "$TEST_TMUX_DATA_DIR/option__tmux_pane_tree_icon_theme.txt"
  printf '#\n' > "$TEST_TMUX_DATA_DIR/option__tmux_pane_tree_badge_command_center.txt"
  output="$(python3 scripts/ui/sidebar-ui.py --dump-render)"
  assert_contains "$output" 'codex #'
  assert_contains "$output" 'claude #'
done
rm "$TEST_TMUX_DATA_DIR/option__tmux_pane_tree_icon_theme.txt" \
  "$TEST_TMUX_DATA_DIR/option__tmux_pane_tree_badge_command_center.txt"
printf 'M\n' > "$TEST_TMUX_DATA_DIR/option__tmux_sidebar_badge_command_center.txt"
output="$(python3 scripts/ui/sidebar-ui.py --dump-render)"
assert_contains "$output" 'codex M'
assert_contains "$output" 'claude M'
rm "$TEST_TMUX_DATA_DIR/option__tmux_sidebar_badge_command_center.txt"

python3 - <<'PY'
from unittest.mock import patch

from scripts.ui.sidebar_ui_lib.status import effective_pane_status

center = "  Agent command center  Group: Project  g\n   All 0   Needs you 0\n"
for state_status in ("idle", "running", "subagent-running", "needs-input", "done", "error"):
    with patch("scripts.ui.sidebar_ui_lib.status.run_tmux", return_value=center):
        assert effective_pane_status("%1", "codex", "project", {"status": state_status}) == "command-center"

for capture in (
    "Discussing the following UI:\n" + center,
    "› /agents\n  open the agent command center\n",
    "› Add command center detection\n",
):
    with patch("scripts.ui.sidebar_ui_lib.status.run_tmux", return_value=capture):
        assert effective_pane_status("%1", "codex", "project", None) == ""

with patch("scripts.ui.sidebar_ui_lib.status.run_tmux", return_value=center):
    assert effective_pane_status("%1", "zsh", "zsh", None) == ""

for title in ("claude agents", "0 awaiting input · claude agents"):
    with patch("scripts.ui.sidebar_ui_lib.status.run_tmux", side_effect=AssertionError("unexpected capture")):
        assert effective_pane_status("%2", "2_1_309", title, {"status": "idle"}) == "command-center"

with patch("scripts.ui.sidebar_ui_lib.status.run_tmux", side_effect=OSError):
    assert effective_pane_status("%1", "codex", "project", {"status": "done"}) == "done"
    assert effective_pane_status("%2", "claude", "⠂ Claude Code", None) == "running"

with patch("scripts.ui.sidebar_ui_lib.status.run_tmux", return_value="• Working (15s • esc to interrupt)\n"):
    assert effective_pane_status("%1", "codex", "project", {"status": "done"}) == "running"
PY
