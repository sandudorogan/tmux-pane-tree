#!/usr/bin/env bash
set -euo pipefail

. "$(dirname "$0")/../testlib.sh"

REPO_ROOT="$(CDPATH= cd -- "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
APPLIER="tmux-pane-tree.tmux"

tmux_entrypoints() {
  find "$REPO_ROOT" -maxdepth 1 -type f -name '*.tmux' | sort
}

exec_entrypoint() {
  : > "$TEST_TMUX_DATA_DIR/commands.log"
  "$1" >/dev/null 2>&1
}

test_entrypoints_are_exactly_the_expected_set() {
  local found
  found="$(cd "$REPO_ROOT" && printf '%s\n' *.tmux | sort)"
  assert_eq "$found" "$(printf 'sidebar.tmux\n%s' "$APPLIER")"
}

test_entrypoints_are_committed_executable() {
  local entrypoint mode
  while IFS= read -r entrypoint; do
    [ -x "$entrypoint" ] || fail "expected [$entrypoint] to be executable"
    mode="$(git -C "$REPO_ROOT" ls-files -s -- "$entrypoint" | cut -d' ' -f1)"
    assert_eq "$mode" "100755"
  done < <(tmux_entrypoints)
}

test_entrypoints_exit_zero_when_tpm_execs_them() {
  local entrypoint status
  while IFS= read -r entrypoint; do
    status=0
    "$entrypoint" >/dev/null 2>&1 || status="$?"
    assert_eq "$status" "0"
  done < <(tmux_entrypoints)
}

test_exactly_one_entrypoint_applies_the_config_on_exec() {
  local entrypoint applied total=0
  while IFS= read -r entrypoint; do
    exec_entrypoint "$entrypoint"
    applied="$(grep -c "source-file $REPO_ROOT/tmux-pane-tree.conf" "$TEST_TMUX_DATA_DIR/commands.log" || true)"
    assert_eq "$(grep -c 'source-file' "$TEST_TMUX_DATA_DIR/commands.log" || true)" "$applied"
    total=$((total + applied))
  done < <(tmux_entrypoints)
  assert_eq "$total" "1"
}

test_current_public_name_is_the_applier() {
  exec_entrypoint "$REPO_ROOT/$APPLIER"
  assert_file_contains "$TEST_TMUX_DATA_DIR/commands.log" "source-file $REPO_ROOT/tmux-pane-tree.conf"
}

test_entrypoints_are_exactly_the_expected_set
test_entrypoints_are_committed_executable
test_entrypoints_exit_zero_when_tpm_execs_them
test_exactly_one_entrypoint_applies_the_config_on_exec
test_current_public_name_is_the_applier
