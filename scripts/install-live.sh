#!/usr/bin/env bash
set -euo pipefail

PLUGIN_SRC="${PLUGIN_SRC:-$(CDPATH= cd -- "$(dirname "$0")/.." && pwd)}"
PLUGIN_DST="${PLUGIN_DST:-$HOME/.config/tmux/plugins/tmux-sidebar}"
TMUX_CONF="${TMUX_CONF:-$HOME/.config/tmux/tmux.conf}"
CLAUDE_SETTINGS="${CLAUDE_SETTINGS:-$HOME/.claude/settings.json}"
CODEX_CONFIG="${CODEX_CONFIG:-$HOME/.codex/config.toml}"
TIMESTAMP="${TIMESTAMP:-$(date +%Y%m%d%H%M%S)}"

mkdir -p "$(dirname "$PLUGIN_DST")"
rm -rf "$PLUGIN_DST"
mkdir -p "$PLUGIN_DST"
cp -R "$PLUGIN_SRC"/. "$PLUGIN_DST"/
chmod +x "$PLUGIN_DST"/sidebar.tmux "$PLUGIN_DST"/examples/*.sh
find "$PLUGIN_DST/scripts" -type f -name '*.sh' -exec chmod +x {} +

cp "$TMUX_CONF" "$TMUX_CONF.bak-tmux-sidebar-$TIMESTAMP"
python3 - <<'PY'
from pathlib import Path

path = Path.home() / ".config/tmux/tmux.conf"
old_line = 'if-shell "test -f ~/.config/tmux/plugins/tmux-sidebar/sidebar.tmux" "source-file ~/.config/tmux/plugins/tmux-sidebar/sidebar.tmux"'
line = "run-shell '~/.config/tmux/plugins/tmux-sidebar/sidebar.tmux'"
text = path.read_text()
text = text.replace(old_line + "\n", "")
text = text.replace("\n" + old_line, "")
text = text.replace(line + "\n", "")
text = text.replace("\n" + line, "")
tpm_line = "run '~/.config/tmux/plugins/tpm/tpm'"
if tpm_line in text:
    text = text.replace(tpm_line, f"{tpm_line}\n{line}", 1)
else:
    text = text.rstrip() + "\n" + line + "\n"
path.write_text(text)
PY

cp "$CLAUDE_SETTINGS" "$CLAUDE_SETTINGS.bak-tmux-sidebar-$TIMESTAMP"
python3 - <<'PY'
import json
from pathlib import Path

path = Path.home() / ".claude/settings.json"
data = json.loads(path.read_text())
hooks = data.setdefault("hooks", {})
command = str(Path.home() / ".config/tmux/plugins/tmux-sidebar/scripts/features/hooks/hook-claude.sh")

def ensure_event(event_name: str, async_enabled: bool) -> None:
    rules = hooks.setdefault(event_name, [])
    target = None
    for rule in rules:
        if rule.get("matcher", "") == "":
            target = rule
            break
    if target is None:
        target = {"matcher": "", "hooks": []}
        rules.append(target)
    hook_list = target.setdefault("hooks", [])
    for hook in hook_list:
        if hook.get("type") == "command" and hook.get("command") == command:
            hook["timeout"] = 10
            if async_enabled:
                hook["async"] = True
            else:
                hook.pop("async", None)
            return
    entry = {"type": "command", "command": command, "timeout": 10}
    if async_enabled:
        entry["async"] = True
    hook_list.append(entry)

for event_name, async_enabled in [
    ("SessionStart", False),
    ("UserPromptSubmit", True),
    ("Stop", True),
    ("Notification", True),
    ("PermissionRequest", True),
    ("SessionEnd", True),
    ("SubagentStart", True),
]:
    ensure_event(event_name, async_enabled)

path.write_text(json.dumps(data, indent=2) + "\n")
PY

cp "$CODEX_CONFIG" "$CODEX_CONFIG.bak-tmux-sidebar-$TIMESTAMP"
python3 - <<'PY'
from pathlib import Path
import re

path = Path.home() / ".codex/config.toml"
text = path.read_text()
line = f'notify = ["bash", "{Path.home() / ".config/tmux/plugins/tmux-sidebar/scripts/features/hooks/hook-codex.sh"}"]'
if re.search(r"^notify\s*=\s*\[.*\]$", text, flags=re.M):
    text = re.sub(r"^notify\s*=\s*\[.*\]$", line, text, count=1, flags=re.M)
else:
    text = text.rstrip() + "\n" + line + "\n"
path.write_text(text)
PY

if [ -n "${TMUX:-}" ]; then
  tmux show-hooks -g 2>/dev/null \
    | awk '/tmux-sidebar/ {print $1}' \
    | while IFS= read -r hook_name; do
        [ -n "$hook_name" ] || continue
        tmux set-hook -gu "$hook_name" || true
      done
  tmux source-file "$TMUX_CONF" || true
  bash "$PLUGIN_DST/scripts/features/sidebar/reload-sidebar-panes.sh" || true
fi
