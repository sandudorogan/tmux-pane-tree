#!/usr/bin/env bash
set -euo pipefail

. "$(dirname "$0")/testlib.sh"

output="$(python3 - <<'PY'
import importlib.util
import json
from pathlib import Path

spec = importlib.util.spec_from_file_location("sidebar_ui", Path("scripts/ui/sidebar-ui.py"))
module = importlib.util.module_from_spec(spec)
spec.loader.exec_module(module)

shortcuts = module.configured_shortcuts()
print(json.dumps(shortcuts, sort_keys=True))
pending, action = module.advance_shortcut_state("", "a", shortcuts)
print(json.dumps({"pending": pending, "action": action}, sort_keys=True))
pending, action = module.advance_shortcut_state(pending, "w", shortcuts)
print(json.dumps({"pending": pending, "action": action}, sort_keys=True))
pending, action = module.advance_shortcut_state("", "x", shortcuts)
print(json.dumps({"pending": pending, "action": action}, sort_keys=True))
PY
)"

assert_contains "$output" '{"add_session": "as", "add_window": "aw", "close_pane": "x"}'
assert_contains "$output" '{"action": null, "pending": "a"}'
assert_contains "$output" '{"action": "add_window", "pending": ""}'
assert_contains "$output" '{"action": "close_pane", "pending": ""}'

printf 'zw\n' > "$TEST_TMUX_DATA_DIR/option__tmux_sidebar_add_window_shortcut.txt"
printf 'zs\n' > "$TEST_TMUX_DATA_DIR/option__tmux_sidebar_add_session_shortcut.txt"

output="$(python3 - <<'PY'
import importlib.util
import json
from pathlib import Path

spec = importlib.util.spec_from_file_location("sidebar_ui", Path("scripts/ui/sidebar-ui.py"))
module = importlib.util.module_from_spec(spec)
spec.loader.exec_module(module)

shortcuts = module.configured_shortcuts()
print(json.dumps(shortcuts, sort_keys=True))
pending, action = module.advance_shortcut_state("", "z", shortcuts)
print(json.dumps({"pending": pending, "action": action}, sort_keys=True))
pending, action = module.advance_shortcut_state(pending, "s", shortcuts)
print(json.dumps({"pending": pending, "action": action}, sort_keys=True))
pending, action = module.advance_shortcut_state("", "x", shortcuts)
print(json.dumps({"pending": pending, "action": action}, sort_keys=True))
PY
)"

assert_contains "$output" '{"add_session": "zs", "add_window": "zw", "close_pane": "x"}'
assert_contains "$output" '{"action": null, "pending": "z"}'
assert_contains "$output" '{"action": "add_session", "pending": ""}'
assert_contains "$output" '{"action": "close_pane", "pending": ""}'

printf 'w\n' > "$TEST_TMUX_DATA_DIR/option__tmux_sidebar_add_window_shortcut.txt"
printf 'sess\n' > "$TEST_TMUX_DATA_DIR/option__tmux_sidebar_add_session_shortcut.txt"
printf 'xx\n' > "$TEST_TMUX_DATA_DIR/option__tmux_sidebar_close_pane_shortcut.txt"

output="$(python3 - <<'PY'
import importlib.util
import json
from pathlib import Path

spec = importlib.util.spec_from_file_location("sidebar_ui", Path("scripts/ui/sidebar-ui.py"))
module = importlib.util.module_from_spec(spec)
spec.loader.exec_module(module)

shortcuts = module.configured_shortcuts()
print(json.dumps(shortcuts, sort_keys=True))
pending, action = module.advance_shortcut_state("", "w", shortcuts)
print(json.dumps({"pending": pending, "action": action}, sort_keys=True))
pending, action = module.advance_shortcut_state("", "s", shortcuts)
print(json.dumps({"pending": pending, "action": action}, sort_keys=True))
pending, action = module.advance_shortcut_state(pending, "e", shortcuts)
print(json.dumps({"pending": pending, "action": action}, sort_keys=True))
pending, action = module.advance_shortcut_state(pending, "s", shortcuts)
print(json.dumps({"pending": pending, "action": action}, sort_keys=True))
pending, action = module.advance_shortcut_state(pending, "s", shortcuts)
print(json.dumps({"pending": pending, "action": action}, sort_keys=True))
pending, action = module.advance_shortcut_state("", "x", shortcuts)
print(json.dumps({"pending": pending, "action": action}, sort_keys=True))
pending, action = module.advance_shortcut_state(pending, "x", shortcuts)
print(json.dumps({"pending": pending, "action": action}, sort_keys=True))
PY
)"

assert_contains "$output" '{"add_session": "sess", "add_window": "w", "close_pane": "xx"}'
assert_contains "$output" '{"action": "add_window", "pending": ""}'
assert_contains "$output" '{"action": null, "pending": "s"}'
assert_contains "$output" '{"action": null, "pending": "se"}'
assert_contains "$output" '{"action": null, "pending": "ses"}'
assert_contains "$output" '{"action": "add_session", "pending": ""}'
assert_contains "$output" '{"action": null, "pending": "x"}'
assert_contains "$output" '{"action": "close_pane", "pending": ""}'

printf 'zw\n' > "$TEST_TMUX_DATA_DIR/option__tmux_sidebar_add_window_shortcut.txt"
printf 'zs\n' > "$TEST_TMUX_DATA_DIR/option__tmux_sidebar_add_session_shortcut.txt"
printf 'qs\n' > "$TEST_TMUX_DATA_DIR/option__tmux_sidebar_close_pane_shortcut.txt"

output="$(python3 - <<'PY'
import importlib.util
import json
from pathlib import Path

spec = importlib.util.spec_from_file_location("sidebar_ui", Path("scripts/ui/sidebar-ui.py"))
module = importlib.util.module_from_spec(spec)
spec.loader.exec_module(module)

print(json.dumps(module.configured_shortcuts(), sort_keys=True))
PY
)"

assert_contains "$output" '{"add_session": "as", "add_window": "aw", "close_pane": "x"}'

printf 'a\n' > "$TEST_TMUX_DATA_DIR/option__tmux_sidebar_add_window_shortcut.txt"
printf 'as\n' > "$TEST_TMUX_DATA_DIR/option__tmux_sidebar_add_session_shortcut.txt"
printf 'x\n' > "$TEST_TMUX_DATA_DIR/option__tmux_sidebar_close_pane_shortcut.txt"

output="$(python3 - <<'PY'
import importlib.util
import json
from pathlib import Path

spec = importlib.util.spec_from_file_location("sidebar_ui", Path("scripts/ui/sidebar-ui.py"))
module = importlib.util.module_from_spec(spec)
spec.loader.exec_module(module)

print(json.dumps(module.configured_shortcuts(), sort_keys=True))
PY
)"

assert_contains "$output" '{"add_session": "as", "add_window": "aw", "close_pane": "x"}'

printf '\n' > "$TEST_TMUX_DATA_DIR/option__tmux_sidebar_add_window_shortcut.txt"
printf 'zz\n' > "$TEST_TMUX_DATA_DIR/option__tmux_sidebar_add_session_shortcut.txt"
printf 'xy\n' > "$TEST_TMUX_DATA_DIR/option__tmux_sidebar_close_pane_shortcut.txt"

output="$(python3 - <<'PY'
import importlib.util
import json
from pathlib import Path

spec = importlib.util.spec_from_file_location("sidebar_ui", Path("scripts/ui/sidebar-ui.py"))
module = importlib.util.module_from_spec(spec)
spec.loader.exec_module(module)

print(json.dumps(module.configured_shortcuts(), sort_keys=True))
PY
)"

assert_contains "$output" '{"add_session": "as", "add_window": "aw", "close_pane": "x"}'

printf 'zz\n' > "$TEST_TMUX_DATA_DIR/option__tmux_sidebar_add_window_shortcut.txt"
printf 'xy\n' > "$TEST_TMUX_DATA_DIR/option__tmux_sidebar_add_session_shortcut.txt"
printf 'zz\n' > "$TEST_TMUX_DATA_DIR/option__tmux_sidebar_close_pane_shortcut.txt"

output="$(python3 - <<'PY'
import importlib.util
import json
from pathlib import Path

spec = importlib.util.spec_from_file_location("sidebar_ui", Path("scripts/ui/sidebar-ui.py"))
module = importlib.util.module_from_spec(spec)
spec.loader.exec_module(module)

print(json.dumps(module.configured_shortcuts(), sort_keys=True))
PY
)"

assert_contains "$output" '{"add_session": "as", "add_window": "aw", "close_pane": "x"}'

printf 'xy\n' > "$TEST_TMUX_DATA_DIR/option__tmux_sidebar_add_window_shortcut.txt"
printf '\n' > "$TEST_TMUX_DATA_DIR/option__tmux_sidebar_add_session_shortcut.txt"
printf 'zz\n' > "$TEST_TMUX_DATA_DIR/option__tmux_sidebar_close_pane_shortcut.txt"

output="$(python3 - <<'PY'
import importlib.util
import json
from pathlib import Path

spec = importlib.util.spec_from_file_location("sidebar_ui", Path("scripts/ui/sidebar-ui.py"))
module = importlib.util.module_from_spec(spec)
spec.loader.exec_module(module)

print(json.dumps(module.configured_shortcuts(), sort_keys=True))
PY
)"

assert_contains "$output" '{"add_session": "as", "add_window": "aw", "close_pane": "x"}'

printf 'xy\n' > "$TEST_TMUX_DATA_DIR/option__tmux_sidebar_add_window_shortcut.txt"
printf 'zz\n' > "$TEST_TMUX_DATA_DIR/option__tmux_sidebar_add_session_shortcut.txt"
printf '\n' > "$TEST_TMUX_DATA_DIR/option__tmux_sidebar_close_pane_shortcut.txt"

output="$(python3 - <<'PY'
import importlib.util
import json
from pathlib import Path

spec = importlib.util.spec_from_file_location("sidebar_ui", Path("scripts/ui/sidebar-ui.py"))
module = importlib.util.module_from_spec(spec)
spec.loader.exec_module(module)

print(json.dumps(module.configured_shortcuts(), sort_keys=True))
PY
)"

assert_contains "$output" '{"add_session": "as", "add_window": "aw", "close_pane": "x"}'

printf 'xy\n' > "$TEST_TMUX_DATA_DIR/option__tmux_sidebar_add_window_shortcut.txt"
printf 'xy\n' > "$TEST_TMUX_DATA_DIR/option__tmux_sidebar_add_session_shortcut.txt"
printf 'zz\n' > "$TEST_TMUX_DATA_DIR/option__tmux_sidebar_close_pane_shortcut.txt"

output="$(python3 - <<'PY'
import importlib.util
import json
from pathlib import Path

spec = importlib.util.spec_from_file_location("sidebar_ui", Path("scripts/ui/sidebar-ui.py"))
module = importlib.util.module_from_spec(spec)
spec.loader.exec_module(module)

print(json.dumps(module.configured_shortcuts(), sort_keys=True))
PY
)"

assert_contains "$output" '{"add_session": "as", "add_window": "aw", "close_pane": "x"}'

printf 'xy\n' > "$TEST_TMUX_DATA_DIR/option__tmux_sidebar_add_window_shortcut.txt"
printf 'zz\n' > "$TEST_TMUX_DATA_DIR/option__tmux_sidebar_add_session_shortcut.txt"
printf 'xy\n' > "$TEST_TMUX_DATA_DIR/option__tmux_sidebar_close_pane_shortcut.txt"

output="$(python3 - <<'PY'
import importlib.util
import json
from pathlib import Path

spec = importlib.util.spec_from_file_location("sidebar_ui", Path("scripts/ui/sidebar-ui.py"))
module = importlib.util.module_from_spec(spec)
spec.loader.exec_module(module)

print(json.dumps(module.configured_shortcuts(), sort_keys=True))
PY
)"

assert_contains "$output" '{"add_session": "as", "add_window": "aw", "close_pane": "x"}'

printf 'zz\n' > "$TEST_TMUX_DATA_DIR/option__tmux_sidebar_add_window_shortcut.txt"
printf 'xy\n' > "$TEST_TMUX_DATA_DIR/option__tmux_sidebar_add_session_shortcut.txt"
printf 'xy\n' > "$TEST_TMUX_DATA_DIR/option__tmux_sidebar_close_pane_shortcut.txt"

output="$(python3 - <<'PY'
import importlib.util
import json
from pathlib import Path

spec = importlib.util.spec_from_file_location("sidebar_ui", Path("scripts/ui/sidebar-ui.py"))
module = importlib.util.module_from_spec(spec)
spec.loader.exec_module(module)

print(json.dumps(module.configured_shortcuts(), sort_keys=True))
PY
)"

assert_contains "$output" '{"add_session": "as", "add_window": "aw", "close_pane": "x"}'
