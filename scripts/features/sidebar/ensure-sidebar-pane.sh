#!/usr/bin/env bash
set -euo pipefail

if [ "${TMUX_SIDEBAR_TRACE:-0}" = "1" ]; then
  export PS4='+ensure:${LINENO}: '
  set -x
fi

enabled="$(tmux show-options -gv @tmux_sidebar_enabled 2>/dev/null || printf '0\n')"
[ "$enabled" = "1" ] || exit 0

SCRIPT_DIR="$(CDPATH= cd -- "$(dirname "$0")" && pwd)"
SCRIPTS_DIR="$(CDPATH= cd -- "$SCRIPT_DIR/../.." && pwd)"
. "$SCRIPTS_DIR/core/lib.sh"
sidebar_enabled || exit 0
target_pane="${1:-}"
current_window="${2:-}"

if [ -z "$target_pane" ] && [ -z "$current_window" ]; then
  target_pane="$(tmux display-message -p '#{pane_id}' 2>/dev/null || true)"
fi
if [ -z "$current_window" ] && [ -n "$target_pane" ]; then
  current_window="$(tmux display-message -p -t "$target_pane" '#{window_id}' 2>/dev/null || true)"
fi
if [ -z "$current_window" ]; then
  current_window="$(tmux display-message -p '#{window_id}' 2>/dev/null || true)"
fi
[ -n "$current_window" ] || exit 0

sidebar_pane_option="$(sidebar_window_option "pane" "$current_window")"
sidebar_creating_option="$(sidebar_window_option "creating" "$current_window")"
sidebar_focus_option="$(sidebar_focus_request_option "$current_window")"
ensure_lock="@tmux_sidebar_ensure_$(window_key_for_id "$current_window")"
ensure_lock_acquired=0

cleanup() {
  tmux set-option -g -u "$sidebar_creating_option" 2>/dev/null || true
  tmux set-option -g -u "$sidebar_focus_option" 2>/dev/null || true
  if [ "$ensure_lock_acquired" = "1" ]; then
    tmux wait-for -U "$ensure_lock" 2>/dev/null || true
  fi
  release_sidebar_lifecycle_lock
}
trap cleanup EXIT

acquire_sidebar_lifecycle_lock

# `tmux wait-for -L` below provides the cross-platform lock. Use `flock`
# opportunistically when available, but do not require it on systems like macOS.
if command -v flock >/dev/null 2>&1; then
  lockfile="/tmp/tmux-sidebar-ensure-$(window_key_for_id "$current_window").lock"
  exec 9>"$lockfile"
  flock -n 9 || exit 0
fi

tmux wait-for -L "$ensure_lock"
ensure_lock_acquired=1
sidebar_enabled || exit 0

cmd_pattern="$(sidebar_pane_command_awk_pattern)"
stored_pane="$(tmux show-options -gv "$sidebar_pane_option" 2>/dev/null || true)"
if [ -n "$stored_pane" ]; then
  stored_details="$(tmux display-message -p -t "$stored_pane" '#{pane_title}|#{pane_current_command}|#{window_id}' 2>/dev/null || true)"
  if [ -n "$stored_details" ]; then
    IFS='|' read -r stored_title stored_command stored_window <<EOF
$stored_details
EOF
  else
    stored_title=""
    stored_command=""
    stored_window=""
  fi
  if [ "$stored_window" = "$current_window" ] && pane_is_known_sidebar "$stored_pane" "$stored_title" "$stored_command"; then
    exit 0
  fi
  tmux set-option -g -u "$sidebar_pane_option" 2>/dev/null || true
fi

existing_pane="$(
  list_marked_sidebar_panes \
    | awk -F'|' -v current_window="$current_window" '$2 == current_window { print $1; exit }'
)"
if [ -n "$existing_pane" ]; then
  tmux set-option -g "$sidebar_pane_option" "$existing_pane"
  exit 0
fi

creating="$(tmux show-options -gv "$sidebar_creating_option" 2>/dev/null || true)"
[ "$creating" != "1" ] || exit 0

sidebar_width="$(configured_sidebar_width)"
current_pane="$target_pane"
if [ -z "$current_pane" ]; then
  current_pane="$(
    tmux list-panes -t "$current_window" -F '#{pane_id}|#{pane_active}' 2>/dev/null \
      | awk -F'|' '$2 == 1 { print $1; exit }'
  )"
fi
if [ -z "$current_pane" ]; then
  current_pane="$(tmux display-message -p '#{pane_id}' 2>/dev/null || true)"
fi
sidebar_command="$(sidebar_ui_command "$SCRIPTS_DIR")"
focus_sidebar="$(tmux show-options -gv "$sidebar_focus_option" 2>/dev/null || true)"

sidebar_enabled || exit 0
save_sidebar_window_snapshot "$current_window" "$current_pane"
tmux set-option -g "$sidebar_creating_option" 1

split_window_args=(-h -b -d -f -l "$sidebar_width" -P -F '#{pane_id}')
if [ -n "$current_pane" ]; then
  split_window_args=(-t "$current_pane" "${split_window_args[@]}")
fi
sidebar_pane="$(tmux split-window "${split_window_args[@]}" "$sidebar_command")"
tmux set-option -g "$sidebar_pane_option" "$sidebar_pane"
mark_sidebar_pane "$sidebar_pane"
tmux set-option -p -t "$sidebar_pane" allow-set-title off 2>/dev/null || true
tmux select-pane -t "$sidebar_pane" -T "$(sidebar_pane_title)"
if [ "$focus_sidebar" = "1" ]; then
  tmux select-pane -t "$sidebar_pane"
elif [ -n "$current_pane" ]; then
  tmux select-pane -t "$current_pane"
fi
