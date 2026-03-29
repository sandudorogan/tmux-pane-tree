#!/usr/bin/env bash
set -euo pipefail

. "$(dirname "$0")/testlib.sh"

fake_tmux_no_sidebar
fake_tmux_register_pane "%1" "work" "@1" "editor" "nvim" "nvim" "4"

export TEST_TMUX_PROMPT_RESPONSE="scratch"
python3 - <<'PY'
import importlib.util
from pathlib import Path

spec = importlib.util.spec_from_file_location("sidebar_ui", Path("scripts/ui/sidebar-ui.py"))
module = importlib.util.module_from_spec(spec)
spec.loader.exec_module(module)

module.prompt_add_window("%1")
PY
unset TEST_TMUX_PROMPT_RESPONSE

assert_file_contains "$TEST_TMUX_DATA_DIR/commands.log" 'new-window -d -a -t work:4 -n scratch'

fake_tmux_no_sidebar
fake_tmux_register_pane "%1" "session1" "@1" "editor" "nvim"
fake_tmux_set_tree <<'EOF'
session1|@1|editor|%1|nvim|shell|1
session2|@2|logs|%2|tail|tail|0
EOF

export TEST_TMUX_PROMPT_RESPONSE="my-session"
python3 - <<'PY'
import importlib.util
from pathlib import Path

spec = importlib.util.spec_from_file_location("sidebar_ui", Path("scripts/ui/sidebar-ui.py"))
module = importlib.util.module_from_spec(spec)
spec.loader.exec_module(module)

module.prompt_add_session("%1")
PY
unset TEST_TMUX_PROMPT_RESPONSE

assert_file_contains "$TEST_TMUX_DATA_DIR/commands.log" 'new-session -d -s my-session'
assert_eq "$(cat "$TEST_TMUX_DATA_DIR/option__tmux_pane_tree_session_order.txt")" 'session1,my-session,session2'

fake_tmux_no_sidebar
fake_tmux_register_pane "%1" "session1" "@1" "editor" "nvim"
printf 'session1,session2\n' > "$TEST_TMUX_DATA_DIR/option__tmux_pane_tree_session_order.txt"

export TEST_TMUX_PROMPT_RESPONSE="renamed-session"
python3 - <<'PY'
import importlib.util
from pathlib import Path

spec = importlib.util.spec_from_file_location("sidebar_ui", Path("scripts/ui/sidebar-ui.py"))
module = importlib.util.module_from_spec(spec)
spec.loader.exec_module(module)

module.prompt_rename_session("%1")
PY
unset TEST_TMUX_PROMPT_RESPONSE

assert_file_contains "$TEST_TMUX_DATA_DIR/commands.log" 'rename-session -t session1 renamed-session'
assert_eq "$(cat "$TEST_TMUX_DATA_DIR/option__tmux_pane_tree_session_order.txt")" 'renamed-session,session2'

fake_tmux_no_sidebar
fake_tmux_register_pane "%1" "work" "@1" "editor" "nvim" "nvim" "4"

export TEST_TMUX_PROMPT_RESPONSE="renamed-window"
python3 - <<'PY'
import importlib.util
from pathlib import Path

spec = importlib.util.spec_from_file_location("sidebar_ui", Path("scripts/ui/sidebar-ui.py"))
module = importlib.util.module_from_spec(spec)
spec.loader.exec_module(module)

module.prompt_rename_window("%1")
PY
unset TEST_TMUX_PROMPT_RESPONSE

assert_file_contains "$TEST_TMUX_DATA_DIR/commands.log" 'rename-window -t @1 renamed-window'
