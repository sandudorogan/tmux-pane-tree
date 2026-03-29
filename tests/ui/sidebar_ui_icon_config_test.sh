#!/usr/bin/env bash
set -euo pipefail

. "$(dirname "$0")/testlib.sh"

output="$(
python3 - <<'PY'
from scripts.ui.sidebar_ui_lib.icon_config import (
    APP_ALIASES,
    ASCII_ICONS,
    FONT_DIRS_ENV,
    ICON_THEMES,
    NERD_FONT_BADGES,
)

print(ASCII_ICONS["claude"])
print(ICON_THEMES["nerdfont"]["lazygit"])
print(APP_ALIASES["bash"])
print(NERD_FONT_BADGES["running"])
print(FONT_DIRS_ENV)
PY
)"

assert_contains "$output" 'C'
assert_contains "$output" '󰊢'
assert_contains "$output" 'shell'
assert_contains "$output" ''
assert_contains "$output" 'TMUX_PANE_TREE_FONT_DIRS'
