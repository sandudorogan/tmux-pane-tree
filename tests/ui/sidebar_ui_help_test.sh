#!/usr/bin/env bash
set -euo pipefail

. "$(dirname "$0")/testlib.sh"

python3 - <<'PY'
import importlib.util
from pathlib import Path
from unittest.mock import Mock, patch

spec = importlib.util.spec_from_file_location("sidebar_ui", Path("scripts/ui/sidebar-ui.py"))
ui = importlib.util.module_from_spec(spec)
spec.loader.exec_module(ui)
from sidebar_ui_lib import core
from sidebar_ui_lib.render import help_lines

shortcuts = dict(ui.DEFAULT_SHORTCUTS, close_pane="dd", jump_back="C-p")
lines = help_lines(shortcuts, 80, "s", "S")
assert "  prefix s" in lines
assert "  prefix S" in lines
assert "  dd" in lines
assert "  C-p" in lines
assert "  x" not in lines
assert lines[:4] == ["", " Navigation", "", "  j / k, Up / Down"]
assert lines[4:7] == ["    Move selection", "  Enter", "    Open selected pane"]
assert lines[lines.index(" Search") - 2:lines.index(" Search")] == ["", ""]
for section in ("Navigation", "Search", "Windows & sessions", "View & mouse", "Sidebar", "In help"):
    assert " " + section in lines
for action in shortcuts:
    assert "  " + shortcuts[action] in lines, action
for key in ("?", "j / k, Up / Down", "Enter", "p", "/", "Backspace", "Esc",
            "n / N", "m / right click", "Left click", "Mouse wheel", "C-l",
            "q / Esc", "PgUp / PgDn", "Home / End"):
    assert "  " + key in lines, key
for width in (0, 1, 2, 24):
    wrapped = help_lines(shortcuts, width, "t", "T")
    assert all(len(line) <= max(1, width) for line in wrapped)

for reserved in ("?", "a?"):
    with patch.object(core, "tmux_option_value_with_presence", side_effect=lambda name: (
        (reserved, True) if name == "close_pane_shortcut" else ("", False)
    )):
        assert core.configured_shortcuts() == core.DEFAULT_SHORTCUTS

rows = [
    {"kind": "pane", "pane_id": "%1", "text": "vim"},
    {"kind": "pane", "pane_id": "%2", "text": "zsh"},
]
ui.curses.curs_set = Mock()
ui.curses.start_color = Mock(side_effect=ui.curses.error)
ui.curses.mousemask = Mock()
ui.curses.update_lines_cols = Mock()
ui._write_pid_file = Mock()
ui._remove_pid_file = Mock()
ui._write_row_map = Mock()
ui.tmux_option = lambda _: "%1"
ui.tmux_option_value = lambda key: {"toggle_key": "s", "focus_key": "S"}.get(key, "")
ui.sidebar_has_focus = lambda: True
ui.configured_scrolloff = lambda: 0
ui._consume_sidebar_actions = lambda: []
ui._action_file_path = lambda: Mock(exists=lambda: True)
ui.load_view_state = lambda selected: (rows, rows, shortcuts, selected)
ui.subprocess.run = Mock(side_effect=AssertionError("help triggered a tmux command"))
ui.toggle_hide_panes = Mock(side_effect=AssertionError("help toggled panes"))
ui._run_context_menu = Mock(side_effect=AssertionError("help opened context menu"))
ui.prompt_add_window = Mock(side_effect=AssertionError("shortcut prefix survived help"))


class Screen:
    def __init__(self, keys):
        self.keys = iter(keys)
        self.lines = {}
        self.frames = []
        self.attributes = []

    def keypad(self, enabled):
        pass

    def timeout(self, milliseconds):
        pass

    def erase(self):
        self.lines = {}

    def addnstr(self, y, x, text, limit, attr=0):
        assert 0 <= y < ui.curses.LINES
        assert x + limit < ui.curses.COLS
        row = self.lines.get(y, " " * (ui.curses.COLS - 1))
        self.lines[y] = row[:x] + text[:limit] + row[x + min(len(text), limit):]
        self.attributes.append((text, attr))

    def move(self, y, x):
        pass

    def refresh(self):
        self.frames.append("\n".join(self.lines.get(y, "") for y in range(ui.curses.LINES)))

    def getch(self):
        key = next(self.keys)
        return key() if callable(key) else key


def run(keys, width=80, height=40):
    ui.curses.COLS, ui.curses.LINES = width, height
    ui._refresh_requested = False
    ui.close_sidebar = Mock()
    screen = Screen(keys)
    ui.run_interactive(screen)
    ui.close_sidebar.assert_called_once_with()
    return screen.frames


# q leaves help, restores selection, and clears an unfinished shortcut.
frames = run([ord(c) for c in "ja?xpm/\nwq wq"])
assert "Help" in frames[3]
assert "  C-p" in frames[3]
assert "    Jump back" in frames[3]
assert " Navigation" in frames[3]
assert "Help" not in frames[-1]
assert "▶ zsh" in frames[-1]

# Help scrolls through every binding in a normal 25-column sidebar.
frames = run([ord("?"), *([ui.curses.KEY_NPAGE] * 40), ui.curses.KEY_HOME,
              ui.curses.KEY_END, ui.curses.KEY_PPAGE, ord("q"), ord("q")], 25, 7)
seen = "\n".join(frames)
assert "  prefix s" in seen
assert "    Toggle sidebar" in seen
assert "First / last help" in seen
assert frames[1] == frames[-4]
assert frames[-3] != frames[-2]

# Clicks and jump actions cannot operate on the tree behind help.
def external_jump():
    ui._consume_sidebar_actions = lambda: ["jump_back"]
    ui._refresh_requested = True
    return -1

ui.curses.getmouse = lambda: (0, 0, 0, 0, ui.curses.BUTTON1_CLICKED)
ui.focus_main_pane = Mock(side_effect=AssertionError("help changed focus"))
run([ord("?"), ui.curses.KEY_MOUSE, external_jump, 15, ord("q"), ord("q")])
ui._consume_sidebar_actions = lambda: []

# Resize help, then return to a confirmed search without losing it.
def resize():
    ui.curses.COLS, ui.curses.LINES = 25, 5
    return ui.curses.KEY_RESIZE

frames = run([ord("/"), ord("z"), 10, ord("?"), ui.curses.KEY_END,
              resize, 27, ord("q")])
assert "Help" in frames[-2]
assert "Help" not in frames[-1]
assert "/z" in frames[-1]
assert "▶ zsh" in frames[-1]

# A question mark remains a normal character while entering a search.
frames = run([ord("/"), ord("?"), 27, ord("q")])
assert "/?" in frames[2]
assert all("Help" not in frame for frame in frames)

screen = Screen([])
ui.curses.COLS, ui.curses.LINES = 25, 10
ui.render_help(screen, help_lines(shortcuts, 24, "t", "T"), 0)
assert ("  j / k, Up / Down", ui.curses.A_BOLD) in screen.attributes
assert ("    Move selection", 0) in screen.attributes
print("Help keys, configured bindings, scrolling, resize, and modal isolation passed")
PY
