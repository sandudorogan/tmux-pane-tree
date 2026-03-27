#\
#!/usr/bin/env bash
#\
CURRENT_DIR="$(CDPATH= cd -- "$(dirname "$0")" && pwd)"; tmux source-file "$CURRENT_DIR/tmux-pane-tree.tmux"; exit $?
source-file -F "#{d:current_file}/tmux-pane-tree.tmux"
