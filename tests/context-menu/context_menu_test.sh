#!/usr/bin/env bash
set -euo pipefail

CDPATH= cd -- "$(dirname "$0")" || exit 1
SCRIPT_DIR="$(pwd)"
. ./testlib.sh

REPO_ROOT="$(CDPATH= cd -- "$SCRIPT_DIR/../.." && pwd)"
SIDEBAR_UI="$REPO_ROOT/scripts/ui/sidebar-ui.py"

test_m_key_returns_context_menu_action() {
    output="$(python3 -c "
import sys; sys.path.insert(0, '$(dirname "$SIDEBAR_UI")')
from importlib.machinery import SourceFileLoader
mod = SourceFileLoader('sidebar_ui', '$SIDEBAR_UI').load_module()
result = mod.process_keypress(ord('m'), '%0', [], '', {})
print(result[2])
" 2>/dev/null)"
    assert_eq "$output" "context_menu"
}

test_row_map_written() {
    local state_dir="$TEST_TMP/state"
    mkdir -p "$state_dir"
    TMUX_SIDEBAR_STATE_DIR="$state_dir" TMUX_PANE="%99" python3 -c "
import sys, os
os.environ['TMUX_SIDEBAR_STATE_DIR'] = '$state_dir'
os.environ['TMUX_PANE'] = '%99'
sys.path.insert(0, '$(dirname "$SIDEBAR_UI")')
from importlib.machinery import SourceFileLoader
mod = SourceFileLoader('sidebar_ui', '$SIDEBAR_UI').load_module()
rows = [
    {'kind': 'session', 'session': 'main'},
    {'kind': 'window', 'session': 'main', 'window': '@1'},
    {'kind': 'pane', 'session': 'main', 'window': '@1', 'pane_id': '%0'},
]
mod._write_row_map(rows, 0)
" 2>/dev/null
    [ -f "$state_dir/rowmap-%99.json" ] || fail "rowmap file not created"
    assert_contains "$(cat "$state_dir/rowmap-%99.json")" '"kind": "session"'
    assert_contains "$(cat "$state_dir/rowmap-%99.json")" '"kind": "window"'
    assert_contains "$(cat "$state_dir/rowmap-%99.json")" '"kind": "pane"'
}

test_m_key_returns_context_menu_action
test_row_map_written
