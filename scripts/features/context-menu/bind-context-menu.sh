#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(CDPATH= cd -- "$(dirname "$0")" && pwd)"
SCRIPTS_DIR="$(CDPATH= cd -- "$SCRIPT_DIR/../.." && pwd)"
. "$SCRIPTS_DIR/core/lib.sh"
CONTEXT_MENU_DIR="$SCRIPTS_DIR/features/context-menu"
SIDEBAR_STATE="$(print_state_dir)"

# Register a custom MouseDown3Pane binding that intercepts right-clicks on
# the sidebar pane and opens a context-sensitive display-menu. For non-sidebar
# panes, falls through to tmux's default right-click behavior.
#
# The binding is written to a tmux command file and loaded via source-file
# because it uses { } block syntax that bash cannot pass to tmux directly.
bind_file="$SIDEBAR_STATE/bind-mouse.tmux"
mkdir -p "$SIDEBAR_STATE"

# Flow: MouseDown3Pane →
#   if pane title matches "Sidebar":
#     run show-context-menu.sh (writes menu-cmd.tmux) → source-file menu-cmd.tmux
#   else:
#     default tmux behavior (check mouse_any_flag, show standard pane menu)
cat > "$bind_file" <<TMUX
bind-key -T root MouseDown3Pane if-shell -F "#{m:Sidebar,#{pane_title}}" { if-shell "bash $CONTEXT_MENU_DIR/show-context-menu.sh #{pane_id} #{mouse_y}" { source-file "$SIDEBAR_STATE/menu-cmd.tmux" } } { if-shell -F -t= "#{||:#{mouse_any_flag},#{&&:#{pane_in_mode},#{?#{m/r:(copy|view)-mode,#{pane_mode}},0,1}}}" { select-pane -t= ; send-keys -M } { display-menu -T "#[align=centre]#{pane_index} (#{pane_id})" -t= -xM -yM "Horizontal Split" h { split-window -h } "Vertical Split" v { split-window -v } "" "" "" "Swap Up" u { swap-pane -U } "Swap Down" d { swap-pane -D } "" "" "" Kill X { kill-pane } Respawn R { respawn-pane -k } "#{?pane_marked,Unmark,Mark}" m { select-pane -m } "#{?window_zoomed_flag,Unzoom,Zoom}" z { resize-pane -Z } } }
TMUX

tmux source-file "$bind_file"
