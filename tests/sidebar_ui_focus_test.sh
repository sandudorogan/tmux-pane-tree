#!/usr/bin/env bash
set -euo pipefail

. "$(dirname "$0")/testlib.sh"

fake_tmux_register_pane "%1" "work" "@1" "editor" "nvim"
fake_tmux_register_pane "%99" "work" "@1" "editor" "Sidebar" "python3"
printf '%%1\n' > "$TEST_TMUX_DATA_DIR/current_pane.txt"

output="$(TMUX_PANE=%99 python3 - <<'PY'
import importlib.util
from pathlib import Path

spec = importlib.util.spec_from_file_location("sidebar_ui", Path("scripts/sidebar-ui.py"))
module = importlib.util.module_from_spec(spec)
spec.loader.exec_module(module)
print("1" if module.sidebar_has_focus() else "0")
PY
)"

assert_eq "$output" "0"

printf '%%99\n' > "$TEST_TMUX_DATA_DIR/current_pane.txt"

output="$(TMUX_PANE=%99 python3 - <<'PY'
import importlib.util
from pathlib import Path

spec = importlib.util.spec_from_file_location("sidebar_ui", Path("scripts/sidebar-ui.py"))
module = importlib.util.module_from_spec(spec)
spec.loader.exec_module(module)
print("1" if module.sidebar_has_focus() else "0")
PY
)"

assert_eq "$output" "1"
