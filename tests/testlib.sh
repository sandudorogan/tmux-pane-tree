#!/usr/bin/env bash
set -euo pipefail

TEST_TMP="$(mktemp -d "${TMPDIR:-/tmp}/tmux-sidebar-tests.XXXXXX")"
trap 'rm -rf "$TEST_TMP"' EXIT

output=""
TEST_BIN="$TEST_TMP/bin"
mkdir -p "$TEST_BIN" "$TEST_TMP/tmux"
export PATH="$TEST_BIN:$PATH"
export TEST_TMUX_DATA_DIR="$TEST_TMP/tmux"
: > "$TEST_TMUX_DATA_DIR/list_panes.txt"

SIDEBAR_PANE_TITLE="Sidebar"
SIDEBAR_LEGACY_PANE_TITLE="tmux-sidebar"

fail() {
  printf 'FAIL: %s\n' "$1" >&2
  exit 1
}

assert_eq() {
  local actual="$1"
  local expected="$2"
  if [ "$actual" != "$expected" ]; then
    fail "expected [$expected], got [$actual]"
  fi
}

run_script() {
  output="$(bash "$@" 2>&1)"
}

assert_file_contains() {
  local path="$1"
  local expected="$2"
  if ! grep -Fq -- "$expected" "$path"; then
    fail "expected [$path] to contain [$expected]"
  fi
}

assert_contains() {
  local haystack="$1"
  local needle="$2"
  case "$haystack" in
    *"$needle"*) ;;
    *) fail "expected output to contain [$needle]" ;;
  esac
}

assert_not_contains() {
  local haystack="$1"
  local needle="$2"
  case "$haystack" in
    *"$needle"*) fail "expected output to not contain [$needle]" ;;
    *) ;;
  esac
}

fake_tmux_register_pane() {
  local pane_id="$1"
  local session_name="$2"
  local window_id="$3"
  local window_name="$4"
  local pane_title="$5"
  local pane_current_command="${6:-$5}"
  local window_index="${7:-0}"
  cat > "$TEST_TMUX_DATA_DIR/pane_${pane_id//%/}.meta" <<EOF
session_name=$session_name
window_id=$window_id
window_name=$window_name
pane_title=$pane_title
pane_current_command=$pane_current_command
window_index=$window_index
EOF
}

fake_tmux_set_tree() {
  cat > "$TEST_TMUX_DATA_DIR/list_panes.txt"
}

fake_tmux_add_sidebar_pane() {
  local pane_id="$1"
  local window_id="$2"
  cat > "$TEST_TMUX_DATA_DIR/pane_${pane_id//%/}.meta" <<EOF
session_name=
window_id=$window_id
window_name=
pane_title=$SIDEBAR_PANE_TITLE
pane_current_command=python3
window_index=0
EOF
  printf '%s|%s|%s\n' "$pane_id" "$SIDEBAR_PANE_TITLE" "$window_id" >> "$TEST_TMUX_DATA_DIR/toggle_panes.txt"
}

fake_tmux_no_sidebar() {
  : > "$TEST_TMUX_DATA_DIR/toggle_panes.txt"
  printf '%%1\n' > "$TEST_TMUX_DATA_DIR/current_pane.txt"
  : > "$TEST_TMUX_DATA_DIR/commands.log"
  rm -f "$TEST_TMUX_DATA_DIR"/pane_*.meta
  rm -f "$TEST_TMUX_DATA_DIR"/option_*.txt
  rm -f "$TEST_TMUX_DATA_DIR"/window_layout_*.txt
}

fake_tmux_sidebar_count() {
  if [ ! -f "$TEST_TMUX_DATA_DIR/toggle_panes.txt" ]; then
    printf '0\n'
    return
  fi
  awk -F'|' -v title="$SIDEBAR_PANE_TITLE" -v legacy_title="$SIDEBAR_LEGACY_PANE_TITLE" '$2==title || $2==legacy_title { count++ } END { print count + 0 }' "$TEST_TMUX_DATA_DIR/toggle_panes.txt"
}

fake_tmux_current_pane() {
  cat "$TEST_TMUX_DATA_DIR/current_pane.txt"
}

fake_tmux_register_main_pane() {
  printf '%s\n' "$1" > "$TEST_TMUX_DATA_DIR/option__tmux_sidebar_main_pane.txt"
}

fake_tmux_set_window_layout() {
  local window_id="$1"
  local layout="$2"
  printf '%s\n' "$layout" > "$TEST_TMUX_DATA_DIR/window_layout_${window_id//@/_}.txt"
}

assert_file_not_contains() {
  local path="$1"
  local unexpected="$2"
  if grep -Fq -- "$unexpected" "$path"; then
    fail "expected [$path] to not contain [$unexpected]"
  fi
}

cat > "$TEST_BIN/tmux" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail

data_dir="${TEST_TMUX_DATA_DIR:?}"
command_name="${1:-}"
shift || true

case "$command_name" in
  display-message)
    format=""
    target=""
    while [ "$#" -gt 0 ]; do
      case "$1" in
        -p) shift ;;
        -t) target="$2"; shift 2 ;;
        *) format="$1"; shift ;;
      esac
    done
    if [ -z "$target" ] && [ "$format" = '#{pane_id}' ]; then
      cat "$data_dir/current_pane.txt"
      exit 0
    fi
    if [ -z "$target" ] && [ "$format" = '#{window_id}' ]; then
      current_pane="$(cat "$data_dir/current_pane.txt")"
      meta_file="$data_dir/pane_${current_pane//%/}.meta"
      [ -f "$meta_file" ] || exit 1
      . "$meta_file"
      printf '%s\n' "$window_id"
      exit 0
    fi
    if [ -z "$target" ] && [ "$format" = '#{window_layout}' ]; then
      current_pane="$(cat "$data_dir/current_pane.txt")"
      meta_file="$data_dir/pane_${current_pane//%/}.meta"
      [ -f "$meta_file" ] || exit 1
      . "$meta_file"
      layout_file="$data_dir/window_layout_${window_id//@/_}.txt"
      [ -f "$layout_file" ] || exit 1
      cat "$layout_file"
      exit 0
    fi
    if [ -z "$target" ] && [ "$format" = '#{pane_title}' ]; then
      current_pane="$(cat "$data_dir/current_pane.txt")"
      meta_file="$data_dir/pane_${current_pane//%/}.meta"
      [ -f "$meta_file" ] || exit 1
      . "$meta_file"
      printf '%s\n' "$pane_title"
      exit 0
    fi
    meta_file="$data_dir/pane_${target//%/}.meta"
    [ -f "$meta_file" ] || exit 1
    . "$meta_file"
    result="$format"
    result="${result//\#\{session_name\}/$session_name}"
    result="${result//\#\{window_id\}/$window_id}"
    result="${result//\#\{window_name\}/$window_name}"
    result="${result//\#\{window_index\}/$window_index}"
    result="${result//\#\{pane_title\}/$pane_title}"
    result="${result//\#\{pane_current_command\}/$pane_current_command}"
    if [ "$target" = "$(cat "$data_dir/current_pane.txt")" ]; then
      result="${result//\#\{pane_active\}/1}"
    else
      result="${result//\#\{pane_active\}/0}"
    fi
    printf '%s\n' "$result"
    ;;
  list-panes)
    format="${*: -1}"
    target_window=""
    while [ "$#" -gt 0 ]; do
      case "$1" in
        -t)
          target_window="$2"
          shift 2
          ;;
        *)
          shift
          ;;
      esac
    done
    if [[ "$format" == '#{pane_id}|#{pane_title}' || "$format" == '#{pane_id}|#{pane_title}|#{window_id}' || "$format" == '#{pane_id}' || "$format" == '#{session_name}' ]]; then
      found="0"
      if [ "$format" = '#{session_name}' ]; then
        awk -F'|' '{ print $1 }' "$data_dir/list_panes.txt"
        exit 0
      fi
      for meta_file in "$data_dir"/pane_*.meta; do
        [ -e "$meta_file" ] || continue
        . "$meta_file"
        pane_id="%${meta_file##*_}"
        pane_id="${pane_id%.meta}"
        if [ -n "$target_window" ] && [ "$window_id" != "$target_window" ]; then
          continue
        fi
        case "$format" in
          '#{pane_id}|#{pane_title}')
            printf '%s|%s\n' "$pane_id" "$pane_title"
            ;;
          '#{pane_id}|#{pane_title}|#{window_id}')
            printf '%s|%s|%s\n' "$pane_id" "$pane_title" "$window_id"
            ;;
          '#{pane_id}')
            printf '%s\n' "$pane_id"
            ;;
        esac
        found="1"
      done
      [ "$found" = "1" ] || true
    else
      cat "$data_dir/list_panes.txt"
    fi
    ;;
  split-window)
    printf 'split-window %s\n' "$*" >> "$data_dir/commands.log"
    current_pane="$(cat "$data_dir/current_pane.txt")"
    meta_file="$data_dir/pane_${current_pane//%/}.meta"
    session_name=""
    window_id="@unknown"
    window_name=""
    if [ -f "$meta_file" ]; then
      . "$meta_file"
    fi
    cat > "$data_dir/pane_99.meta" <<METAEOF
session_name=$session_name
window_id=$window_id
window_name=$window_name
pane_title=Sidebar
pane_current_command=python3
METAEOF
    printf '%%99|Sidebar|%s\n' "$window_id" >> "$data_dir/toggle_panes.txt"
    printf '%%99\n'
    ;;
  select-layout)
    printf 'select-layout %s\n' "$*" >> "$data_dir/commands.log"
    target_window=""
    layout=""
    while [ "$#" -gt 0 ]; do
      case "$1" in
        -t)
          target_window="$2"
          shift 2
          ;;
        *)
          layout="$1"
          shift
          ;;
      esac
    done
    [ -n "$target_window" ] || exit 1
    printf '%s\n' "$layout" > "$data_dir/window_layout_${target_window//@/_}.txt"
    ;;
  respawn-pane)
    printf 'respawn-pane %s\n' "$*" >> "$data_dir/commands.log"
    ;;
  command-prompt)
    printf 'command-prompt %s\n' "$*" >> "$data_dir/commands.log"
    template=""
    while [ "$#" -gt 0 ]; do
      case "$1" in
        -p|-I|-N|-t|-T)
          shift 2
          ;;
        -1|-b|-F|-i|-k|-l)
          shift
          ;;
        *)
          template="$1"
          shift
          ;;
      esac
    done
    if [ -n "${TEST_TMUX_PROMPT_RESPONSE:-}" ] && [ -n "$template" ]; then
      expanded_template="$(
        python3 - "$template" "$TEST_TMUX_PROMPT_RESPONSE" <<'PY'
import sys

template = sys.argv[1]
response = sys.argv[2]

if "%%%" in template:
    template = template.replace("%%%", response.replace('"', '\\"'), 1)
elif "%%" in template:
    template = template.replace("%%", response, 1)

template = template.replace("%1", response)
print(template)
PY
      )"
      printf 'command-prompt-exec %s\n' "$expanded_template" >> "$data_dir/commands.log"
      eval "set -- $expanded_template"
      "$0" "$@"
    fi
    ;;
  run-shell)
    printf 'run-shell %s\n' "$*" >> "$data_dir/commands.log"
    if [ "${1:-}" = "-b" ]; then
      shift
    fi
    shell_command="${1:-}"
    [ -n "$shell_command" ] || exit 0
    bash -c "$shell_command"
    ;;
  set-option)
    printf 'set-option %s\n' "$*" >> "$data_dir/commands.log"
    scope=""
    unset_flag="0"
    target=""
    value=""
    option_name=""
    while [ "$#" -gt 0 ]; do
      case "$1" in
        -g|-p)
          scope="$1"
          shift
          ;;
        -t)
          target="$2"
          shift 2
          ;;
        -u)
          unset_flag="1"
          shift
          ;;
        *)
          if [ -z "$option_name" ]; then
            option_name="$1"
          elif [ -z "$value" ]; then
            value="$1"
          fi
          shift
          ;;
      esac
    done
    option_file="$data_dir/option_${option_name//@/_}.txt"
    if [ "$unset_flag" = "1" ]; then
      rm -f "$option_file"
    else
      printf '%s\n' "$value" > "$option_file"
    fi
    ;;
  show-options)
    option_name="${*: -1}"
    if [ "$option_name" = "-g" ]; then
      for option_file in "$data_dir"/option_*.txt; do
        [ -e "$option_file" ] || exit 0
        option_name="${option_file##*/option_}"
        option_name="${option_name%.txt}"
        option_name="@${option_name#_}"
        printf '%s "%s"\n' "$option_name" "$(cat "$option_file")"
      done
      exit 0
    fi
    option_file="$data_dir/option_${option_name//@/_}.txt"
    if [ ! -f "$option_file" ]; then
      printf 'invalid option: %s\n' "$option_name" >&2
      exit 1
    fi
    cat "$option_file"
    ;;
  set)
    printf 'set %s\n' "$*" >> "$data_dir/commands.log"
    ;;
  kill-pane)
    target=""
    while [ "$#" -gt 0 ]; do
      case "$1" in
        -t)
          target="$2"
          shift 2
          ;;
        *)
          shift
          ;;
      esac
    done
    if [ -f "$data_dir/toggle_panes.txt" ]; then
      awk -F'|' -v target="$target" '$1 != target' "$data_dir/toggle_panes.txt" > "$data_dir/toggle_panes.txt.next" || true
      mv "$data_dir/toggle_panes.txt.next" "$data_dir/toggle_panes.txt"
    fi
    rm -f "$data_dir/pane_${target//%/}.meta"
    ;;
  select-pane)
    printf 'select-pane %s\n' "$*" >> "$data_dir/commands.log"
    target=""
    title=""
    while [ "$#" -gt 0 ]; do
      case "$1" in
        -t)
          target="$2"
          shift 2
          ;;
        -T)
          title="$2"
          shift 2
          ;;
        *)
          shift
          ;;
      esac
    done
    if [ -n "$target" ] && [ -n "$title" ]; then
      meta_file="$data_dir/pane_${target//%/}.meta"
      if [ -f "$meta_file" ]; then
        python3 - "$meta_file" "$title" <<'PY'
from pathlib import Path
import sys

path = Path(sys.argv[1])
title = sys.argv[2]
updated = []
for line in path.read_text().splitlines():
    if line.startswith("pane_title="):
        updated.append(f"pane_title={title}")
    else:
        updated.append(line)
path.write_text("\n".join(updated) + "\n")
PY
      fi
    fi
    if [ -n "$target" ]; then
      printf '%s\n' "$target" > "$data_dir/current_pane.txt"
    fi
    ;;
  select-window)
    printf 'select-window %s\n' "$*" >> "$data_dir/commands.log"
    ;;
  switch-client)
    printf 'switch-client %s\n' "$*" >> "$data_dir/commands.log"
    ;;
  new-window)
    printf 'new-window %s\n' "$*" >> "$data_dir/commands.log"
    ;;
  new-session)
    printf 'new-session %s\n' "$*" >> "$data_dir/commands.log"
    ;;
  *)
    echo "unsupported fake tmux command: $command_name" >&2
    exit 1
    ;;
esac
EOF

chmod +x "$TEST_BIN/tmux"
