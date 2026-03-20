#!/usr/bin/env bash
set -euo pipefail

. "$(dirname "$0")/testlib.sh"

locked_state_dir="$TEST_TMP/locked-state"
mkdir -p "$locked_state_dir"
chmod 0555 "$locked_state_dir"

output="$(TMUX_PANE=%4 LOCKED_STATE_DIR="$locked_state_dir" python3 - <<'PY'
import importlib.util
import json
import os
from pathlib import Path

spec = importlib.util.spec_from_file_location("sidebar_ui", Path("scripts/ui/sidebar-ui.py"))
module = importlib.util.module_from_spec(spec)
spec.loader.exec_module(module)

locked_state_dir = Path(os.environ["LOCKED_STATE_DIR"])
module.STATE_DIR = locked_state_dir
module._last_row_map_json = ""

try:
    module._write_pid_file()
    module._write_row_map(
        [
            {"kind": "session", "session": "work"},
            {"kind": "pane", "session": "work", "window": "@1", "pane_id": "%4"},
        ],
        0,
    )
    result = {"ok": True}
except Exception as exc:  # pragma: no cover - test output documents failure mode
    result = {"ok": False, "error": type(exc).__name__}
finally:
    os.chmod(locked_state_dir, 0o755)

print(json.dumps(result, sort_keys=True))
PY
)"

assert_contains "$output" '"ok": true'
