#!/usr/bin/env bash
set -euo pipefail

. "$(dirname "$0")/../testlib.sh"

SCRIPTS_DIR="$(CDPATH= cd -- "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"

make_fake_cursor_plugin_dir() {
  local plugin_dir="$1"
  local label="$2"

  mkdir -p "$plugin_dir/scripts/features/hooks"
  cat > "$plugin_dir/scripts/features/hooks/hook-cursor.sh" <<EOF
#!/usr/bin/env bash
set -euo pipefail

printf '%s\n' "$label" > "\${TEST_CURSOR_PLUGIN_SELECTION:?}"
cat > "\${TEST_CURSOR_PLUGIN_PAYLOAD:?}"
EOF
  chmod +x "$plugin_dir/scripts/features/hooks/hook-cursor.sh"
}

test_cursor_hook_prefers_tmux_pane_tree_plugin_dir_over_legacy() {
  local new_plugin_dir="$TEST_TMP/plugins/tmux-pane-tree"
  local legacy_plugin_dir="$TEST_TMP/plugins/tmux-sidebar"
  local selection_file="$TEST_TMP/cursor-plugin-selection.txt"
  local payload_file="$TEST_TMP/cursor-plugin-payload.json"

  make_fake_cursor_plugin_dir "$new_plugin_dir" "new"
  make_fake_cursor_plugin_dir "$legacy_plugin_dir" "legacy"

  TMUX_PANE_TREE_PLUGIN_DIR="$new_plugin_dir" \
  TMUX_SIDEBAR_PLUGIN_DIR="$legacy_plugin_dir" \
  TEST_CURSOR_PLUGIN_SELECTION="$selection_file" \
  TEST_CURSOR_PLUGIN_PAYLOAD="$payload_file" \
  CURSOR_HOOK_EVENT_NAME="sessionStart" \
  bash "$SCRIPTS_DIR/examples/cursor-hook.sh"

  assert_eq "$(cat "$selection_file")" "new"
  assert_file_contains "$payload_file" '"hook_event_name":"sessionStart"'
}

test_cursor_hook_falls_back_to_tmux_sidebar_plugin_dir() {
  local legacy_plugin_dir="$TEST_TMP/plugins/tmux-sidebar-fallback"
  local selection_file="$TEST_TMP/cursor-plugin-selection-fallback.txt"
  local payload_file="$TEST_TMP/cursor-plugin-payload-fallback.json"

  make_fake_cursor_plugin_dir "$legacy_plugin_dir" "legacy"

  TMUX_SIDEBAR_PLUGIN_DIR="$legacy_plugin_dir" \
  TEST_CURSOR_PLUGIN_SELECTION="$selection_file" \
  TEST_CURSOR_PLUGIN_PAYLOAD="$payload_file" \
  CURSOR_HOOK_EVENT_NAME="sessionEnd" \
  bash "$SCRIPTS_DIR/examples/cursor-hook.sh"

  assert_eq "$(cat "$selection_file")" "legacy"
  assert_file_contains "$payload_file" '"hook_event_name":"sessionEnd"'
}

test_cursor_hook_falls_back_to_tmux_sidebar_plugin_dir
test_cursor_hook_prefers_tmux_pane_tree_plugin_dir_over_legacy
