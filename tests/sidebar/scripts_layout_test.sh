#!/usr/bin/env bash
set -euo pipefail

. "$(dirname "$0")/testlib.sh"

assert_file_contains "sidebar.tmux" 'scripts/features/sidebar/configure-pane-border-format.sh'
assert_file_contains "sidebar.tmux" 'scripts/features/sidebar/toggle-sidebar.sh'
assert_file_contains "sidebar.tmux" 'scripts/features/sidebar/focus-sidebar.sh'
assert_file_contains "sidebar.tmux" 'scripts/features/sidebar/ensure-sidebar-pane.sh'
assert_file_contains "sidebar.tmux" 'scripts/features/sidebar/on-pane-focus.sh'
assert_file_contains "sidebar.tmux" 'scripts/features/sidebar/notify-sidebar.sh'
assert_file_contains "sidebar.tmux" 'scripts/features/sidebar/handle-pane-exited.sh'
assert_file_contains "sidebar.tmux" 'scripts/features/sidebar/apply-key-overrides.sh'
assert_file_contains "sidebar.tmux" 'scripts/features/context-menu/bind-context-menu.sh'

assert_file_contains "scripts/install-live.sh" 'scripts/features/hooks/hook-claude.sh'
assert_file_contains "scripts/install-live.sh" 'scripts/features/hooks/hook-codex.sh'
assert_file_contains "scripts/install-live.sh" 'scripts/features/sidebar/reload-sidebar-panes.sh'

assert_file_not_contains "sidebar.tmux" 'scripts/toggle-sidebar.sh'
assert_file_not_contains "sidebar.tmux" 'scripts/focus-sidebar.sh'
