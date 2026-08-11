#!/usr/bin/env bash
set -euo pipefail

. "$(dirname "$0")/../testlib.sh"

REPO_ROOT="$(CDPATH= cd -- "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"

test_new_public_entrypoint_exists_with_wiring() {
  [ -f "$REPO_ROOT/tmux-pane-tree.conf" ] || fail "expected tmux-pane-tree.conf at repo root"
  assert_file_contains "$REPO_ROOT/tmux-pane-tree.conf" 'set -gF @tmux_pane_tree_dir'
  assert_file_contains "$REPO_ROOT/tmux-pane-tree.conf" 'run-shell -b'
  assert_file_contains "$REPO_ROOT/tmux-pane-tree.conf" 'toggle-sidebar.sh'
}

test_legacy_sidebar_tmux_still_sources_the_config() {
  assert_file_contains "$REPO_ROOT/sidebar.tmux" 'source-file -F "#{d:current_file}/tmux-pane-tree.conf"'
  assert_file_not_contains "$REPO_ROOT/sidebar.tmux" 'set-hook'
  assert_file_not_contains "$REPO_ROOT/sidebar.tmux" 'bind-key'
}

test_current_public_entrypoint_is_a_thin_polyglot() {
  [ -f "$REPO_ROOT/tmux-pane-tree.tmux" ] || fail "expected tmux-pane-tree.tmux entrypoint at repo root"
  assert_file_contains "$REPO_ROOT/tmux-pane-tree.tmux" 'tmux source-file "$CURRENT_DIR/tmux-pane-tree.conf"'
  assert_file_contains "$REPO_ROOT/tmux-pane-tree.tmux" 'source-file -F "#{d:current_file}/tmux-pane-tree.conf"'
  assert_file_not_contains "$REPO_ROOT/tmux-pane-tree.tmux" 'set-hook'
  assert_file_not_contains "$REPO_ROOT/tmux-pane-tree.tmux" 'bind-key'
}

test_install_agent_hooks_option_alias_in_entrypoint() {
  assert_file_contains "$REPO_ROOT/tmux-pane-tree.conf" '@tmux_pane_tree_install_agent_hooks'
  assert_file_contains "$REPO_ROOT/tmux-pane-tree.conf" '@tmux_sidebar_install_agent_hooks'
  assert_file_contains "$REPO_ROOT/tmux-pane-tree.conf" 'install-agent-hooks.sh'
}

test_new_public_entrypoint_exists_with_wiring
test_legacy_sidebar_tmux_still_sources_the_config
test_current_public_entrypoint_is_a_thin_polyglot
test_install_agent_hooks_option_alias_in_entrypoint
