#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(CDPATH= cd -- "$(dirname "$0")" && pwd)"
SCRIPTS_DIR="$(CDPATH= cd -- "$SCRIPT_DIR/../.." && pwd)"
. "$SCRIPTS_DIR/core/lib.sh"
pane_id=""
app=""
status=""
message=""
updated_at=""

current_timestamp_ns() {
  python3 - <<'PY'
from __future__ import annotations

import time

print(time.time_ns())
PY
}

status_rank() {
  case "${1:-}" in
    needs-input|error) printf '4\n' ;;
    done) printf '3\n' ;;
    running) printf '2\n' ;;
    idle) printf '1\n' ;;
    *) printf '0\n' ;;
  esac
}

while [ "$#" -gt 0 ]; do
  case "$1" in
    --pane)
      pane_id="${2:-}"
      shift 2
      ;;
    --app)
      app="${2:-}"
      shift 2
      ;;
    --status)
      status="${2:-}"
      shift 2
      ;;
    --message)
      message="${2:-}"
      shift 2
      ;;
    --updated-at)
      updated_at="${2:-}"
      shift 2
      ;;
    *)
      printf 'unknown arg: %s\n' "$1" >&2
      exit 1
      ;;
  esac
done

if [ -z "$pane_id" ]; then
  pane_id="$(tmux display-message -p '#{pane_id}' 2>/dev/null || true)"
fi

[ -n "$pane_id" ] || exit 0
[[ "$pane_id" =~ ^%[0-9]+$ ]] || { printf 'invalid pane_id: %s\n' "$pane_id" >&2; exit 1; }
[ -n "$status" ] || exit 0

state_dir="$(print_state_dir)"
mkdir -p "$state_dir"
state_file="$state_dir/pane-$pane_id.json"
state_lock="@tmux_sidebar_state_${pane_id#%}"
tmux wait-for -L "$state_lock"
trap 'tmux wait-for -U "$state_lock" 2>/dev/null || true' EXIT

if [ -z "$updated_at" ]; then
  updated_at="$(current_timestamp_ns)"
fi
[[ "$updated_at" =~ ^[0-9]+$ ]] || { printf 'invalid updated_at: %s\n' "$updated_at" >&2; exit 1; }

if [ -f "$state_file" ]; then
  existing_updated_at="$(json_get_number "$state_file" "updated_at")"
  if [ -n "$existing_updated_at" ] && [ "$existing_updated_at" -gt "$updated_at" ]; then
    exit 0
  fi
  if [ -n "$existing_updated_at" ] && [ "$existing_updated_at" -eq "$updated_at" ]; then
    existing_status="$(json_get_string "$state_file" "status")"
    if [ "$(status_rank "$existing_status")" -gt "$(status_rank "$status")" ]; then
      exit 0
    fi
  fi
fi

session_name=""
window_id=""
window_name=""
pane_title=""
pane_current_command=""

metadata="$(tmux display-message -p -t "$pane_id" '#{session_name}|#{window_id}|#{window_name}|#{pane_title}|#{pane_current_command}' 2>/dev/null || true)"
if [ -n "$metadata" ]; then
  IFS='|' read -r session_name window_id window_name pane_title pane_current_command <<EOF
$metadata
EOF
elif [ -f "$state_file" ]; then
  session_name="$(json_get_string "$state_file" "session_name")"
  window_id="$(json_get_string "$state_file" "window_id")"
  window_name="$(json_get_string "$state_file" "window_name")"
  pane_title="$(json_get_string "$state_file" "pane_title")"
  pane_current_command="$(json_get_string "$state_file" "pane_current_command")"
fi

tmp_file="$(mktemp "$state_dir/.pane-state.XXXXXX")"
if printf '{"pane_id":"%s","session_name":"%s","window_id":"%s","window_name":"%s","pane_title":"%s","pane_current_command":"%s","app":"%s","status":"%s","message":"%s","updated_at":%s}\n' \
  "$(json_escape "$pane_id")" \
  "$(json_escape "$session_name")" \
  "$(json_escape "$window_id")" \
  "$(json_escape "$window_name")" \
  "$(json_escape "$pane_title")" \
  "$(json_escape "$pane_current_command")" \
  "$(json_escape "$app")" \
  "$(json_escape "$status")" \
  "$(json_escape "$message")" \
  "$updated_at" > "$tmp_file" \
  && mv "$tmp_file" "$state_file"
then
  :
else
  rm -f "$tmp_file"
  exit 1
fi
signal_sidebar_refresh
