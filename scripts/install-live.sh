#!/usr/bin/env bash
set -euo pipefail

PLUGIN_SRC="${PLUGIN_SRC:-$(CDPATH= cd -- "$(dirname "$0")/.." && pwd)}"
PLUGIN_DST="${PLUGIN_DST:-$HOME/.config/tmux/plugins/tmux-pane-tree}"
TMUX_CONF="${TMUX_CONF:-$HOME/.config/tmux/tmux.conf}"
CLAUDE_SETTINGS="${CLAUDE_SETTINGS:-$HOME/.claude/settings.json}"
CODEX_CONFIG="${CODEX_CONFIG:-$HOME/.codex/config.toml}"
CURSOR_HOOKS="${CURSOR_HOOKS:-$HOME/.cursor/hooks.json}"
TIMESTAMP="${TIMESTAMP:-$(date +%Y%m%d%H%M%S)}"

mkdir -p "$(dirname "$PLUGIN_DST")"
rm -rf "$PLUGIN_DST"
mkdir -p "$PLUGIN_DST"
cp -R "$PLUGIN_SRC"/. "$PLUGIN_DST"/
chmod +x "$PLUGIN_DST"/sidebar.tmux "$PLUGIN_DST"/tmux-pane-tree.tmux "$PLUGIN_DST"/examples/*.sh
find "$PLUGIN_DST/scripts" -type f -name '*.sh' -exec chmod +x {} +

cp "$TMUX_CONF" "$TMUX_CONF.bak-tmux-sidebar-$TIMESTAMP"
TMUX_CONF="$TMUX_CONF" PLUGIN_DST="$PLUGIN_DST" python3 - <<'PY'
import os
from pathlib import Path

tmux_conf = Path(os.environ["TMUX_CONF"]).expanduser()
plugin_dst = Path(os.environ["PLUGIN_DST"]).expanduser()
source_line = f"source-file {plugin_dst / 'tmux-pane-tree.tmux'}"

text = tmux_conf.read_text()
lines = []
plugin_shim_line = str(plugin_dst / "sidebar.tmux")
plugin_conf_line = str(plugin_dst / "sidebar.conf")
for line in text.splitlines(keepends=True):
    stripped = line.strip()
    if not stripped:
        lines.append(line)
        continue
    if "tmux-pane-tree.tmux" in stripped and "source-file" in stripped:
        continue
    if "source-file" in stripped and "sidebar.tmux" in stripped and (
        "tmux-sidebar" in line
        or "tmux-pane-tree" in line
        or plugin_shim_line in stripped
    ):
        continue
    if "run-shell" in stripped and "sidebar.tmux" in stripped and (
        "tmux-sidebar" in line
        or "tmux-pane-tree" in line
        or plugin_shim_line in stripped
    ):
        continue
    if "source-file" in stripped and "sidebar.conf" in stripped and (
        "tmux-sidebar" in line
        or "tmux-pane-tree" in line
        or plugin_conf_line in stripped
    ):
        continue
    if "run-shell" in stripped and "sidebar.conf" in stripped and (
        "tmux-sidebar" in line
        or "tmux-pane-tree" in line
        or plugin_conf_line in stripped
    ):
        continue
    if "if-shell" in stripped and "sidebar.tmux" in stripped and (
        "tmux-sidebar" in line
        or "tmux-pane-tree" in line
        or plugin_shim_line in stripped
    ):
        continue
    if "if-shell" in stripped and "sidebar.conf" in stripped and (
        "tmux-sidebar" in line
        or "tmux-pane-tree" in line
        or plugin_conf_line in stripped
    ):
        continue
    if "tmux-sidebar" in line and ("sidebar.tmux" in line or "sidebar.conf" in line):
        continue
    lines.append(line)

text = "".join(lines)

tpm_line = "run '~/.config/tmux/plugins/tpm/tpm'"
if tpm_line in text:
    text = text.replace(tpm_line, f"{tpm_line}\n{source_line}\n", 1)
else:
    text = text.rstrip() + ("\n" if text and not text.endswith("\n") else "") + source_line + "\n"

tmux_conf.write_text(text)
PY

CLAUDE_SETTINGS="$CLAUDE_SETTINGS" \
CODEX_CONFIG="$CODEX_CONFIG" \
CURSOR_HOOKS="$CURSOR_HOOKS" \
TIMESTAMP="$TIMESTAMP" \
bash "$PLUGIN_DST/scripts/features/hooks/install-agent-hooks.sh"

if [ -n "${TMUX:-}" ]; then
  tmux show-hooks -g 2>/dev/null \
    | awk '/tmux-sidebar/ {print $1}' \
    | while IFS= read -r hook_name; do
        [ -n "$hook_name" ] || continue
        tmux set-hook -gu "$hook_name" || true
      done
  tmux show-hooks -gw 2>/dev/null \
    | awk '/tmux-sidebar/ {print $1}' \
    | while IFS= read -r hook_name; do
        [ -n "$hook_name" ] || continue
        tmux set-hook -guw "$hook_name" || true
      done
  tmux show-hooks -gp 2>/dev/null \
    | awk '/tmux-sidebar/ {print $1}' \
    | while IFS= read -r hook_name; do
        [ -n "$hook_name" ] || continue
        tmux set-hook -gup "$hook_name" || true
      done
  tmux source-file "$TMUX_CONF" || true
  bash "$PLUGIN_DST/scripts/features/sidebar/reload-sidebar-panes.sh" || true
fi
