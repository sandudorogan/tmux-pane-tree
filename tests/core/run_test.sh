#!/usr/bin/env bash
set -euo pipefail

. "$(dirname "$0")/testlib.sh"

if [ "${TMUX_SIDEBAR_RUNNER_FIXTURE_MODE:-0}" = "1" ]; then
  exit 0
fi

write_fixture_test() {
  local path="$1"
  local name="$2"
  cat > "$path" <<EOF
#!/usr/bin/env bash
set -euo pipefail
printf '%s\n' '$name' >> "\${RUNNER_LOG:?}"
EOF
  chmod +x "$path"
}

test_runner_discovers_nested_test_files_recursively() {
  local fixture_dir="$TEST_TMP/run-fixtures"
  local normalized_fixture_dir=""
  local output_path="$TEST_TMP/runner-output.txt"
  local log_path="$TEST_TMP/runner-log.txt"

  mkdir -p "$fixture_dir/nested/deeper"
  write_fixture_test "$fixture_dir/root_test.sh" "root"
  write_fixture_test "$fixture_dir/nested/one_test.sh" "nested"
  write_fixture_test "$fixture_dir/nested/deeper/two_test.sh" "deeper"

  RUNNER_LOG="$log_path" \
    TMUX_SIDEBAR_RUNNER_FIXTURE_MODE=1 \
    TMUX_SIDEBAR_TESTS_DIR="$fixture_dir" \
    bash tests/run.sh > "$output_path"

  normalized_fixture_dir="$(python3 -c 'from pathlib import Path; import sys; print(Path(sys.argv[1]))' "$fixture_dir")"
  assert_eq "$(wc -l < "$log_path" | tr -d ' ')" "3"
  assert_file_contains "$log_path" 'root'
  assert_file_contains "$log_path" 'nested'
  assert_file_contains "$log_path" 'deeper'
  assert_file_contains "$output_path" "$normalized_fixture_dir/root_test.sh"
  assert_file_contains "$output_path" "$normalized_fixture_dir/nested/one_test.sh"
  assert_file_contains "$output_path" "$normalized_fixture_dir/nested/deeper/two_test.sh"
  assert_file_not_contains "$output_path" 'tests/core/lib_test.sh'
}

test_runner_discovers_nested_test_files_recursively
