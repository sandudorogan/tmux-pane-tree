from __future__ import annotations

import os
import re
from pathlib import Path

from .core import run_tmux, tmux_option_value
from .icon_config import (
    APP_ALIASES,
    ASCII_ICONS,
    DEFAULT_BADGES,
    FONT_DIRS_ENV,
    FONT_FILE_SUFFIXES,
    ICON_THEMES,
    LEGACY_FONT_DIRS_ENV,
    NERD_FONT_BADGES,
)


SEMVER_PATTERN = re.compile(r"^\d+\.\d+\.\d+(?:[-+][0-9A-Za-z.-]+)?$")
NON_AGENT_COMMANDS = {
    "",
    "ash",
    "bash",
    "fish",
    "htop",
    "ksh",
    "less",
    "nano",
    "nvim",
    "sh",
    "ssh",
    "tail",
    "tmux",
    "top",
    "vi",
    "vim",
    "yazi",
    "zsh",
}
BADGE_OPTION_SUFFIXES: dict[str, str] = {
    "running": "badge_running",
    "needs-input": "badge_needs_input",
    "done": "badge_done",
    "error": "badge_error",
}

_badge_cache: dict[str, str] | None = None
_icon_cache: dict[str, str] | None = None
_nerd_font_installed_cache: bool | None = None


def configured_badges() -> dict[str, str]:
    global _badge_cache
    if _badge_cache is not None:
        return _badge_cache
    badges = dict(NERD_FONT_BADGES if configured_icon_theme() == "nerdfont" else DEFAULT_BADGES)
    for status, suffix in BADGE_OPTION_SUFFIXES.items():
        custom = tmux_option_value(suffix)
        if custom:
            badges[status] = custom
    _badge_cache = badges
    return badges


def badge_for_status(status: str) -> str:
    return configured_badges().get(status, "")


def font_search_paths() -> tuple[Path, ...]:
    override = os.environ.get(FONT_DIRS_ENV)
    if override is None:
        override = os.environ.get(LEGACY_FONT_DIRS_ENV)
    if override is not None:
        return tuple(Path(path).expanduser() for path in override.split(os.pathsep) if path)
    home = Path.home()
    xdg_data_home = Path(os.environ.get("XDG_DATA_HOME", str(home / ".local" / "share")))
    return (
        home / "Library" / "Fonts",
        Path("/Library/Fonts"),
        Path("/System/Library/Fonts"),
        xdg_data_home / "fonts",
        home / ".fonts",
        Path("/usr/local/share/fonts"),
        Path("/usr/share/fonts"),
    )


def is_nerd_font_file(path: Path) -> bool:
    return path.suffix.lower() in FONT_FILE_SUFFIXES and bool(re.search(r"nerd\s*font", path.name, re.IGNORECASE))


def nerd_font_installed() -> bool:
    global _nerd_font_installed_cache
    if _nerd_font_installed_cache is not None:
        return _nerd_font_installed_cache
    for root in font_search_paths():
        try:
            if root.is_file():
                if is_nerd_font_file(root):
                    _nerd_font_installed_cache = True
                    return True
                continue
            candidates = root.rglob("*")
        except OSError:
            continue
        for candidate in candidates:
            try:
                if candidate.is_file() and is_nerd_font_file(candidate):
                    _nerd_font_installed_cache = True
                    return True
            except OSError:
                continue
    _nerd_font_installed_cache = False
    return False


def configured_icon_theme() -> str:
    theme_name = tmux_option_value("icon_theme").strip().lower()
    if theme_name and theme_name != "auto":
        return theme_name
    if nerd_font_installed():
        return "nerdfont"
    return "ascii"


def configured_icons() -> dict[str, str]:
    global _icon_cache
    if _icon_cache is not None:
        return _icon_cache
    theme_name = configured_icon_theme()
    icons = dict(ICON_THEMES.get(theme_name, ASCII_ICONS))
    for app in icons:
        custom = tmux_option_value(f"icon_{app}")
        if custom:
            icons[app] = custom
    _icon_cache = icons
    return icons


def icon_for_app(app: str) -> str:
    return configured_icons().get(app, "")


def normalize_token(value: str) -> str:
    token = value.strip().lower()
    if "/" in token:
        token = token.rsplit("/", 1)[-1]
    return token


def looks_like_codex(value: str) -> bool:
    return normalize_token(value).startswith("codex")


def looks_like_opencode(value: str) -> bool:
    return normalize_token(value).startswith("opencode")


def looks_like_cursor(value: str) -> bool:
    return normalize_token(value).startswith("cursor")


def looks_like_claude(value: str) -> bool:
    token = normalize_token(value)
    if token == "claude" or token.startswith("claude-") or token.startswith("claude_"):
        return True
    return bool(re.search(r"\bclaude\b", value, re.IGNORECASE))


def looks_like_semver(value: str) -> bool:
    return bool(SEMVER_PATTERN.match(normalize_token(value)))


def should_preserve_live_label(command: str, title: str) -> bool:
    command_token = normalize_token(command)
    title_token = normalize_token(title)
    return command_token in NON_AGENT_COMMANDS or title_token in NON_AGENT_COMMANDS


def state_agent_app(command: str, title: str, state: dict | None) -> str:
    app = str((state or {}).get("app", "")).strip().lower()
    status = str((state or {}).get("status", "")).strip().lower()
    state_command = str((state or {}).get("pane_current_command", ""))
    state_title = str((state or {}).get("pane_title", ""))
    if app not in ("claude", "codex", "opencode", "cursor"):
        return ""
    if app == "cursor":
        if status and status != "idle":
            return "cursor"
        return ""
    state_matches_codex = looks_like_codex(state_command) or looks_like_codex(state_title)
    if app == "codex" and status == "idle":
        if state_matches_codex:
            return "codex"
    if should_preserve_live_label(command, title):
        if app == "codex" and status in ("done", "needs-input", "error") and state_matches_codex:
            return app
        return ""
    if app == "claude" and (looks_like_semver(command) or looks_like_semver(title)):
        return "claude"
    if status and status != "idle":
        return app
    return ""


def claude_title_status(title: str) -> str:
    match = re.search(r":\s*([a-z_-]+)\s*$", title.strip().lower())
    if match:
        suffix = match.group(1)
        return {
            "done": "done",
            "error": "error",
            "needs-input": "needs-input",
            "running": "running",
        }.get(suffix, "")
    if re.match(r"^[\u2800-\u28FF]", title.strip()):
        return "running"
    return ""


def live_agent_app(command: str, title: str, state: dict | None) -> str:
    if looks_like_codex(command) or looks_like_codex(title):
        return "codex"
    if looks_like_opencode(command) or looks_like_opencode(title):
        return "opencode"
    if looks_like_cursor(command) or looks_like_cursor(title):
        return "cursor"
    if looks_like_claude(command) or looks_like_claude(title):
        return "claude"
    if looks_like_semver(command) and not should_preserve_live_label(command, title):
        return "claude"
    return state_agent_app(command, title, state)


def canonical_pane_app(command: str, title: str, state: dict | None) -> str:
    live_app = live_agent_app(command, title, state)
    if live_app:
        return live_app
    command_token = normalize_token(command)
    if command_token in APP_ALIASES:
        return APP_ALIASES[command_token]
    title_token = normalize_token(title)
    if title_token in APP_ALIASES:
        return APP_ALIASES[title_token]
    if command_token.startswith("python"):
        return "python"
    if command_token:
        return "unknown"
    return ""


def codex_terminal_status(pane_id: str) -> str:
    if not pane_id:
        return ""
    try:
        capture = run_tmux("capture-pane", "-pt", pane_id)
    except Exception:
        return ""
    if re.search(r"^\s*[•·]\s+Working \([^)]*esc to interrupt\)\s*$", capture, re.MULTILINE):
        return "running"
    return ""


def effective_pane_status(pane_id: str, command: str, title: str, state: dict | None) -> str:
    live_app = live_agent_app(command, title, state)
    if not live_app:
        return ""

    status = str((state or {}).get("status", "")).strip().lower()
    if live_app == "codex":
        if status in ("running", "needs-input", "error", "done"):
            return status
        terminal_status = codex_terminal_status(pane_id)
        if terminal_status:
            return terminal_status
        return ""

    if status == "idle":
        return ""
    title_status = claude_title_status(title)
    if title_status:
        return title_status
    if status in ("running", "needs-input", "error", "done"):
        return status
    return ""


def pane_display_label(command: str, title: str, state: dict | None) -> str:
    live_app = live_agent_app(command, title, state)
    if live_app:
        return live_app
    return command


def pane_icon(command: str, title: str, state: dict | None) -> str:
    return icon_for_app(canonical_pane_app(command, title, state))


def auto_window_name(window_name: str, panes: list[dict]) -> bool:
    if (
        looks_like_semver(window_name)
        or looks_like_codex(window_name)
        or looks_like_opencode(window_name)
        or looks_like_cursor(window_name)
        or looks_like_claude(window_name)
    ):
        return True
    active_pane = next((pane for pane in panes if pane["active"]), panes[0] if panes else None)
    if active_pane is None:
        return False
    return normalize_token(window_name) == normalize_token(active_pane["label"])


def window_display_name(window_name: str, panes: list[dict], pane_states: dict[str, dict]) -> str:
    if not auto_window_name(window_name, panes):
        return window_name

    for pane in sorted(panes, key=lambda p: not p["active"]):
        pane_state = pane_states.get(pane["id"], {})
        label = pane_display_label(pane["label"], pane["title"], pane_state)
        if label != pane["label"]:
            return label

    return window_name
