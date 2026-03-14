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
- `aw` prompts for a name and adds a window after the selected pane's window
- `as` prompts for a name and adds a session after the selected pane's session
- `Ctrl+l` leaves the sidebar and returns focus to the main pane

## Configuration

The sidebar width defaults to `25` columns.

Set a custom width in your tmux config:

```tmux
set -g @tmux_sidebar_width 28
```

If you need a process-level override, `TMUX_SIDEBAR_WIDTH` takes precedence over
the tmux option.

By default, the sidebar takes focus when you open it manually with `<prefix>t`.
Disable that behavior in your tmux config if you want focus to stay in the main
pane:

```tmux
set -g @tmux_sidebar_focus_on_open 0
```

The add shortcuts default to `aw` for windows and `as` for sessions.

Set custom shortcuts in your tmux config:

```tmux
set -g @tmux_sidebar_add_window_shortcut zw
set -g @tmux_sidebar_add_session_shortcut zs
```

Each shortcut must be exactly two characters. If a configured value is invalid
or duplicates the other shortcut, the sidebar falls back to the defaults.

Both actions use tmux's built-in prompt for naming and create the new object
relative to the pane row currently selected in the sidebar.

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
  tests/sidebar_ui_shortcuts_test.sh \
  tests/sidebar_ui_prompt_test.sh \
  tests/sidebar_ui_focus_test.sh \
  tests/add_window_test.sh \
  tests/add_session_test.sh \
  tests/focus_main_pane_test.sh
```

## License

MIT
