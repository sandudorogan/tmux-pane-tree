#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(CDPATH= cd -- "$(dirname "$0")" && pwd)"
SCRIPTS_DIR="$(CDPATH= cd -- "$SCRIPT_DIR/../.." && pwd)"
. "$SCRIPTS_DIR/core/lib.sh"

pane_id=""
name=""
session_name=""

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

if [ -z "$session_name" ]; then
  [ -n "$pane_id" ] || exit 0
  session_name="$(tmux display-message -p -t "$pane_id" '#{session_name}' 2>/dev/null || true)"
  [ -n "$session_name" ] || exit 0
fi

tmux rename-session -t "$session_name" "$name"

current_order="$(get_pane_tree_option session_order)"
[ -n "$current_order" ] || exit 0

updated_order="$(
  printf '%s\n' "$current_order" | tr ',' '\n' | awk -v current="$session_name" -v renamed="$name" '
    $0 == "" { next }
    {
      value = $0
      if ($0 == current) {
        value = renamed
      }
      if (seen[value]) {
        next
      }
      seen[value] = 1
      order[++count] = value
    }
    END {
      for (i = 1; i <= count; i++) {
        printf "%s", order[i]
        if (i < count) {
          printf ","
        }
      }
    }
  '
)"

set_pane_tree_option session_order "$updated_order"
