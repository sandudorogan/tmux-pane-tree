#!/usr/bin/env bash
set -euo pipefail

. "$(dirname "$0")/testlib.sh"

fake_tmux_no_sidebar
fake_tmux_register_pane "%1" "work" "@1" "editor" "nvim" "nvim" "4"

python3 - <<'PY'
import importlib.util
from pathlib import Path

spec = importlib.util.spec_from_file_location("sidebar_ui", Path("scripts/sidebar-ui.py"))
module = importlib.util.module_from_spec(spec)
spec.loader.exec_module(module)

module.prompt_add_window("%1")
module.prompt_add_session("%1")
PY

assert_file_contains "$TEST_TMUX_DATA_DIR/commands.log" 'command-prompt -p window name:'
assert_file_contains "$TEST_TMUX_DATA_DIR/commands.log" 'add-window.sh --session work --window-index 4 --name "%%%"'
assert_file_contains "$TEST_TMUX_DATA_DIR/commands.log" 'command-prompt -p session name:'
assert_file_contains "$TEST_TMUX_DATA_DIR/commands.log" 'add-session.sh --after-session work --name "%%%"'
