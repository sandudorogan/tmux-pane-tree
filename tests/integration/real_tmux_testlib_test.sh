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

client_log="$TEST_TMP/client.log"
real_tmux_attach_control_client_info work "$client_log"
client_pid="$REAL_TMUX_CLIENT_PID"
client_name="$REAL_TMUX_CLIENT_NAME"
[ -n "$client_pid" ] || fail 'expected attached client pid'
case "$client_name" in
  client-*) ;;
  *) fail "expected attached client name, got [$client_name]" ;;
esac

attached_client_name="$(real_tmux_wait_for_client_name)"
assert_eq "$attached_client_name" "$client_name"
kill "$client_pid" 2>/dev/null || true
