from __future__ import annotations

import curses
import json
import os
import re
import subprocess
from pathlib import Path

from .core import STATE_DIR, tmux_option
from .tree import find_selected_row_index, render_rows, truncate_line


COLOR_PAIR_SESSION = 1
COLOR_PAIR_WINDOW = 2
COLOR_PAIR_PANE = 3
DEFAULT_COLOR_FG = "ffffff"
_HEX_COLOR_RE = re.compile(r"#([0-9a-fA-F]{6})")
_CUBE_VALUES = [0, 95, 135, 175, 215, 255]
_last_row_map_json = ""


def _scripts_dir() -> Path:
    return Path(__file__).resolve().parents[2]


def _write_row_map(rows: list[dict], scroll_offset: int) -> None:
    global _last_row_map_json
    sidebar_pane = os.environ.get("TMUX_PANE", "")
    if not sidebar_pane:
        return
    data = {"scroll_offset": scroll_offset, "rows": []}
    for row in rows:
        entry: dict = {"kind": row["kind"], "session": row.get("session", "")}
        if "window" in row:
            entry["window"] = row["window"]
        if "pane_id" in row:
            entry["pane_id"] = row["pane_id"]
        data["rows"].append(entry)
    json_str = json.dumps(data)
    if json_str == _last_row_map_json:
        return
    map_path = STATE_DIR / f"rowmap-{sidebar_pane}.json"
    try:
        tmp = map_path.with_suffix(".tmp")
        tmp.write_text(json_str)
        tmp.rename(map_path)
        _last_row_map_json = json_str
    except OSError:
        # Context menus are optional; keep the sidebar interactive if state files are unavailable.
        return


def _run_context_menu(mouse_y: int) -> None:
    sidebar_pane = os.environ.get("TMUX_PANE", "")
    if not sidebar_pane:
        return
    subprocess.Popen(
        ["bash", str(_scripts_dir() / "features/context-menu/show-context-menu.sh"), sidebar_pane, str(mouse_y)],
        stdout=subprocess.DEVNULL,
        stderr=subprocess.DEVNULL,
    )


def parse_fg_hex(style: str) -> str:
    match = re.search(r"fg=#([0-9a-fA-F]{6})", style)
    return match.group(1) if match else ""


def hex_to_256(hex_color: str) -> int:
    r, g, b = int(hex_color[0:2], 16), int(hex_color[2:4], 16), int(hex_color[4:6], 16)
    ri = min(range(6), key=lambda i: abs(_CUBE_VALUES[i] - r))
    gi = min(range(6), key=lambda i: abs(_CUBE_VALUES[i] - g))
    bi = min(range(6), key=lambda i: abs(_CUBE_VALUES[i] - b))
    return 16 + 36 * ri + 6 * gi + bi


def _option_hex(option: str) -> str:
    raw = tmux_option(option)
    if raw:
        match = _HEX_COLOR_RE.search(raw)
        return match.group(1) if match else ""
    return ""


def _define_color(slot: int, hex_color: str) -> int:
    r = int(hex_color[0:2], 16)
    g = int(hex_color[2:4], 16)
    b = int(hex_color[4:6], 16)
    if curses.can_change_color():
        curses.init_color(slot, r * 1000 // 255, g * 1000 // 255, b * 1000 // 255)
        return slot
    return hex_to_256(hex_color)


def _parse_border_format_colors() -> dict[str, str]:
    fmt = tmux_option("pane-border-format")
    colors: dict[str, str] = {}
    pattern = r"#\{\?pane_active,#\[fg=#([0-9a-fA-F]{6})\],#\[fg=#([0-9a-fA-F]{6})\]\}"
    matches = list(re.finditer(pattern, fmt))
    if matches:
        colors["inactive_command"] = matches[0].group(2)
    if len(matches) > 1:
        colors["active_path"] = matches[1].group(1)
    return colors


def init_sidebar_colors() -> tuple[int, int, int, int]:
    try:
        if curses.COLORS < 256:
            return curses.A_BOLD, 0, 0, 0
    except AttributeError:
        return curses.A_BOLD, 0, 0, 0
    fmt_colors = _parse_border_format_colors()
    session_hex = (
        _option_hex("@tmux_sidebar_color_session")
        or parse_fg_hex(tmux_option("pane-active-border-style"))
        or DEFAULT_COLOR_FG
    )
    window_hex = (
        _option_hex("@tmux_sidebar_color_window")
        or fmt_colors.get("inactive_command", "")
        or parse_fg_hex(tmux_option("pane-border-style"))
        or DEFAULT_COLOR_FG
    )
    pane_hex = (
        _option_hex("@tmux_sidebar_color_pane")
        or fmt_colors.get("active_path", "")
        or parse_fg_hex(tmux_option("status-style"))
        or DEFAULT_COLOR_FG
    )
    curses.init_pair(COLOR_PAIR_SESSION, _define_color(240, session_hex), -1)
    curses.init_pair(COLOR_PAIR_WINDOW, _define_color(241, window_hex), -1)
    curses.init_pair(COLOR_PAIR_PANE, _define_color(242, pane_hex), -1)
    return (
        curses.A_BOLD,
        curses.color_pair(COLOR_PAIR_SESSION),
        curses.color_pair(COLOR_PAIR_WINDOW),
        curses.color_pair(COLOR_PAIR_PANE),
    )


def _label_start(line: str) -> int:
    pos = line.rfind("─ ")
    return pos + 2 if pos >= 0 else len(line)


def render_screen(
    stdscr,
    rows: list[dict],
    selected_pane_id: str,
    scroll_offset: int = 0,
    search_query: str = "",
    search_matches: set[int] | None = None,
    search_mode: bool = False,
    active_attr: int = curses.A_BOLD,
    session_attr: int = 0,
    window_attr: int = 0,
    pane_attr: int = 0,
) -> None:
    width = max(0, curses.COLS - 1)
    has_search_bar = search_mode or bool(search_query)
    visible_lines = curses.LINES - (1 if has_search_bar else 0)
    stdscr.erase()
    rendered = render_rows(rows, selected_pane_id, width)
    selected_row = find_selected_row_index(rows, selected_pane_id)
    match_attr = getattr(curses, "A_ITALIC", curses.A_UNDERLINE)
    visible = rendered[scroll_offset:scroll_offset + visible_lines]
    for y, line in enumerate(visible):
        if y >= visible_lines:
            break
        row_idx = y + scroll_offset
        row = rows[row_idx] if row_idx < len(rows) else None
        kind = row["kind"] if row else None
        is_selected = selected_row is not None and row_idx == selected_row
        is_match = bool(search_matches) and row_idx in search_matches
        label_start = _label_start(line)
        stdscr.addnstr(y, 0, line[:label_start], width)
        remaining = width - label_start
        if remaining > 0 and label_start < len(line):
            label = line[label_start:]
            if is_selected:
                attr = active_attr | (match_attr if is_match else 0)
            elif kind == "session":
                attr = session_attr | (match_attr if is_match else 0)
            elif kind == "window":
                attr = window_attr | (match_attr if is_match else 0)
            else:
                attr = pane_attr | (match_attr if is_match else 0)
            stdscr.addnstr(y, label_start, label, remaining, attr)
    if has_search_bar:
        prompt = f"/{search_query}"
        prompt_line = curses.LINES - 1
        stdscr.addnstr(
            prompt_line,
            0,
            truncate_line(prompt, width),
            width,
            0 if search_mode else curses.A_DIM,
        )
        if search_mode:
            curses.curs_set(1)
            stdscr.move(prompt_line, min(len(prompt), width - 1))
        else:
            curses.curs_set(0)
    else:
        curses.curs_set(0)
    stdscr.refresh()
