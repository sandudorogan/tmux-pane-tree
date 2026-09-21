#!/usr/bin/env bash
set -euo pipefail

. "$(dirname "$0")/testlib.sh"

assert_file_contains "sidebar.tmux" 'tmux-pane-tree.conf'
assert_file_contains "tmux-pane-tree.conf" 'client-active[198]'
assert_file_contains "tmux-pane-tree.conf" 'client-attached[199]'
assert_file_contains "tmux-pane-tree.conf" 'client-session-changed[200]'
assert_file_contains "tmux-pane-tree.conf" 'client-focus-in[202]'
assert_file_contains "tmux-pane-tree.conf" 'after-select-window[203]'
assert_file_contains "tmux-pane-tree.conf" 'after-select-pane[204]'
assert_file_contains "tmux-pane-tree.conf" 'session-window-changed[205]'
assert_file_contains "tmux-pane-tree.conf" 'after-split-window[206]'
assert_file_contains "tmux-pane-tree.conf" 'after-new-window[207]'
assert_file_contains "tmux-pane-tree.conf" 'after-kill-pane[208]'
assert_file_contains "tmux-pane-tree.conf" 'after-resize-pane[209]'
assert_file_contains "tmux-pane-tree.conf" 'after-rename-window[210]'
assert_file_contains "tmux-pane-tree.conf" 'after-rename-session[211]'
assert_file_contains "tmux-pane-tree.conf" 'on-pane-focus.sh'
assert_file_contains "tmux-pane-tree.conf" 'ensure-sidebar-pane.sh'
assert_file_contains "tmux-pane-tree.conf" 'notify-sidebar.sh'
assert_file_contains "tmux-pane-tree.conf" 'notify-sidebar.sh #{hook_pane}'
assert_file_contains "tmux-pane-tree.conf" 'handle-pane-exited.sh'
assert_file_contains "tmux-pane-tree.conf" 'configure-pane-border-format.sh'
assert_file_contains "tmux-pane-tree.conf" 'client-attached[199]" "run-shell -b'
assert_file_contains "tmux-pane-tree.conf" 'client-active[198]" "run-shell -b'
# after-new-window must call ensure-sidebar-pane (not notify-sidebar)
assert_not_contains "$(grep 'after-new-window' tmux-pane-tree.conf)" 'notify-sidebar'
