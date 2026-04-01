#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(CDPATH= cd -- "$(dirname "$0")" && pwd)"
SCRIPTS_DIR="$(CDPATH= cd -- "$SCRIPT_DIR/../.." && pwd)"
. "$SCRIPTS_DIR/core/lib.sh"

pane_id="${1:-}"
window_id="${2:-}"

enabled="$(tmux show-options -gv @tmux_sidebar_enabled 2>/dev/null || printf '0\n')"

if [ -n "$pane_id" ]; then
  pane_title="$(tmux display-message -p -t "$pane_id" '#{pane_title}' 2>/dev/null || true)"
  if printf '%s\n' "$pane_title" | grep -Eq "$(sidebar_title_pattern)"; then
    # Focused pane IS the sidebar — no need to ensure or update anything
    exit 0
  fi
  tmux set-option -g @tmux_sidebar_main_pane "$pane_id"

  if [[ "$pane_id" =~ ^%[0-9]+$ ]]; then
    state_dir="$(print_state_dir)"
    state_file="$state_dir/pane-$pane_id.json"
    if [ -f "$state_file" ]; then
      clear_terminal_pane_state "$state_file" || true
    elif printf '%s\n' "$pane_title" | grep -qE '(: (done|needs-input|error))\s*$'; then
      tmp_file="$(mktemp "$state_dir/.pane-state.XXXXXX")"
      printf '{"pane_id":"%s","app":"claude","status":"idle","updated_at":%d}\n' \
        "$pane_id" "$(date +%s)" > "$tmp_file"
      mv "$tmp_file" "$state_file"
      signal_sidebar_refresh
    fi
  fi
fi

[ "$enabled" = "1" ] || exit 0
exec bash "$SCRIPT_DIR/ensure-sidebar-pane.sh" "$pane_id" "$window_id"
