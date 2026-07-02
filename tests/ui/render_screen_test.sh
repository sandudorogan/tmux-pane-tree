#!/usr/bin/env bash
set -euo pipefail

. "$(dirname "$0")/../testlib.sh"

python3 - <<'PY'
from __future__ import annotations

import sys
from pathlib import Path

sys.path.insert(0, str(Path("scripts/ui").resolve()))
from sidebar_ui_lib import render

render.curses.COLS = 24
render.curses.LINES = 4
render.curses.A_BOLD = 1
render.curses.A_DIM = 2
render.curses.A_UNDERLINE = 4
render.curses.A_ITALIC = 8
render.curses.curs_set = lambda value: None


class FakeScreen:
    def __init__(self) -> None:
        self.erase_count = 0
        self.refresh_count = 0
        self.calls: list[tuple[int, int, str, int]] = []

    def erase(self) -> None:
        self.erase_count += 1

    def addnstr(self, y: int, x: int, value: str, width: int, attr: int = 0) -> None:
        self.calls.append((y, x, value, width))

    def move(self, y: int, x: int) -> None:
        self.calls.append((y, x, "<move>", 0))

    def refresh(self) -> None:
        self.refresh_count += 1


screen = FakeScreen()
rows = [
    {"kind": "session", "session": "work", "text": "├─ work"},
    {"kind": "pane", "session": "work", "window": "@1", "pane_id": "%1", "text": "│  └─ claude"},
]

render.render_screen(screen, rows, "%1")

if screen.erase_count != 0:
    raise SystemExit(f"render_screen should not erase the whole screen, got {screen.erase_count}")
if screen.refresh_count != 1:
    raise SystemExit(f"render_screen should refresh once, got {screen.refresh_count}")
if not any(call[2].strip() == "" for call in screen.calls):
    raise SystemExit("render_screen should clear individual rows before drawing")
PY
