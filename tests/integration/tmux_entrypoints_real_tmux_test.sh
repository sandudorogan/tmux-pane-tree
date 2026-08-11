#!/usr/bin/env bash
set -euo pipefail

. "$(dirname "$0")/real_tmux_testlib.sh"

real_tmux_start_server

HOOK_MARKER='scripts/features/sidebar/'
EXPECTED_HOOK_COUNT="$(grep -c "^set-hook .*$HOOK_MARKER" "$REPO_ROOT/tmux-pane-tree.conf" || true)"
[ "$EXPECTED_HOOK_COUNT" -ge 13 ] \
  || fail "expected tmux-pane-tree.conf to declare at least 13 hooks, found $EXPECTED_HOOK_COUNT"

prefix_binding() {
  real_tmux list-keys -T prefix \
    | awk -v key="$1" '$4 == key { $1 = ""; $2 = ""; $3 = ""; $4 = ""; sub(/^ +/, ""); print }'
}

registered_hook_count() {
  real_tmux show-hooks -g | grep -c "$HOOK_MARKER" || true
}

reset_plugin_state() {
  real_tmux set-option -gu @tmux_sidebar_dir
  real_tmux set-option -gu @tmux_pane_tree_dir
  real_tmux bind-key t display-message unbound
  real_tmux bind-key T display-message unbound
  real_tmux show-hooks -g \
    | awk -v marker="$HOOK_MARKER" 'index($0, marker) { print $1 }' \
    | while IFS= read -r hook_name; do
        real_tmux set-hook -gu "$hook_name"
      done
  assert_eq "$(real_tmux show-options -gqv @tmux_sidebar_dir)" ""
  assert_eq "$(real_tmux show-options -gqv @tmux_pane_tree_dir)" ""
  assert_contains "$(prefix_binding t)" 'display-message unbound'
  assert_contains "$(prefix_binding T)" 'display-message unbound'
  assert_eq "$(registered_hook_count)" "0"
}

assert_config_applied() {
  assert_eq "$(real_tmux show-options -gqv @tmux_sidebar_dir)" "$REPO_ROOT"
  assert_eq "$(real_tmux show-options -gqv @tmux_pane_tree_dir)" "$REPO_ROOT"
  assert_contains "$(prefix_binding t)" 'toggle-sidebar.sh'
  assert_contains "$(prefix_binding T)" 'focus-sidebar.sh'
  assert_eq "$(registered_hook_count)" "$EXPECTED_HOOK_COUNT"
}

for entrypoint in "$REPO_ROOT"/*.tmux "$REPO_ROOT/tmux-pane-tree.conf"; do
  reset_plugin_state
  real_tmux_source_file "$entrypoint"
  assert_config_applied
done

reset_plugin_state
real_tmux_run_shell_capture "$REPO_ROOT/tmux-pane-tree.tmux"
assert_config_applied

reset_plugin_state
real_tmux_run_shell_capture "$REPO_ROOT/sidebar.tmux"
assert_eq "$(real_tmux show-options -gqv @tmux_sidebar_dir)" ""
assert_eq "$(real_tmux show-options -gqv @tmux_pane_tree_dir)" ""
assert_eq "$(registered_hook_count)" "0"
