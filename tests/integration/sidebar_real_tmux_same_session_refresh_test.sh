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
real_tmux rename-session -t work elephc
real_tmux rename-window -t elephc:editor SessionX
real_tmux new-window -d -t elephc -n 1246 'tail -f /dev/null'
real_tmux set-option -g @tmux_sidebar_enabled 1
real_tmux set-option -g @tmux_sidebar_focus_on_open 0

for window_name in SessionX 1246; do
  window_id="$(real_tmux display-message -p -t "elephc:$window_name" '#{window_id}')"
  pane_id="$(real_tmux display-message -p -t "elephc:$window_name" '#{pane_id}')"
  printf -v ensure_cmd '%q %q %q' \
    "$REPO_ROOT/scripts/features/sidebar/ensure-sidebar-pane.sh" "$pane_id" "$window_id"
  real_tmux run-shell -b "$ensure_cmd"
  real_tmux_wait_for_sidebar_pane "$window_id" >/dev/null
done

real_tmux_attach_control_client_info elephc "$TEST_TMP/client.log"
source_sidebar="$(real_tmux list-panes -t elephc:SessionX -F '#{pane_id}|#{pane_title}' | awk -F'|' '$2 == "Sidebar" { print $1; exit }')"
target_sidebar="$(real_tmux list-panes -t elephc:1246 -F '#{pane_id}|#{pane_title}' | awk -F'|' '$2 == "Sidebar" { print $1; exit }')"
real_tmux select-window -t elephc:SessionX
real_tmux select-pane -t "$source_sidebar"
real_tmux_wait_for_capture "$target_sidebar" 'SessionX' >/dev/null
sleep 0.2

real_tmux send-keys -t "$source_sidebar" G
wait_for_selected_line "$source_sidebar" 'tail' >/dev/null
real_tmux send-keys -t "$source_sidebar" Enter

for _attempt in $(seq 1 100); do
  client_window="$(real_tmux list-clients -F '#{window_name}' | head -1)"
  [ "$client_window" = '1246' ] && break
  sleep 0.01
done
assert_eq "$client_window" '1246'
target_selection="$(real_tmux capture-pane -pt "$target_sidebar" | awk '/^▶/ { print; exit }')"
assert_contains "$target_selection" 'tail'

real_tmux select-pane -t "$target_sidebar"
real_tmux send-keys -t "$target_sidebar" g g
wait_for_selected_line "$target_sidebar" 'bash' >/dev/null
real_tmux send-keys -t "$target_sidebar" Enter
for _attempt in $(seq 1 100); do
  client_window="$(real_tmux list-clients -F '#{window_name}' | head -1)"
  [ "$client_window" = 'SessionX' ] && break
  sleep 0.01
done
assert_eq "$client_window" 'SessionX'
source_selection="$(real_tmux capture-pane -pt "$source_sidebar" | awk '/^▶/ { print; exit }')"
assert_contains "$source_selection" 'bash'

kill "$REAL_TMUX_CLIENT_PID" 2>/dev/null || true
