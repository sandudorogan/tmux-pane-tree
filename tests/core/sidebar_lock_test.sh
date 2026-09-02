#!/usr/bin/env bash
set -euo pipefail

. "$(dirname "$0")/testlib.sh"

export TMUX_PANE_TREE_STATE_DIR="$TEST_TMP/state"
lock_dir="$TMUX_PANE_TREE_STATE_DIR/locks"

. scripts/core/lib.sh

# acquire stamps the holder pid, release clears it
sidebar_lock_acquire "state_1"
assert_eq "$(readlink "$lock_dir/state_1")" "$$"
sidebar_lock_release "state_1"
assert_file_absent "$lock_dir/state_1"

# releasing a lock held by somebody else must not steal it
mkdir -p "$lock_dir"
ln -s 2147483647 "$lock_dir/state_2"
sidebar_lock_release "state_2"
assert_eq "$(readlink "$lock_dir/state_2")" "2147483647"
rm -f "$lock_dir/state_2"

# a lock abandoned by a killed holder is broken at once, not waited out
dead_pid="$(bash -c 'printf "%s\n" "$$"')"
ln -s "$dead_pid" "$lock_dir/state_3"
started="$SECONDS"
sidebar_lock_acquire "state_3" 30
assert_eq "$(readlink "$lock_dir/state_3")" "$$"
if [ "$((SECONDS - started))" -gt 2 ]; then
  fail "stale lock should break immediately, waited $((SECONDS - started))s"
fi
sidebar_lock_release "state_3"

# a live holder is respected, then the timeout breaks the lock anyway so a
# recycled pid cannot wedge the plugin forever
sleep 30 &
live_pid="$!"
ln -s "$live_pid" "$lock_dir/state_4"
started="$SECONDS"
sidebar_lock_acquire "state_4" 1
waited="$((SECONDS - started))"
kill "$live_pid" 2>/dev/null || true
wait "$live_pid" 2>/dev/null || true
assert_eq "$(readlink "$lock_dir/state_4")" "$$"
if [ "$waited" -lt 1 ]; then
  fail "live holder should be respected for the timeout, waited ${waited}s"
fi
sidebar_lock_release "state_4"

# the lifecycle helpers ride on the same mutex and stay reentrant
unset TMUX_SIDEBAR_LIFECYCLE_LOCKED
acquire_sidebar_lifecycle_lock
assert_eq "$(readlink "$lock_dir/@tmux_sidebar_lifecycle")" "$$"
acquire_sidebar_lifecycle_lock
assert_eq "$(readlink "$lock_dir/@tmux_sidebar_lifecycle")" "$$"
release_sidebar_lifecycle_lock
assert_file_absent "$lock_dir/@tmux_sidebar_lifecycle"

printf 'ok sidebar_lock\n'
