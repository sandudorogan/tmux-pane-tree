#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(CDPATH= cd -- "$(dirname "$0")" && pwd)"
PLUGIN_DST="${PLUGIN_DST:-$(CDPATH= cd -- "$SCRIPT_DIR/../../.." && pwd)}"
CLAUDE_SETTINGS="${CLAUDE_SETTINGS:-$HOME/.claude/settings.json}"
CODEX_CONFIG="${CODEX_CONFIG:-$HOME/.codex/config.toml}"
CURSOR_HOOKS="${CURSOR_HOOKS:-$HOME/.cursor/hooks.json}"
OPENCODE_PLUGIN="${OPENCODE_PLUGIN:-$HOME/.config/opencode/plugins/tmux-pane-tree.js}"
PI_EXTENSION="${PI_EXTENSION:-$HOME/.pi/agent/extensions/tmux-pane-tree.ts}"
KIRO_AGENT="${KIRO_AGENT:-$HOME/.kiro/agents/tmux-pane-tree.json}"
KIRO_CLI_SETTINGS="${KIRO_CLI_SETTINGS:-$HOME/.kiro/settings/cli.json}"
TIMESTAMP="${TIMESTAMP:-$(date +%Y%m%d%H%M%S)}"

mkdir -p \
  "$(dirname "$CLAUDE_SETTINGS")" \
  "$(dirname "$CODEX_CONFIG")" \
  "$(dirname "$CURSOR_HOOKS")" \
  "$(dirname "$OPENCODE_PLUGIN")" \
  "$(dirname "$PI_EXTENSION")" \
  "$(dirname "$KIRO_AGENT")" \
  "$(dirname "$KIRO_CLI_SETTINGS")"

if [ -f "$CLAUDE_SETTINGS" ]; then
  cp "$CLAUDE_SETTINGS" "$CLAUDE_SETTINGS.bak-tmux-sidebar-$TIMESTAMP"
else
  printf '{}\n' > "$CLAUDE_SETTINGS"
fi

CLAUDE_SETTINGS="$CLAUDE_SETTINGS" PLUGIN_DST="$PLUGIN_DST" python3 - <<'END_CLAUDE'
import json
import os
from pathlib import Path

path = Path(os.environ["CLAUDE_SETTINGS"]).expanduser()
plugin_dir = Path(os.environ["PLUGIN_DST"]).expanduser()
text = path.read_text().strip()
data = json.loads(text) if text else {}
if not isinstance(data, dict):
    data = {}
hooks = data.setdefault("hooks", {})
command = str(plugin_dir / "scripts/features/hooks/hook-claude.sh")

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
    ("SubagentStop", True),
    ("Notification", True),
    ("PermissionRequest", True),
    ("SessionEnd", True),
    ("SubagentStart", True),
]:
    ensure_event(event_name, async_enabled)

path.write_text(json.dumps(data, indent=2) + "\n")
END_CLAUDE

if [ -f "$CODEX_CONFIG" ]; then
  cp "$CODEX_CONFIG" "$CODEX_CONFIG.bak-tmux-sidebar-$TIMESTAMP"
else
  : > "$CODEX_CONFIG"
fi

CODEX_CONFIG="$CODEX_CONFIG" PLUGIN_DST="$PLUGIN_DST" python3 - <<'END_CODEX'
from pathlib import Path
import os
import re

path = Path(os.environ["CODEX_CONFIG"]).expanduser()
plugin_dir = Path(os.environ["PLUGIN_DST"]).expanduser()
text = path.read_text()
line = f'notify = ["bash", "{plugin_dir / "scripts/features/hooks/hook-codex.sh"}"]'
if re.search(r"^notify\s*=\s*\[.*\]$", text, flags=re.M):
    text = re.sub(r"^notify\s*=\s*\[.*\]$", line, text, count=1, flags=re.M)
else:
    text = text.rstrip() + ("\n" if text.rstrip() else "") + line + "\n"
path.write_text(text)
END_CODEX

if [ -f "$CURSOR_HOOKS" ]; then
  cp "$CURSOR_HOOKS" "$CURSOR_HOOKS.bak-tmux-sidebar-$TIMESTAMP"
else
  printf '{\n  "version": 1,\n  "hooks": {}\n}\n' > "$CURSOR_HOOKS"
fi

CURSOR_HOOKS="$CURSOR_HOOKS" PLUGIN_DST="$PLUGIN_DST" python3 - <<'END_CURSOR'
import json
import os
from pathlib import Path

path = Path(os.environ["CURSOR_HOOKS"]).expanduser()
plugin_dir = Path(os.environ["PLUGIN_DST"]).expanduser()
text = path.read_text().strip()
data = json.loads(text) if text else {}
if not isinstance(data, dict):
    data = {}
data["version"] = 1
hooks = data.setdefault("hooks", {})
if not isinstance(hooks, dict):
    raise SystemExit("cursor hooks config must contain an object-valued 'hooks' field")
command = str(plugin_dir / "scripts/features/hooks/hook-cursor.sh")

def ensure_event(event_name: str) -> None:
    entries = hooks.setdefault(event_name, [])
    if not isinstance(entries, list):
        entries = []
        hooks[event_name] = entries
    for entry in entries:
        if entry.get("command") == command:
            entry["timeout"] = 10
            return
    entries.append({"command": command, "timeout": 10})

for event_name in (
    "sessionStart",
    "sessionEnd",
    "beforeSubmitPrompt",
    "preToolUse",
    "postToolUse",
    "postToolUseFailure",
    "subagentStart",
    "subagentStop",
    "afterAgentThought",
    "afterAgentResponse",
    "stop",
):
    ensure_event(event_name)

path.write_text(json.dumps(data, indent=2) + "\n")
END_CURSOR

if [ -f "$OPENCODE_PLUGIN" ]; then
  cp "$OPENCODE_PLUGIN" "$OPENCODE_PLUGIN.bak-tmux-sidebar-$TIMESTAMP"
fi

OPENCODE_PLUGIN="$OPENCODE_PLUGIN" PLUGIN_DST="$PLUGIN_DST" python3 - <<'END_OPENCODE'
import os
from pathlib import Path

path = Path(os.environ["OPENCODE_PLUGIN"]).expanduser()
plugin_dir = Path(os.environ["PLUGIN_DST"]).expanduser()
hook = plugin_dir / "scripts/features/hooks/hook-opencode.sh"

path.write_text(
    """const hook = {hook_path!r}

export const TmuxSidebarPlugin = async () => {{
  return {{
    event: async ({{ event }}) => {{
      const eventType = String(event?.type ?? "")
      const status = String(
        event?.properties?.status?.type
        ?? event?.status
        ?? event?.state
        ?? ""
      )
      const message = String(
        event?.properties?.status?.message
        ?? event?.properties?.error?.message
        ?? event?.message
        ?? event?.summary
        ?? event?.transcript_summary
        ?? ""
      )

      if (!eventType && !status && !message) {{
        return
      }}

      const payload = JSON.stringify({{
        event: eventType,
        status,
        message,
      }})

      const proc = Bun.spawn(["bash", hook, payload], {{
        env: {{
          ...process.env,
        }},
        stdin: "ignore",
        stdout: "ignore",
        stderr: "ignore",
      }})

      await proc.exited
    }},
  }}
}}
""".format(hook_path=str(hook))
)
END_OPENCODE

if [ -f "$PI_EXTENSION" ]; then
  cp "$PI_EXTENSION" "$PI_EXTENSION.bak-tmux-sidebar-$TIMESTAMP"
fi

PI_EXTENSION="$PI_EXTENSION" PLUGIN_DST="$PLUGIN_DST" python3 - <<'END_PI'
import os
from pathlib import Path

path = Path(os.environ["PI_EXTENSION"]).expanduser()
plugin_dir = Path(os.environ["PLUGIN_DST"]).expanduser()
hook = plugin_dir / "scripts/features/hooks/hook-pi.sh"

path.write_text(
    """import type {{ ExtensionAPI }} from '@mariozechner/pi-coding-agent'

const hook = {hook_path!r}

function pickMessage(event: unknown): string {{
  if (!event || typeof event !== 'object') {{
    return ''
  }}

  const record = event as Record<string, unknown>
  for (const key of ['message', 'summary', 'prompt', 'toolName', 'tool_name']) {{
    const value = record[key]
    if (typeof value === 'string' && value.trim()) {{
      return value.trim()
    }}
  }}
  return ''
}}

async function emit(pi: ExtensionAPI, eventName: string, event: unknown): Promise<void> {{
  const payload = JSON.stringify({{
    event: eventName,
    message: pickMessage(event),
  }})
  try {{
    await pi.exec('bash', [hook, payload])
  }} catch {{
    // Hook failures should not break the agent session.
  }}
}}

export default function (pi: ExtensionAPI) {{
  pi.on('session_start', async (event) => emit(pi, 'session_start', event))
  pi.on('session_shutdown', async (event) => emit(pi, 'session_shutdown', event))
  pi.on('agent_start', async (event) => emit(pi, 'agent_start', event))
  pi.on('agent_end', async (event) => emit(pi, 'agent_end', event))
  pi.on('turn_start', async (event) => emit(pi, 'turn_start', event))
  pi.on('tool_call', async (event) => emit(pi, 'tool_call', event))
}}
""".format(hook_path=str(hook))
)
END_PI

if [ -f "$KIRO_AGENT" ]; then
  cp "$KIRO_AGENT" "$KIRO_AGENT.bak-tmux-sidebar-$TIMESTAMP"
fi

KIRO_AGENT="$KIRO_AGENT" PLUGIN_DST="$PLUGIN_DST" python3 - <<'END_KIRO_AGENT'
import json
import os
import shlex
from pathlib import Path

path = Path(os.environ["KIRO_AGENT"]).expanduser()
plugin_dir = Path(os.environ["PLUGIN_DST"]).expanduser()
hook = plugin_dir / "scripts/features/hooks/hook-kiro.sh"
command_prefix = f"bash {shlex.quote(str(hook))}"

data = {
    "name": "tmux-pane-tree",
    "description": "Update tmux-pane-tree sidebar status badges from Kiro hook events.",
    "includeMcpJson": True,
    "hooks": {
        "agentSpawn": [
            {"command": f"{command_prefix} agentSpawn"},
        ],
        "userPromptSubmit": [
            {"command": f"{command_prefix} userPromptSubmit"},
        ],
        "preToolUse": [
            {"matcher": "*", "command": f"{command_prefix} preToolUse"},
        ],
        "postToolUse": [
            {"matcher": "*", "command": f"{command_prefix} postToolUse"},
        ],
        "stop": [
            {"command": f"{command_prefix} stop"},
        ],
    },
}

path.write_text(json.dumps(data, indent=2) + "\n")
END_KIRO_AGENT

if [ -f "$KIRO_CLI_SETTINGS" ]; then
  cp "$KIRO_CLI_SETTINGS" "$KIRO_CLI_SETTINGS.bak-tmux-sidebar-$TIMESTAMP"
fi

KIRO_CLI_SETTINGS="$KIRO_CLI_SETTINGS" python3 - <<'END_KIRO_SETTINGS'
import json
import os
from pathlib import Path

path = Path(os.environ["KIRO_CLI_SETTINGS"]).expanduser()
text = path.read_text().strip() if path.exists() else ""
try:
    data = json.loads(text) if text else {}
except Exception:
    data = {}
if not isinstance(data, dict):
    data = {}

chat = data.get("chat")
if not isinstance(chat, dict):
    chat = {}
    data["chat"] = chat

current_default = str(chat.get("defaultAgent") or "").strip()
if current_default not in ("", "kiro_default", "default"):
    raise SystemExit(0)

chat["defaultAgent"] = "tmux-pane-tree"
path.write_text(json.dumps(data, indent=2) + "\n")
END_KIRO_SETTINGS
