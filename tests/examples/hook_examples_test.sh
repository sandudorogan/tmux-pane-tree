#!/usr/bin/env bash
set -euo pipefail

. "$(dirname "$0")/testlib.sh"

assert_file_contains "examples/claude-hook.sh" 'scripts/features/hooks/hook-claude.sh'
assert_file_contains "examples/codex-hook.sh" 'scripts/features/hooks/hook-codex.sh'
assert_file_contains "examples/opencode-hook.sh" 'scripts/features/hooks/hook-opencode.sh'
assert_file_contains "examples/cursor-hook.sh" 'scripts/features/hooks/hook-cursor.sh'
assert_file_contains "examples/claude-hook.sh" 'TMUX_PANE_TREE_PLUGIN_DIR'
assert_file_contains "examples/codex-hook.sh" 'TMUX_PANE_TREE_PLUGIN_DIR'
assert_file_contains "examples/opencode-hook.sh" 'TMUX_PANE_TREE_PLUGIN_DIR'
assert_file_contains "examples/cursor-hook.sh" 'TMUX_PANE_TREE_PLUGIN_DIR'
assert_file_contains "README.md" 'To patch Claude Code, Codex, Cursor, and OpenCode hook config after a manual install:'
assert_file_contains "README.md" 'bash ~/.config/tmux/plugins/tmux-pane-tree/scripts/features/hooks/install-agent-hooks.sh'
assert_file_contains "README.md" '--pane "$TMUX_PANE"'
assert_file_contains "README.md" '@tmux_pane_tree_install_agent_hooks'
assert_file_contains "README.md" '~/.config/opencode/plugins/tmux-pane-tree.js'
assert_file_contains "README.md" '.cursor/hooks.json'
assert_file_contains "README.md" '~/.codex/config.toml'
assert_file_contains "README.md" 'TMUX_PANE_TREE_PLUGIN_DIR'
assert_file_contains "README.md" 'the single `notify = [...]` line in `~/.codex/config.toml`'
