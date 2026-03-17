#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(CDPATH= cd -- "$(dirname "$0")" && pwd)"
SCRIPTS_DIR="$(CDPATH= cd -- "$SCRIPT_DIR/../.." && pwd)"
. "$SCRIPTS_DIR/core/lib.sh"
pane_id="${1:-}"
[ -n "$pane_id" ] || exit 0
[[ "$pane_id" =~ ^%[0-9]+$ ]] || exit 0

state_dir="$(print_state_dir)"
state_file="$state_dir/pane-$pane_id.json"
[ -f "$state_file" ] || exit 0

clear_terminal_pane_state "$state_file" || true
