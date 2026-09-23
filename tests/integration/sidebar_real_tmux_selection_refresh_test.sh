#!/usr/bin/env bash
set -euo pipefail

. "$(dirname "$0")/real_tmux_testlib.sh"

wait_for_selected_line() {
  local pane_id="$1"
  local expected="$2"
  local selected=""
  for _attempt in $(seq 1 100); do
    selected="$(real_tmux capture-pane -pt "$pane_id" | awk '/^▶/ { print; exit }')"
    case "$selected" in
      *"$expected"*) printf '%s\n' "$selected"; return 0 ;;
    esac
    sleep 0.05
  done
  fail "pane [$pane_id] never selected [$expected], last selection [$selected]"
}

real_tmux_start_server
real_tmux_source_plugin
real_tmux rename-session -t work SessionX
real_tmux rename-window -t SessionX:editor SessionX
real_tmux new-session -d -s codexCiao -n codexCiao 'tail -f /dev/null'
real_tmux set-option -g @tmux_sidebar_enabled 1
real_tmux set-option -g @tmux_sidebar_focus_on_open 0

for session in SessionX codexCiao; do
  window_id="$(real_tmux display-message -p -t "$session" '#{window_id}')"
  pane_id="$(real_tmux display-message -p -t "$session" '#{pane_id}')"
  printf -v ensure_cmd '%q %q %q' \
    "$REPO_ROOT/scripts/features/sidebar/ensure-sidebar-pane.sh" "$pane_id" "$window_id"
  real_tmux run-shell -b "$ensure_cmd"
  real_tmux_wait_for_sidebar_pane "$window_id" >/dev/null
done

real_tmux_attach_control_client_info SessionX "$TEST_TMP/client.log"
source_sidebar="$(real_tmux list-panes -t SessionX -F '#{pane_id}|#{pane_title}' | awk -F'|' '$2 == "Sidebar" { print $1; exit }')"
target_sidebar="$(real_tmux list-panes -t codexCiao -F '#{pane_id}|#{pane_title}' | awk -F'|' '$2 == "Sidebar" { print $1; exit }')"
source_window="$(real_tmux display-message -p -t SessionX '#{window_id}')"
source_pane="$(real_tmux list-panes -t SessionX -F '#{pane_id}|#{pane_title}' | awk -F'|' '$2 != "Sidebar" { print $1; exit }')"
target_pane="$(real_tmux list-panes -t codexCiao -F '#{pane_id}|#{pane_title}' | awk -F'|' '$2 != "Sidebar" { print $1; exit }')"
real_tmux select-pane -t "$source_sidebar"
real_tmux_wait_for_capture "$target_sidebar" 'SessionX' >/dev/null
sleep 0.2

real_tmux send-keys -t "$source_sidebar" G
wait_for_selected_line "$source_sidebar" 'tail' >/dev/null
real_tmux send-keys -t "$source_sidebar" Enter

for _attempt in $(seq 1 100); do
  client_session="$(real_tmux list-clients -F '#{session_name}' | head -1)"
  [ "$client_session" = 'codexCiao' ] && break
  sleep 0.01
done
assert_eq "$client_session" 'codexCiao'

target_selection="$(real_tmux capture-pane -pt "$target_sidebar" | awk '/^▶/ { print; exit }')"
assert_contains "$target_selection" 'tail'

printf -v stale_cmd '%q %q %q' \
  "$REPO_ROOT/scripts/features/sidebar/on-pane-focus.sh" "$source_pane" "$source_window"
real_tmux run-shell "$stale_cmd"
assert_eq "$(real_tmux show-options -gqv @tmux_sidebar_main_pane)" "$target_pane"

real_tmux select-pane -t "$source_pane"
sleep 0.1
assert_eq "$(real_tmux show-options -gqv @tmux_sidebar_main_pane)" "$target_pane"
target_selection="$(real_tmux capture-pane -pt "$target_sidebar" | awk '/^▶/ { print; exit }')"
assert_contains "$target_selection" 'tail'

real_tmux select-pane -t "$target_sidebar"
real_tmux send-keys -t "$target_sidebar" g g
wait_for_selected_line "$target_sidebar" 'bash' >/dev/null
real_tmux send-keys -t "$target_sidebar" Enter
for _attempt in $(seq 1 100); do
  client_session="$(real_tmux list-clients -F '#{session_name}' | head -1)"
  [ "$client_session" = 'SessionX' ] && break
  sleep 0.01
done
assert_eq "$client_session" 'SessionX'
source_selection="$(real_tmux capture-pane -pt "$source_sidebar" | awk '/^▶/ { print; exit }')"
assert_contains "$source_selection" 'bash'

kill "$REAL_TMUX_CLIENT_PID" 2>/dev/null || true
