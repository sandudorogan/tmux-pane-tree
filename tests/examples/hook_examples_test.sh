#!/usr/bin/env bash
set -euo pipefail

. "$(dirname "$0")/testlib.sh"

assert_file_contains "examples/claude-hook.sh" 'update-pane-state.sh'
assert_file_contains "examples/claude-hook.sh" '--app claude'
assert_file_contains "examples/codex-hook.sh" '--app codex'
assert_file_contains "examples/opencode-hook.sh" '--app opencode'
assert_file_contains "README.md" '<prefix> t'
assert_file_contains "README.md" 'TMUX_PANE'
