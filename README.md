# tmux-sidebar

`tmux-sidebar` is a tmux plugin that adds a mirrored left sidebar showing your
tmux session tree:

- sessions
- windows
- panes
- per-pane agent status badges

It is designed for agent-heavy tmux workflows, with hook-driven badges for
`claude`, `codex`, and `opencode`.

## Features

- Toggle the sidebar with `<prefix>t`
- Render a Unicode tree of `session -> window -> pane`
- Mirror the sidebar into visited windows while enabled
- Keep the sidebar full-height on the left side of the window
- Navigate inside the sidebar and jump to a selected pane
- Show per-pane agent badges for `running`, `needs-input`, `done`, and `error`
- Clear transient notifications when you focus the pane

## Install

### TPM

Add the plugin to your tmux config:

```tmux
set -g @plugin 'tmux-plugins/tpm'
set -g @plugin 'sandudorogan/tmux-sidebar'

run '~/.tmux/plugins/tpm/tpm'
```

Reload tmux, then install plugins with `prefix + I`.

TPM will automatically source `sidebar.tmux`.

### Manual

Clone the repo:

```bash
git clone https://github.com/sandudorogan/tmux-sidebar ~/.tmux/plugins/tmux-sidebar
```

Source the plugin from your tmux config:

```tmux
if-shell "test -f ~/.tmux/plugins/tmux-sidebar/sidebar.tmux" \
  "source-file ~/.tmux/plugins/tmux-sidebar/sidebar.tmux"
```

Reload tmux:

```bash
tmux source-file ~/.tmux.conf
```

## Usage

- `<prefix>t` toggles the sidebar
- `j` / `k` or arrow keys move inside the sidebar
- `Enter` jumps to the selected pane
- `Ctrl+l` leaves the sidebar and returns focus to the main pane

## Hook Integration

Each agent should report pane-local status through
`scripts/update-pane-state.sh`.

Example:

```bash
~/.tmux/plugins/tmux-sidebar/scripts/update-pane-state.sh \
  --pane "$TMUX_PANE" \
  --app claude \
  --status needs-input \
  --message "Permission request"
```

If you install the plugin somewhere else, adjust the path accordingly.

Example hook wrappers:

- `examples/claude-hook.sh`
- `examples/codex-hook.sh`
- `examples/opencode-hook.sh`

State is stored in `~/.tmux-sidebar/state` by default. Override it with
`TMUX_SIDEBAR_STATE_DIR` if needed.

## Development

Run the shell test suite:

```bash
bash tests/run.sh \
  tests/hook_scripts_test.sh \
  tests/lib_test.sh \
  tests/update_pane_state_test.sh \
  tests/clear_pane_state_test.sh \
  tests/update_pane_state_timestamp_test.sh \
  tests/render_sidebar_test.sh \
  tests/toggle_sidebar_test.sh \
  tests/refresh_sidebar_test.sh \
  tests/hook_examples_test.sh \
  tests/ensure_sidebar_pane_test.sh \
  tests/sidebar_hooks_test.sh \
  tests/sidebar_ui_state_test.sh \
  tests/sidebar_ui_focus_test.sh \
  tests/focus_main_pane_test.sh
```

## License

MIT
