#!/usr/bin/env bash
set -euo pipefail

. "$(dirname "$0")/testlib.sh"

assert_file_contains "examples/claude-hook.sh" 'scripts/features/hooks/hook-claude.sh'
assert_file_contains "examples/codex-hook.sh" 'scripts/features/hooks/hook-codex.sh'
assert_file_contains "examples/opencode-hook.sh" 'scripts/features/hooks/hook-opencode.sh'
assert_file_contains "README.md" '<prefix> t'
assert_file_contains "README.md" 'TMUX_PANE'
assert_file_contains "README.md" '@tmux_sidebar_install_agent_hooks'
assert_file_contains "README.md" 'opencode/plugins'
