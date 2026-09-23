#!/usr/bin/env bash
set -euo pipefail

. "$(dirname "$0")/testlib.sh"

fake_tmux_no_sidebar
fake_tmux_set_tree <<'EOF'
laravel|@1|codex|%1|codex|codex|1
laravel|@1|codex|%9|python3|Sidebar|0
work|@2|editor|%2|nvim|nvim|1
work|@2|editor|%3|bash|bash|0
EOF

export TMUX_PANE_TREE_STATE_DIR="$TEST_TMP/state"
mkdir -p "$TMUX_PANE_TREE_STATE_DIR"
cat > "$TMUX_PANE_TREE_STATE_DIR/pane-%1.json" <<'EOF'
{"pane_id":"%1","app":"codex","status":"running","pane_current_command":"codex"}
EOF

printf 'on\n' > "$TEST_TMUX_DATA_DIR/option__tmux_pane_tree_compact_single_panes.txt"

python3 - <<'PY'
import importlib.util
from pathlib import Path

spec = importlib.util.spec_from_file_location("sidebar_ui", Path("scripts/ui/sidebar-ui.py"))
module = importlib.util.module_from_spec(spec)
spec.loader.exec_module(module)

rows = module.load_tree()
single_window = next(row for row in rows if row["kind"] == "window" and row["window"] == "@1")
assert single_window["pane_id"] == "%1", single_window
assert "⏳" in single_window["text"], single_window
assert not any(row["kind"] == "pane" and row["pane_id"] == "%1" for row in rows)
assert [row["pane_id"] for row in rows if row["kind"] == "pane"] == ["%2", "%3"]
assert module.reconcile_selected_pane("%1", module.pane_rows_for(rows)) == "%1"
PY

printf 'off\n' > "$TEST_TMUX_DATA_DIR/option__tmux_pane_tree_compact_single_panes.txt"

python3 - <<'PY'
import importlib.util
from pathlib import Path

spec = importlib.util.spec_from_file_location("sidebar_ui", Path("scripts/ui/sidebar-ui.py"))
module = importlib.util.module_from_spec(spec)
spec.loader.exec_module(module)

rows = module.load_tree()
assert any(row["kind"] == "pane" and row["pane_id"] == "%1" for row in rows)
PY

printf 'on\n' > "$TEST_TMUX_DATA_DIR/option__tmux_pane_tree_compact_single_panes.txt"
printf 'nvim\n' > "$TEST_TMUX_DATA_DIR/option__tmux_pane_tree_filter.txt"

python3 - <<'PY'
import importlib.util
from pathlib import Path

spec = importlib.util.spec_from_file_location("sidebar_ui", Path("scripts/ui/sidebar-ui.py"))
module = importlib.util.module_from_spec(spec)
spec.loader.exec_module(module)

rows = module.load_tree()
window = next(row for row in rows if row["kind"] == "window" and row["window"] == "@2")
assert "pane_id" not in window, window
assert any(row["kind"] == "pane" and row["pane_id"] == "%2" for row in rows)
PY

printf '\n' > "$TEST_TMUX_DATA_DIR/option__tmux_pane_tree_filter.txt"

python3 - <<'PY'
import importlib.util
from pathlib import Path

spec = importlib.util.spec_from_file_location("sidebar_ui", Path("scripts/ui/sidebar-ui.py"))
module = importlib.util.module_from_spec(spec)
spec.loader.exec_module(module)

module.curses.curs_set = lambda _: None
module.curses.mousemask = lambda _: (0, 0)
module.curses.COLS = 40
module.curses.LINES = 10
module.sidebar_has_focus = lambda: True
module.close_sidebar = lambda: None
module.configured_shortcuts = lambda: dict(module.DEFAULT_SHORTCUTS)
module._write_row_map = lambda *args: None
commands = []
original_run = module.subprocess.run


def capture_selection(args, **kwargs):
    if args[0] == "tmux" and args[1] in ("switch-client", "select-window", "select-pane"):
        commands.append(args)
        return module.subprocess.CompletedProcess(args, 0)
    return original_run(args, **kwargs)


module.subprocess.run = capture_selection


class FakeScreen:
    def __init__(self, keys):
        self.keys = list(keys)

    def keypad(self, enabled):
        pass

    def timeout(self, milliseconds):
        pass

    def erase(self):
        pass

    def addnstr(self, y, x, text, limit, attr=0):
        pass

    def refresh(self):
        pass

    def getch(self):
        if not self.keys:
            raise AssertionError("getch called after key sequence ended")
        return self.keys.pop(0)


for keys in ([10, ord("q")], [module.curses.KEY_MOUSE, ord("q")]):
    commands.clear()
    module.curses.getmouse = lambda: (0, 0, 1, 0, module.curses.BUTTON1_PRESSED)
    module.run_interactive(FakeScreen(keys))
    assert commands[:3] == [
        ["tmux", "switch-client", "-t", "laravel"],
        ["tmux", "select-window", "-t", "@1"],
        ["tmux", "select-pane", "-t", "%1"],
    ], commands
PY
