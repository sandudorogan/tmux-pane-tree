#!/usr/bin/env bash
set -euo pipefail

. "$(dirname "$0")/testlib.sh"

output="$(python3 - <<'PY'
import importlib.util
import json
from pathlib import Path

spec = importlib.util.spec_from_file_location("sidebar_ui", Path("scripts/ui/sidebar-ui.py"))
module = importlib.util.module_from_spec(spec)
spec.loader.exec_module(module)

module.curses.curs_set = lambda _: None
module.curses.mousemask = lambda _: (0, 0)
module.curses.COLS = 40
module.curses.LINES = 4
module.configured_shortcuts = lambda: dict(module.DEFAULT_SHORTCUTS)
module.sidebar_has_focus = lambda: True
module.tmux_option = lambda _: ""
module.load_tree = lambda: [
    {"kind": "session", "text": "work"},
    {"kind": "pane", "pane_id": "%1", "text": "pane one"},
]

real_size = {"cols": 40, "lines": 4}


def fake_update_lines_cols():
    module.curses.COLS = real_size["cols"]
    module.curses.LINES = real_size["lines"]


module.curses.update_lines_cols = fake_update_lines_cols


class FakeScreen:
    def __init__(self, keys):
        self.keys = list(keys)
        self.widths = []

    def keypad(self, enabled):
        pass

    def timeout(self, milliseconds):
        pass

    def addnstr(self, y, x, text, limit, attr=0):
        if x + limit >= real_size["cols"] and y == real_size["lines"] - 1:
            raise module.curses.error("addnwstr() returned ERR")

    def refresh(self):
        self.widths.append(module.curses.COLS)

    def getch(self):
        key = self.keys.pop(0)
        if key == module.curses.KEY_RESIZE:
            real_size.update(cols=20, lines=3)
        return key


screen = FakeScreen([module.curses.KEY_RESIZE, ord("q")])
module.run_interactive(screen)
print(json.dumps({"widths": screen.widths, "cols": module.curses.COLS, "lines": module.curses.LINES}))
PY
)"

assert_contains "$output" '"widths": [40, 20]'
assert_contains "$output" '"cols": 20, "lines": 3'
