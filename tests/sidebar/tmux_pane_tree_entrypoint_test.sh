#!/usr/bin/env bash
set -euo pipefail

. "$(dirname "$0")/../testlib.sh"

REPO_ROOT="$(CDPATH= cd -- "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"

test_new_public_entrypoint_exists_with_wiring() {
  [ -f "$REPO_ROOT/tmux-pane-tree.tmux" ] || fail "expected tmux-pane-tree.tmux at repo root"
  assert_file_contains "$REPO_ROOT/tmux-pane-tree.tmux" 'set -gF @tmux_pane_tree_dir'
  assert_file_contains "$REPO_ROOT/tmux-pane-tree.tmux" 'run-shell -b'
  assert_file_contains "$REPO_ROOT/tmux-pane-tree.tmux" 'toggle-sidebar.sh'
}

test_sidebar_tmux_is_shim_to_new_entrypoint() {
  assert_file_contains "$REPO_ROOT/sidebar.tmux" 'source-file'
  assert_file_contains "$REPO_ROOT/sidebar.tmux" 'tmux-pane-tree.tmux'
}

test_install_agent_hooks_option_alias_in_entrypoint() {
  assert_file_contains "$REPO_ROOT/tmux-pane-tree.tmux" '@tmux_pane_tree_install_agent_hooks'
  assert_file_contains "$REPO_ROOT/tmux-pane-tree.tmux" '@tmux_sidebar_install_agent_hooks'
  assert_file_contains "$REPO_ROOT/tmux-pane-tree.tmux" 'install-agent-hooks.sh'
}

test_new_public_entrypoint_exists_with_wiring
test_sidebar_tmux_is_shim_to_new_entrypoint
test_install_agent_hooks_option_alias_in_entrypoint
