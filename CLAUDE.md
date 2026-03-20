# tmux-sidebar

A tmux plugin that adds an interactive sidebar showing sessions, windows, and panes with agent status badges. Written in bash and python3 (curses UI).

## Architecture

```
sidebar.tmux          <- TPM entry point, registers hooks and keybindings
scripts/
  core/
    lib.sh            <- shared bash utilities (state, tmux helpers, json)
    hook-lib.sh       <- shared shell hook input handling
    hook-parser.py    <- shared Claude/Codex event parsing
  ui/
    sidebar-ui.py     <- interactive curses loop entrypoint
    sidebar_ui_lib/
      core.py         <- tmux/config helpers, prompts, pane actions
      status.py       <- live agent detection and badge selection
      tree.py         <- tree loading, selection, search helpers
      render.py       <- curses colors, drawing, row-map/context-menu IPC
  features/
    sidebar/          <- toggle/ensure/focus/close/render lifecycle helpers
    hooks/            <- thin Claude/Codex hook wrappers
    state/            <- pane-state writers and cleanup helpers
    context-menu/     <- right-click menu integration
    sessions/         <- prompted creation of windows/sessions
  install-live.sh     <- dev installer (copies to plugin dir, patches paths, reloads)
tests/
  testlib.sh          <- fake tmux test framework
  real_tmux_testlib.sh <- live tmux test helpers
  run.sh              <- test runner
  core/ sidebar/ ui/ hooks/ state/ sessions/ context-menu/ integration/ examples/
                      <- grouped test suites
examples/
  claude-hook.sh / codex-hook.sh / opencode-hook.sh  <- agent integration hooks
```

State files live in `$XDG_STATE_HOME/tmux-sidebar/pane-{PANE_ID}.json` (defaults to `~/.local/state/tmux-sidebar/`).

## Testing

### Unit tests (fake tmux, no live session needed)

```bash
bash tests/run.sh
```

Run a single test file:
```bash
bash tests/run.sh tests/core/lib_test.sh
```

The test framework (`tests/testlib.sh`) creates a fake `tmux` binary that simulates core commands using temp files. Tests source `testlib.sh`, set up state with helpers like `fake_tmux_register_pane` and `fake_tmux_set_tree`, then call scripts and assert results.

### Live testing in a separate tmux session

For integration testing against a real tmux server, use a dedicated session so you don't disrupt your work:

```bash
# 1. Install the working copy into the plugin directory
bash scripts/install-live.sh

# 2. Open a separate tmux session for testing
tmux new-session -d -s sidebar-test
tmux send-keys -t sidebar-test 'echo "test pane"' Enter

# 3. Toggle sidebar in the test session
tmux send-keys -t sidebar-test 'prefix' ''   # or trigger via:
tmux run-shell -t sidebar-test "$HOME/.config/tmux/plugins/tmux-sidebar/scripts/features/sidebar/toggle-sidebar.sh"

# 4. Simulate agent state updates
bash scripts/features/state/update-pane-state.sh --pane %0 --app claude --status running
bash scripts/features/state/update-pane-state.sh --pane %0 --app claude --status needs-input
bash scripts/features/state/update-pane-state.sh --pane %0 --app claude --status idle

# 5. Clean up
tmux kill-session -t sidebar-test
```

To manually verify changes without install-live:
```bash
# Source the plugin directly in a test session
tmux new-session -d -s sidebar-test
tmux source-file sidebar.tmux
```

### After any code change

1. Run `bash tests/run.sh` — all tests must pass
2. If changing UI or hooks, also run `bash scripts/install-live.sh` and verify in a live tmux session
3. If adding new functionality, add a corresponding `tests/<name>_test.sh`

## Code style

### Bash

- Always start with `#!/usr/bin/env bash` and `set -euo pipefail`
- Source shared code via `. "$SCRIPTS_DIR/core/lib.sh"` where `SCRIPTS_DIR` resolves to the repo `scripts/` directory
- Use `printf` over `echo` for output
- Quote all variable expansions: `"$var"`, `"${var:-default}"`
- Prefer `[ condition ]` for simple tests, `[[ ]]` for pattern matching
- Use `local` for all function variables
- Suppress expected errors with `2>/dev/null || true`, not by removing `set -e`
- Argument parsing uses `while [ "$#" -gt 0 ]; do case "$1" in ...` pattern
- No unnecessary comments — code should be self-documenting
- Functions go in `scripts/core/lib.sh` if reused across scripts
- Use `awk` for structured text processing, not complex bash string manipulation
- Temp files via `mktemp` with cleanup traps
- Atomic file writes: write to tmp, then `mv`

### Python

- Target python3, use `from __future__ import annotations`
- Type hints on function signatures
- Use `pathlib.Path` over `os.path`
- `subprocess.check_output` / `subprocess.run` for external commands
- Constants at module top as ALL_CAPS
- No classes unless genuinely needed — functions and module-level state
- `shlex.quote` for shell escaping
- Keep curses code isolated in dedicated functions

### tmux plugin conventions

- `sidebar.tmux` has no shebang — tmux sources it directly
- Use `#{d:current_file}` for relative paths in hook registrations
- Hook indices (e.g. `[198]`) are namespaced to avoid collisions with other plugins
- State stored in tmux global options prefixed `@tmux_sidebar_`
- Per-window state keyed by window ID: `@tmux_sidebar_{suffix}_w{ID}`
- Background execution via `run-shell -b` to avoid blocking tmux

### Testing conventions

- One test file per script/feature, named `<script>_test.sh`
- Group tests under `tests/<area>/` to match the feature or subsystem they cover
- Test files source `testlib.sh` which provides the fake tmux and assertions
- Use `fake_tmux_register_pane`, `fake_tmux_set_tree`, `fake_tmux_no_sidebar` to set up state
- Use `run_script` to execute a script and capture output into `$output`
- Assertions: `assert_eq`, `assert_contains`, `assert_not_contains`, `assert_file_contains`, `assert_file_not_contains`
- Each test is a function called directly — no test framework dependencies
- Reset state between tests with `fake_tmux_no_sidebar`

### General

- No fallback logic unless explicitly requested
- Fail fast — `set -euo pipefail` in bash, no silent error swallowing
- Separation of concerns: `scripts/core/lib.sh` for shared bash logic, `scripts/core/hook-lib.sh` and `scripts/core/hook-parser.py` for shared hook parsing, `scripts/ui/sidebar-ui.py` as the UI entrypoint, and `scripts/ui/sidebar_ui_lib/` for focused Python UI modules
- Atomic state mutations — write to temp file then `mv` to avoid partial reads
- Mutex via `tmux wait-for` for operations that race (e.g. ensure-sidebar-pane)
