#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(CDPATH= cd -- "$(dirname "$0")" && pwd)"
SCRIPTS_DIR="$(CDPATH= cd -- "$SCRIPT_DIR/../.." && pwd)"
. "$SCRIPTS_DIR/core/lib.sh"
pane_id="${1:-}"
window_id="${2:-}"

if sidebar_enabled && [ -n "$pane_id" ] && [ -n "$window_id" ]; then
  acquire_sidebar_lifecycle_lock
  trap release_sidebar_lifecycle_lock EXIT
fi

if sidebar_enabled && [ -n "$pane_id" ] && [ -n "$window_id" ]; then
  tracked_pane_option="$(sidebar_window_option "pane" "$window_id")"
  tracked_pane="$(tmux show-options -gv "$tracked_pane_option" 2>/dev/null || true)"

  if [ "$tracked_pane" = "$pane_id" ]; then
    tmux set-option -g @tmux_sidebar_enabled 0
    restore_sidebar_window_snapshot_if_unchanged "$window_id"

    list_sidebar_panes \
      | while IFS='|' read -r other_pane_id other_window_id; do
          [ -n "$other_pane_id" ] || continue
          tmux kill-pane -t "$other_pane_id"
          [ -n "$other_window_id" ] || continue
          restore_sidebar_window_snapshot_if_unchanged "$other_window_id"
        done

    clear_sidebar_state_options
  fi
fi

signal_sidebar_refresh
