#!/usr/bin/env bash
set -euo pipefail

TESTS_DIR="${TMUX_SIDEBAR_TESTS_DIR:-$(CDPATH= cd -- "$(dirname "${BASH_SOURCE[0]}")" && pwd)}"

if [ "$#" -eq 0 ]; then
  test_files=()
  while IFS= read -r test_file; do
    test_files+=("$test_file")
  done < <(
    python3 - "$TESTS_DIR" <<'PY'
from pathlib import Path
import sys

tests_dir = Path(sys.argv[1])
for path in sorted(tests_dir.rglob("*_test.sh")):
    print(path)
PY
  )
  set -- "${test_files[@]}"
fi

for test_file in "$@"; do
  printf 'RUN %s\n' "$test_file"
  bash "$test_file"
done
