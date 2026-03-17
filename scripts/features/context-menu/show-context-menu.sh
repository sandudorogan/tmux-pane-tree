#!/usr/bin/env bash
set -euo pipefail

# Called from tmux MouseDown3Pane via if-shell (synchronous).
# Reads the row-map written by sidebar-ui.py, determines what
# was clicked, and writes the display-menu command to a temp file.
# The calling tmux binding then source-files this to open the menu
# in the mouse event context (so -xM -yM and hold-release work).

SCRIPT_DIR="$(CDPATH= cd -- "$(dirname "$0")" && pwd)"
SCRIPTS_DIR="$(CDPATH= cd -- "$SCRIPT_DIR/../.." && pwd)"
. "$SCRIPTS_DIR/core/lib.sh"

sidebar_pane="${1:?sidebar pane id required}"
mouse_y="${2:-0}"

state_dir="$(print_state_dir)"
rowmap_file="$state_dir/rowmap-${sidebar_pane}.json"
menu_file="$state_dir/menu-cmd.tmux"

# If rowmap doesn't exist yet (first render not completed), treat as empty area.
if [ ! -f "$rowmap_file" ]; then
    kind="null"
    session="" window="" pane_id=""
else
    # Look up the clicked row in the rowmap and extract all fields in one call.
    # The rowmap is written by sidebar-ui.py on every render with scroll_offset
    # so we can map screen y-coordinate back to the tree item.
    read -r kind session window pane_id < <(python3 -c "
import json, sys
data = json.load(open('$rowmap_file'))
rows = data.get('rows', [])
idx = $mouse_y + data.get('scroll_offset', 0)
if 0 <= idx < len(rows):
    r = rows[idx]
    print(r.get('kind',''), r.get('session',''), r.get('window',''), r.get('pane_id',''))
else:
    print('null', '', '', '')
")
fi

sidebar_scripts_dir="$SCRIPTS_DIR/features/sidebar"

# Escape single quotes for tmux command strings (POSIX: ' → '\'' )
escape_tmux() { printf '%s' "$1" | sed "s/'/'\\\\''/g"; }

# Empty area (clicked below last tree row)
if [ "$kind" = "null" ]; then
    cat > "$menu_file" <<TMUX
display-menu -xM -yM -T "#[align=centre] Sidebar " \
  "New Session" "s" "command-prompt -p 'session name:' \"new-session -d -s '%%' \\\\; switch-client -t '%%'\"" \
  "New Window"  "w" "new-window" \
  "" "" "" \
  "Refresh"       "r" "run-shell -b 'bash $sidebar_scripts_dir/refresh-sidebar.sh'" \
  "Close Sidebar" "q" "run-shell -b 'bash $sidebar_scripts_dir/close-sidebar.sh'"
TMUX
    exit 0
fi

qs="$(escape_tmux "$session")"

# Build context-specific display-menu command and write to menu_file.
# The tmux binding source-files this in the mouse event context so that
# -xM -yM positions the menu at the cursor and hold-release selection works.
case "$kind" in
    session)
        cat > "$menu_file" <<TMUX
display-menu -xM -yM -T "#[align=centre] $(escape_tmux "$session") " \
  "Switch to"    "s" "switch-client -t '$qs'" \
  "Rename"       "r" "command-prompt -I '$qs' -p 'Rename session:' \"rename-session -t '$qs' '%%'\"" \
  "New Window"   "w" "new-window -t '$qs'" \
  "Detach"       "d" "detach-client -s '$qs'" \
  "" "" "" \
  "Kill Session" "x" "confirm-before -p 'Kill session? (y/n)' \"kill-session -t '$qs'\""
TMUX
        ;;
    window)
        qw="$(escape_tmux "$window")"
        cat > "$menu_file" <<TMUX
display-menu -xM -yM -T "#[align=centre] $(escape_tmux "$session"):$(escape_tmux "$window") " \
  "Select"            "s" "switch-client -t '$qs' \\; select-window -t '$qw'" \
  "Rename"            "r" "command-prompt -I '' -p 'Rename window:' \"rename-window -t '$qw' '%%'\"" \
  "New Window After"  "w" "new-window -a -t '$qw'" \
  "" "" "" \
  "Split Horizontal"  "h" "split-window -h -t '$qw'" \
  "Split Vertical"    "v" "split-window -v -t '$qw'" \
  "" "" "" \
  "Kill Window"       "x" "confirm-before -p 'Kill window? (y/n)' \"kill-window -t '$qw'\""
TMUX
        ;;
    pane)
        qw="$(escape_tmux "$window")"
        qp="$(escape_tmux "$pane_id")"
        cat > "$menu_file" <<TMUX
display-menu -xM -yM -T "#[align=centre] $(escape_tmux "$pane_id") " \
  "Select"            "s" "switch-client -t '$qs' \\; select-window -t '$qw' \\; select-pane -t '$qp'" \
  "Zoom"              "z" "resize-pane -Z -t '$qp'" \
  "" "" "" \
  "Split Horizontal"  "h" "split-window -h -t '$qp'" \
  "Split Vertical"    "v" "split-window -v -t '$qp'" \
  "Break to Window"   "!" "break-pane -d -t '$qp'" \
  "" "" "" \
  "Mark"              "m" "select-pane -m -t '$qp'" \
  "" "" "" \
  "Kill Pane"         "x" "confirm-before -p 'Kill pane? (y/n)' \"kill-pane -t '$qp'\""
TMUX
        ;;
esac
