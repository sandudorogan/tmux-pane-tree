# tmux-pane-tree

[![Tests](https://github.com/sandudorogan/tmux-pane-tree/actions/workflows/test.yml/badge.svg)](https://github.com/sandudorogan/tmux-pane-tree/actions/workflows/test.yml)

A persistent session tree on the left of every tmux window, with live status
badges for `claude`, `codex`, `cursor`, `opencode`, `pi`, and `kiro`.

```
  ┌─ Sidebar ────────────┬────────────────────────────────┐
  │   ├─ work            │  $ claude                      │
  │   │  └─ zsh          │                                │
  │   │     ├─ claude    │  Working on your request...    │
  │   │     └─ zsh       │                                │
  │   └─ env             │                                │
  │      ├─ claude       │                                │
  │      │  ├─ lazygit   │                                │
  │ ▶    │  ├─ claude ⏳│                                │
  │      │  └─ yazi      │                                │
  │      └─ yazi         │                                │
  └──────────────────────┴────────────────────────────────┘
```

![tmux-pane-tree showcase](images/showcase.gif)

- **Tree view** of sessions, windows, and panes. `Enter` jumps to a pane.
- **Agent badges** update live from agent hooks.
- **Follows you** across windows once opened.
- **Manage sessions** from the sidebar: add, rename, close.

| Badge | Status           | Meaning                          |
| :---: | ---------------- | -------------------------------- |
| `⏳`  | running          | Agent is working                 |
| `↳⏳` | subagent-running | Agent is delegating to subagents |
| `❓`  | needs-input      | Waiting for permission or input  |
| `✅`  | done             | Finished                         |
| `❌`  | error            | Something went wrong             |

`needs-input` clears when you focus the pane. `done` stays until the next run.

## Install

Requires tmux 3.0+, Python 3, bash 4.0+.

**TPM**

```tmux
set -g @plugin 'sandudorogan/tmux-pane-tree'
set -g @tmux_pane_tree_install_agent_hooks 1   # optional: wire agent hooks on load
```

Reload tmux, then `prefix + I`.

**Manual**

```bash
git clone https://github.com/sandudorogan/tmux-pane-tree ~/.config/tmux/plugins/tmux-pane-tree
```

```tmux
source-file ~/.config/tmux/plugins/tmux-pane-tree/tmux-pane-tree.conf
```

To patch Claude Code, Codex, Cursor, OpenCode, Pi, and Kiro hook config after a manual install:

```bash
bash ~/.config/tmux/plugins/tmux-pane-tree/scripts/features/hooks/install-agent-hooks.sh
```

> Migrating from `tmux-sidebar`: the old `@tmux_sidebar_*` options, paths, and
> `tmux-pane-tree.tmux` source line keep working for one release cycle. New
> installs should use the `tmux-pane-tree` names.

## Usage

| Key          | Action                                        |
| ------------ | --------------------------------------------- |
| `prefix t`   | Toggle the sidebar                            |
| `prefix T`   | Focus the sidebar, or return to the main pane |

Inside the sidebar:

| Key                  | Action                            |
| -------------------- | --------------------------------- |
| `j` / `k`, arrows    | Move selection                    |
| `gg` / `G`           | Top / bottom                      |
| `Ctrl+o` / `Ctrl+i`  | Jump list back / forward          |
| `Enter`              | Jump to the selected pane         |
| `aw` / `as`          | Add window / session (prompts)    |
| `rw` / `rs`          | Rename window / session           |
| `x`                  | Close the selected pane           |
| `f`                  | Toggle pane filter                |
| `p`                  | Toggle hide-panes mode            |
| `Ctrl+l`             | Return focus to the main pane     |
| `q`                  | Close the sidebar                 |

New windows and sessions insert next to the selected row. Closing the last
pane removes its window, and the last window removes its session.

The jump list starts from the pane you came from. The final `Ctrl+o` returns
you there. It resets when the sidebar loses focus.

## Configuration

Set options with `set -g` in your tmux config.

| Option                                    | Default | Description                                   |
| ----------------------------------------- | :-----: | --------------------------------------------- |
| `@tmux_pane_tree_width`                   |  `25`   | Sidebar column width                          |
| `@tmux_pane_tree_focus_on_open`           |   `1`   | Focus the sidebar when toggled open           |
| `@tmux_pane_tree_toggle_key`              |   `t`   | Prefix key to toggle                          |
| `@tmux_pane_tree_focus_key`               |   `T`   | Prefix key to focus                           |
| `@tmux_pane_tree_session_order`           |    —    | Comma-separated session order, rest follow    |
| `@tmux_pane_tree_filter`                  |    —    | Comma-separated pane filter (see below)       |
| `@tmux_pane_tree_hide_panes`              |  `off`  | Show only sessions and windows                |
| `@tmux_pane_tree_compact_single_panes`    |  `off`  | Fold single-pane windows into one row         |
| `@tmux_pane_tree_scrolloff`               |   `8`   | Rows kept visible around the cursor, `0` off  |
| `@tmux_pane_tree_icon_theme`              | `auto`  | `auto`, `ascii`, `unicode`, or `nerdfont`     |
| `@tmux_pane_tree_icon_<app>`              |    —    | Override one app icon                         |
| `@tmux_pane_tree_badge_<status>`          |    —    | Override one status badge                     |
| `@tmux_pane_tree_color_session`           |    —    | Session name color, hex                       |
| `@tmux_pane_tree_color_window`            |    —    | Window name color, hex                        |
| `@tmux_pane_tree_color_pane`              |    —    | Pane name color, hex                          |
| `@tmux_pane_tree_install_agent_hooks`     |   `0`   | Install agent hooks when the plugin loads     |
| `@tmux_pane_tree_<action>_shortcut`       |    —    | Override a sidebar shortcut (see below)       |

| Environment variable        | Description                                                  |
| --------------------------- | ------------------------------------------------------------ |
| `TMUX_PANE_TREE_STATE_DIR`  | State directory, default `$XDG_STATE_HOME/tmux-sidebar`      |
| `TMUX_PANE_TREE_PLUGIN_DIR` | Plugin root used by the example hooks                        |
| `TMUX_PANE_TREE_FONT_DIRS`  | Path-separated font directories checked by icon theme `auto` |

**Pane filter.** Case-insensitive match against pane command, title, and agent
metadata. `f` toggles it at runtime.

```tmux
set -g @tmux_pane_tree_filter "claude,codex,cursor,opencode"
```

**Compact single-pane windows.** Set `@tmux_pane_tree_compact_single_panes` to
`on` to show a window with one content pane as one selectable row. The row
retains the pane's agent status badge. The sidebar pane does not count, and
filtering does not turn a multi-pane window into a compact row.

```tmux
set -g @tmux_pane_tree_compact_single_panes on
```

**Shortcuts.** Actions: `add_window` (`aw`), `add_session` (`as`), `go_top`
(`gg`), `go_bottom` (`G`), `jump_back` (`C-o`), `jump_forward` (`C-i`),
`rename_window` (`rw`), `rename_session` (`rs`), `toggle_filter` (`f`),
`close_pane` (`x`). If any shortcut is empty, duplicated, a prefix of another,
or uses the reserved `q`, all ten revert to defaults.

```tmux
set -g @tmux_pane_tree_close_pane_shortcut dd
```

**Icons.** `auto` picks `nerdfont` when a Nerd Font is installed on the tmux
host, else `ascii`. Installed is not the same as in use: if glyphs render
wrong, or the session is remote, set the theme explicitly. Badges follow the
theme. App ids for overrides: `claude`, `codex`, `opencode`, `cursor`, `pi`,
`kiro`, `shell`, `node`, `python`, `git`, `lazygit`, `yazi`, `ranger`, `bb`,
`cat`, `clojure`, `java`, `less`, `vim`, `ssh`, `pager`, `top`, `tmux`,
`unknown`.

```tmux
set -g @tmux_pane_tree_icon_theme ascii
set -g @tmux_pane_tree_icon_claude "A"
set -g @tmux_pane_tree_badge_running "*"
```

**Colors.** Unset colors derive from your tmux theme.

## Agent hooks

```
  agent hook ──▶ scripts/features/hooks/hook-<agent>.sh
                        │
                        ▼
             update-pane-state.sh --pane $TMUX_PANE --app claude --status running
                        │
                        ▼
             $STATE_DIR/pane-%N.json ──▶ sidebar badge
```

`install-agent-hooks.sh` writes the wiring for every agent and keeps three
timestamped backups per file:

| Agent    | File                                          |
| -------- | --------------------------------------------- |
| Claude   | `~/.claude/settings.json`                     |
| Codex    | `~/.codex/config.toml` (`notify` line)        |
| Cursor   | `~/.cursor/hooks.json`                        |
| OpenCode | `~/.config/opencode/plugins/tmux-pane-tree.js`|
| Pi       | `~/.pi/agent/extensions/tmux-pane-tree.ts`    |
| Kiro     | `~/.kiro/agents/tmux-pane-tree.json`, `~/.kiro/settings/cli.json` |

It replaces the single `notify = [...]` line in `~/.codex/config.toml`, and
only rewrites Kiro's `chat.defaultAgent` when it is missing or still `kiro_default`.

**Manual wiring.** Copy from `examples/` and point each tool at its wrapper
under `scripts/features/hooks/`: Claude Code: `hook-claude.sh`, Codex:
`hook-codex.sh`, Cursor: `hook-cursor.sh`, OpenCode: `hook-opencode.sh`,
Pi: `hook-pi.sh`, Kiro: `hook-kiro.sh`.

Subagent completions are suppressed so only the parent session shows `done`.
For that to work:

- Claude Code needs `SessionStart`, `UserPromptSubmit`, `Stop`, `Notification`,
  `PermissionRequest`, `SessionEnd`, `SubagentStart`, `SubagentStop`.
- Cursor needs `sessionStart`, `sessionEnd`, `beforeSubmitPrompt`,
  `preToolUse`, `postToolUse`, `postToolUseFailure`, `subagentStart`,
  `subagentStop`, `afterAgentThought`, `afterAgentResponse`, `stop`.
  Cursor has no permission events, so `needs-input` comes from
  `postToolUseFailure` with `failure_type=permission_denied`.
- Codex suppression is best-effort via `permission_mode` and `session_id`.
  Without those markers the completion badge is kept.

Custom integrations call `update-pane-state.sh` directly with `--pane "$TMUX_PANE"`.

## Development

```
scripts/
  core/        shared bash and hook parsing
  ui/          curses UI: sidebar-ui.py + sidebar_ui_lib/
  features/    sidebar, state, hooks, sessions, context-menu
tests/         fake-tmux test suites, run with bash tests/run.sh
examples/      copy-ready agent hook configs
```

```bash
bash tests/run.sh                 # all tests, no live tmux needed
bash scripts/install-live.sh      # copy into the plugin dir and reload open sidebars
```

## License

MIT
