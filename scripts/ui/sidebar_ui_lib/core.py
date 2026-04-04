from __future__ import annotations

import curses
import os
import re
import shlex
import subprocess
from pathlib import Path


def state_dir() -> Path:
    if os.environ.get("TMUX_PANE_TREE_STATE_DIR"):
        return Path(os.environ["TMUX_PANE_TREE_STATE_DIR"])
    if os.environ.get("TMUX_SIDEBAR_STATE_DIR"):
        return Path(os.environ["TMUX_SIDEBAR_STATE_DIR"])
    base = os.environ.get("XDG_STATE_HOME") or str(Path.home() / ".local/state")
    return Path(base) / "tmux-sidebar"


STATE_DIR = state_dir()
DEFAULT_SIDEBAR_WIDTH = 25
DEFAULT_SHORTCUTS = {
    "add_window": "aw",
    "add_session": "as",
    "go_top": "gg",
    "go_bottom": "G",
    "jump_back": "C-o",
    "jump_forward": "C-i",
    "rename_session": "rs",
    "rename_window": "rw",
    "close_pane": "x",
    "toggle_filter": "f",
}
SIDEBAR_TITLES = {"Sidebar", "tmux-sidebar"}
SIDEBAR_COMMAND_RE = re.compile(r"^python(?:[0-9.]+)?$", re.IGNORECASE)
INPUT_POLL_MS = 25
REFRESH_INTERVAL_SECONDS = 2.0
SHORTCUTS_CACHE_TTL_SECONDS = 30.0
ESC_DELAY_MS = 25
if hasattr(curses, "BUTTON5_PRESSED"):
    MOUSE_SCROLL_DOWN = curses.BUTTON5_PRESSED
    EXTRA_MOUSE_MASK = 0
else:
    EXTRA_MOUSE_MASK = getattr(curses, "REPORT_MOUSE_POSITION", 0x08000000)
    MOUSE_SCROLL_DOWN = EXTRA_MOUSE_MASK
MOUSE_SCROLL_LINES = 3
DEFAULT_SCROLLOFF = 8


def scripts_dir() -> Path:
    return Path(__file__).resolve().parents[2]


def feature_script(*parts: str) -> Path:
    return scripts_dir().joinpath("features", *parts)


def run_tmux(*args: str) -> str:
    return subprocess.check_output(["tmux", *args], text=True, stderr=subprocess.DEVNULL)


def option_aliases(suffix: str) -> tuple[str, ...]:
    return (f"@tmux_pane_tree_{suffix}", f"@tmux_sidebar_{suffix}")


def tmux_option_value_with_presence(suffix: str) -> tuple[str, bool]:
    for name in option_aliases(suffix):
        try:
            return run_tmux("show-options", "-gv", name).strip(), True
        except subprocess.CalledProcessError:
            continue
    return "", False


def tmux_option_value(suffix: str) -> str:
    value, _present = tmux_option_value_with_presence(suffix)
    return value


def set_tmux_option_value(suffix: str, value: str) -> None:
    subprocess.run(
        ["tmux", "set-option", "-g", f"@tmux_pane_tree_{suffix}", value],
        check=False,
    )


def tmux_option(option_name: str) -> str:
    try:
        return run_tmux("show-options", "-gv", option_name).strip()
    except subprocess.CalledProcessError:
        return ""


def configured_scrolloff() -> int:
    raw = tmux_option_value("scrolloff")
    if raw:
        try:
            value = int(raw)
            if value >= 0:
                return value
        except (TypeError, ValueError):
            pass
    return DEFAULT_SCROLLOFF


def configured_sidebar_width() -> int:
    raw_width = tmux_option_value("width")
    if raw_width:
        try:
            width = int(raw_width)
        except (TypeError, ValueError):
            width = 0
        if width > 0:
            return width
    return DEFAULT_SIDEBAR_WIDTH


def configured_shortcuts() -> dict[str, str]:
    shortcuts: dict[str, str] = {}
    for action, default_shortcut in DEFAULT_SHORTCUTS.items():
        shortcut, present = tmux_option_value_with_presence(f"{action}_shortcut")
        if not present:
            shortcuts[action] = default_shortcut
            continue
        if not shortcut:
            return dict(DEFAULT_SHORTCUTS)
        shortcuts[action] = shortcut
    shortcut_values = list(shortcuts.values())
    if any("q" in shortcut for shortcut in shortcut_values):
        return dict(DEFAULT_SHORTCUTS)
    if len(set(shortcut_values)) != len(shortcuts):
        return dict(DEFAULT_SHORTCUTS)
    if any(
        shortcut != other_shortcut and other_shortcut.startswith(shortcut)
        for shortcut in shortcut_values
        for other_shortcut in shortcut_values
    ):
        return dict(DEFAULT_SHORTCUTS)
    return shortcuts


def shortcut_key_code(shortcut: str) -> int | None:
    match = re.fullmatch(r"C-([A-Za-z])", shortcut)
    if match is None:
        return None
    return ord(match.group(1).lower()) & 0x1F


def sidebar_has_focus() -> bool:
    sidebar_pane = os.environ.get("TMUX_PANE", "")
    if not sidebar_pane:
        return False
    try:
        return run_tmux("display-message", "-p", "-t", sidebar_pane, "#{pane_active}").strip() == "1"
    except subprocess.CalledProcessError:
        return False


def is_sidebar_pane(title: str, command: str) -> bool:
    return title in SIDEBAR_TITLES and bool(SIDEBAR_COMMAND_RE.match(normalize_command_token(command)))


def normalize_command_token(command: str) -> str:
    token = command.strip()
    if "/" in token:
        token = token.rsplit("/", 1)[-1]
    return token


def focus_main_pane() -> None:
    subprocess.run(["bash", str(feature_script("sidebar", "focus-main-pane.sh"))], check=False)


def toggle_hide_panes() -> None:
    current = tmux_option_value("hide_panes").lower() in ("on", "1", "true", "yes")
    new_value = "off" if current else "on"
    set_tmux_option_value("hide_panes", new_value)


def close_sidebar() -> None:
    script_path = feature_script("sidebar", "close-sidebar.sh")
    pane_id = os.environ.get("TMUX_PANE", "")
    window_id = ""
    if pane_id:
        try:
            window_id = run_tmux("display-message", "-p", "-t", pane_id, "#{window_id}").strip()
        except subprocess.CalledProcessError:
            window_id = ""
    shell_command = " ".join(
        [
            "bash",
            shlex.quote(str(script_path)),
            shlex.quote(pane_id),
            shlex.quote(window_id),
        ]
    )
    subprocess.run(["tmux", "run-shell", "-b", shell_command], check=False)


def prompt_for_name(prompt: str, script_name: str, arguments: list[str], initial_value: str = "") -> None:
    script_path = scripts_dir() / script_name
    shell_parts = ["bash", shlex.quote(str(script_path))]
    shell_parts.extend(shlex.quote(argument) for argument in arguments)
    shell_parts.extend(["--name", '"%%%"'])
    command = ["tmux", "command-prompt"]
    if initial_value:
        command.extend(["-I", initial_value])
    command.extend(
        [
            "-p",
            prompt,
            f"run-shell -b {shlex.quote(' '.join(shell_parts))}",
        ]
    )
    subprocess.run(command, check=False)


def prompt_add_window(pane_id: str) -> None:
    try:
        metadata = run_tmux("display-message", "-p", "-t", pane_id, "#{session_name}|#{window_index}").strip()
    except subprocess.CalledProcessError:
        return
    if not metadata:
        return
    session_name, window_index = metadata.split("|", 1)
    if not session_name or not window_index:
        return
    prompt_for_name(
        "window name:",
        "features/sessions/add-window.sh",
        ["--session", session_name, "--window-index", window_index],
    )


def prompt_add_session(pane_id: str) -> None:
    try:
        session_name = run_tmux("display-message", "-p", "-t", pane_id, "#{session_name}").strip()
    except subprocess.CalledProcessError:
        return
    if not session_name:
        return
    prompt_for_name("session name:", "features/sessions/add-session.sh", ["--after-session", session_name])


def prompt_rename_session(pane_id: str) -> None:
    try:
        session_name = run_tmux("display-message", "-p", "-t", pane_id, "#{session_name}").strip()
    except subprocess.CalledProcessError:
        return
    if not session_name:
        return
    prompt_for_name(
        "rename session:",
        "features/sessions/rename-session.sh",
        ["--session", session_name],
        initial_value=session_name,
    )


def prompt_rename_window(pane_id: str) -> None:
    try:
        metadata = run_tmux("display-message", "-p", "-t", pane_id, "#{window_id}|#{window_name}").strip()
    except subprocess.CalledProcessError:
        return
    if not metadata:
        return
    window_id, window_name = metadata.split("|", 1)
    if not window_id or not window_name:
        return
    prompt_for_name(
        "rename window:",
        "features/sessions/rename-window.sh",
        ["--window", window_id],
        initial_value=window_name,
    )
