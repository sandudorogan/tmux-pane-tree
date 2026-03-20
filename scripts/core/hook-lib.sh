#!/usr/bin/env bash
set -euo pipefail

HOOK_LIB_DIR="$(CDPATH= cd -- "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
hook_event=""
hook_payload=""
hook_status=""
hook_message=""

looks_like_json() {
  case "${1:-}" in
    \{*|\[*)
      return 0
      ;;
    *)
      return 1
      ;;
  esac
}

read_ready_stdin() {
  python3 -c 'from __future__ import annotations
import select
import sys

ready, _, _ = select.select([sys.stdin], [], [], 0.05)
if ready:
    sys.stdout.write(sys.stdin.read())'
}

resolve_hook_input() {
  local arg1="${1:-}"
  local arg2="${2:-}"

  hook_event=""
  hook_payload=""

  if looks_like_json "$arg1"; then
    hook_payload="$arg1"
    hook_event="$arg2"
    return
  fi

  if looks_like_json "$arg2"; then
    hook_payload="$arg2"
    hook_event="$arg1"
    return
  fi

  hook_event="$arg1"
  if [ ! -t 0 ]; then
    hook_payload="$(read_ready_stdin)"
  fi
}

parse_hook_result() {
  local app="$1"
  local event="${2:-}"
  local parsed

  parsed="$(
    HOOK_PAYLOAD="$hook_payload" python3 "$HOOK_LIB_DIR/hook-parser.py" "$app" "$event"
  )"
  hook_status="$(printf '%s\n' "$parsed" | sed -n '1p')"
  hook_message="$(printf '%s\n' "$parsed" | sed '1d')"
}
