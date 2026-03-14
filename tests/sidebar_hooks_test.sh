#!/usr/bin/env bash
set -euo pipefail

. "$(dirname "$0")/testlib.sh"

assert_file_contains "sidebar.tmux" 'client-session-changed[200]'
assert_file_contains "sidebar.tmux" 'window-pane-changed[201]'
assert_file_contains "sidebar.tmux" 'pane-focus-in[202]'
assert_file_contains "sidebar.tmux" 'after-select-window[203]'
assert_file_contains "sidebar.tmux" 'client-session-changed[211]'
assert_file_contains "sidebar.tmux" 'after-select-window[212]'
assert_file_contains "sidebar.tmux" 'after-select-pane[213]'
assert_file_contains "sidebar.tmux" 'window-pane-changed[214]'
assert_file_contains "sidebar.tmux" 'session-window-changed[215]'
assert_file_contains "sidebar.tmux" 'session-window-changed[216]'
assert_file_contains "sidebar.tmux" 'remember-main-pane.sh'
assert_file_contains "sidebar.tmux" 'ensure-sidebar-pane.sh'
assert_file_contains "sidebar.tmux" 'handle-pane-exited.sh'
assert_file_contains "sidebar.tmux" 'configure-pane-border-format.sh'
