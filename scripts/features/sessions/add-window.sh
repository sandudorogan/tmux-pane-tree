#!/usr/bin/env bash
set -euo pipefail

pane_id=""
name=""
session_name=""
window_index=""

while [ "$#" -gt 0 ]; do
  case "$1" in
    --pane)
      pane_id="${2:-}"
      shift 2
      ;;
    --session)
      session_name="${2:-}"
      shift 2
      ;;
    --window-index)
      window_index="${2:-}"
      shift 2
      ;;
    --name)
      name="${2:-}"
      shift 2
      ;;
    *)
      printf 'unknown argument: %s\n' "$1" >&2
      exit 1
      ;;
  esac
done

if [ -z "${name//[[:space:]]/}" ]; then
  exit 0
fi

if [ -z "$session_name" ] || [ -z "$window_index" ]; then
  [ -n "$pane_id" ] || exit 0
  metadata="$(tmux display-message -p -t "$pane_id" '#{session_name}|#{window_index}' 2>/dev/null || true)"
  [ -n "$metadata" ] || exit 0

  IFS='|' read -r session_name window_index <<EOF
$metadata
EOF
fi

[ -n "$session_name" ] || exit 0
[ -n "$window_index" ] || exit 0

tmux new-window -d -a -t "${session_name}:${window_index}" -n "$name"
