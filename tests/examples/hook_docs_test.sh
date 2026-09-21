#!/usr/bin/env bash
set -euo pipefail

. "$(dirname "$0")/testlib.sh"

assert_file_contains "README.md" 'Subagent completions are suppressed so only the parent session shows `done`.'
assert_file_contains "README.md" 'Claude Code needs `SessionStart`'
assert_file_contains "README.md" 'Cursor needs `sessionStart`, `sessionEnd`'
assert_file_contains "README.md" 'Codex suppression is best-effort via `permission_mode` and `session_id`.'
assert_file_contains "README.md" 'the single `notify = [...]` line in `~/.codex/config.toml`'

assert_file_contains "docs/index.html" 'Subagent completions are suppressed so only the parent session shows'
assert_file_contains "docs/index.html" '<code>~/.codex/config.toml</code>, the <code>notify</code> line'
assert_file_contains "docs/index.html" '~/.cursor/hooks.json'
assert_file_contains "docs/index.html" '~/.config/opencode/plugins/tmux-pane-tree.js'
assert_file_contains "docs/index.html" '~/.pi/agent/extensions/tmux-pane-tree.ts'
assert_file_contains "docs/index.html" '~/.kiro/agents/tmux-pane-tree.json'
