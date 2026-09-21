#!/usr/bin/env bash
set -euo pipefail

. "$(dirname "$0")/testlib.sh"

assert_file_contains "README.md" 'Subagent completions are suppressed so only the parent session shows `done`.'
assert_file_contains "README.md" 'Claude Code needs `SessionStart`'
assert_file_contains "README.md" 'Cursor needs `sessionStart`, `sessionEnd`'
assert_file_contains "README.md" 'Codex suppression is best-effort via `permission_mode` and `session_id`.'
assert_file_contains "README.md" 'the single `notify = [...]` line in `~/.codex/config.toml`'

assert_file_contains "docs/index.html" 'Subagent completion badges stay hidden while the main session'
assert_file_contains "docs/index.html" 'Codex suppression is best-effort.'
assert_file_contains "docs/index.html" 'SubagentStart'
assert_file_contains "docs/index.html" 'subagentStart'
assert_file_contains "docs/index.html" 'single <code>notify = [...]</code> line in'
assert_file_contains "docs/index.html" '~/.pi/agent/extensions/tmux-pane-tree.ts'
assert_file_contains "docs/index.html" '~/.kiro/agents/tmux-pane-tree.json'
