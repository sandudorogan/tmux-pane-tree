#!/usr/bin/env bash
set -euo pipefail

. "$(dirname "$0")/real_tmux_testlib.sh"

case "$REAL_TMUX_SOCKET_PATH" in
  "$TEST_TMP"/*) ;;
  *) fail "expected real tmux socket path [$REAL_TMUX_SOCKET_PATH] to live under [$TEST_TMP]" ;;
esac

real_tmux_start_server

session_name="$(real_tmux display-message -p -t work:editor '#{session_name}')"
assert_eq "$session_name" 'work'
