#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(CDPATH= cd -- "$(dirname "$0")" && pwd)"
SCRIPTS_DIR="$(CDPATH= cd -- "$SCRIPT_DIR/../.." && pwd)"
. "$SCRIPTS_DIR/core/lib.sh"

pane_id=""
name=""
selected_session=""

while [ "$#" -gt 0 ]; do
  case "$1" in
    --pane)
      pane_id="${2:-}"
      shift 2
      ;;
    --after-session)
      selected_session="${2:-}"
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

if [ -z "$selected_session" ]; then
  [ -n "$pane_id" ] || exit 0
  selected_session="$(tmux display-message -p -t "$pane_id" '#{session_name}' 2>/dev/null || true)"
  [ -n "$selected_session" ] || exit 0
fi

tmux new-session -d -s "$name"

current_order="$(get_pane_tree_option session_order)"
if [ -n "$current_order" ]; then
  base_order="$(printf '%s\n' "$current_order" | tr ',' '\n')"
else
  base_order="$(tmux list-panes -a -F '#{session_name}' 2>/dev/null | awk '!seen[$0]++')"
fi

updated_order="$(
  printf '%s\n' "$base_order" | awk -v selected="$selected_session" -v inserted_name="$name" '
    $0 == "" { next }
    seen[$0] { next }
    {
      order[++count] = $0
      seen[$0] = 1
    }
    END {
      inserted = 0
      for (i = 1; i <= count; i++) {
        output[++output_count] = order[i]
        if (order[i] == selected && !inserted) {
          output[++output_count] = inserted_name
          inserted = 1
        }
      }
      if (!inserted) {
        output[++output_count] = inserted_name
      }
      for (i = 1; i <= output_count; i++) {
        printf "%s", output[i]
        if (i < output_count) {
          printf ","
        }
      }
    }
  '
)"

set_pane_tree_option session_order "$updated_order"
