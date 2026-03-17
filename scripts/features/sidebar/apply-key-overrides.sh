#!/usr/bin/env bash
set -euo pipefail

plugin_dir="${TMUX_SIDEBAR_PLUGIN_DIR:-$(CDPATH= cd -- "$(dirname "$0")/../../.." && pwd)}"

toggle_key="$(tmux show-options -gv @tmux_sidebar_toggle_key 2>/dev/null || true)"
focus_key="$(tmux show-options -gv @tmux_sidebar_focus_key 2>/dev/null || true)"

if [ -n "$toggle_key" ] && [ "$toggle_key" != "t" ]; then
  tmux unbind-key t
  tmux bind-key "$toggle_key" run-shell -b "\"$plugin_dir/scripts/features/sidebar/toggle-sidebar.sh\""
fi

if [ -n "$focus_key" ] && [ "$focus_key" != "T" ]; then
  tmux unbind-key T
  tmux bind-key "$focus_key" run-shell -b "\"$plugin_dir/scripts/features/sidebar/focus-sidebar.sh\""
fi
