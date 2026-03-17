# Context Menu Feature for tmux-sidebar

## Idea

Add right-click context menus to the tmux-sidebar, similar to tmux's built-in right-click menus on panes and the status bar. When a user right-clicks on a session, window, or pane in the sidebar tree, a context-sensitive menu appears with relevant actions (rename, kill, split, etc.). An `m` keyboard shortcut provides the same functionality for keyboard-driven workflows.

## Research Phase

A team of four specialized agents conducted parallel research:

### Agent Team

| Agent | Focus Area | Output |
|-------|-----------|--------|
| **Researcher** | tmux display-menu/popup API, mouse events, existing plugins, version compatibility | `docs/Agenten/active/researcher/recherche-ergebnisse.md`, `curses-tmux-interaktion.md` |
| **Reviewer** | Codebase analysis of sidebar-ui.py, integration points, existing actions | `docs/Agenten/active/reviewer/codebase-analyse.md`, `cross-review.md`, `plan-review.md` |
| **Bash Expert** | Shell scripting, tmux command syntax, worktree integration, race conditions | `docs/Agenten/active/bash-expert/shell-integration.md`, `poc-ergebnisse.md` |
| **TUI Expert** | UX design, curses/tmux interaction, positioning, implementation plan | `docs/Agenten/active/tui-expert/ux-konzept.md`, `positionierung-analyse.md`, `implementierungsplan.md` |

### Key Research Findings

1. **`tmux display-menu`** (tmux 3.0+) is the right rendering mechanism — native look, keyboard navigation built-in, renders as overlay over the entire terminal (not limited to the 25-column sidebar width).

2. **`tmux display-popup`** (tmux 3.2+) is better for complex dialogs (e.g., worktree management with fzf pickers). Reserved for Phase 2+.

3. **Mouse event handling**: When curses enables `ALL_MOUSE_EVENTS`, tmux sets `mouse_any_flag=1` on the pane and forwards mouse events to the application instead of processing them for key bindings. This is the core challenge.

4. **Positioning**: Numeric `-x`/`-y` values in `display-menu` are always **absolute terminal coordinates** (confirmed by reading tmux source code `cmd-display-menu.c`). `-x M`/`-y M` only works within tmux mouse binding context.

5. **Existing plugins analyzed**: tmux-menus (hierarchical shell scripts), tmux-which-key (YAML config), tmux-easy-menu (Rust tool), tmux-fzf (popup-based).

## Technical Decisions

The team discussed and resolved several critical questions through cross-review and debate:

| Question | Decision | Reasoning |
|----------|----------|-----------|
| Menu rendering | `tmux display-menu` | Native tmux look, sidebar too narrow for curses menu |
| Menu trigger | tmux `MouseDown3Pane` binding + `m` key | Only tmux mouse bindings support hold-release selection |
| Positioning (mouse) | `-xM -yM` in binding context | Works because display-menu runs directly from the mouse event handler |
| Positioning (keyboard) | Screen row from selected item | Calculated from selection index minus scroll offset |
| `subprocess.run` vs `Popen` | N/A (resolved differently) | Initial approach of calling display-menu from Python was abandoned |
| `endwin()` needed? | No | tmux commands use Unix socket, not PTY — no conflict with curses |
| Destructive actions | `confirm-before` | Prevents accidental kills |

### The Mouse Click Problem

The most significant technical challenge was making mouse clicks work on menu items. The development went through several iterations:

**Attempt 1: `subprocess.run` from Python**
Called `tmux display-menu` via `subprocess.run` from the curses event loop. Menu appeared but mouse clicks on items did nothing — only keyboard worked. Root cause: `display-menu` opened from CLI subprocess doesn't receive mouse events from the tmux overlay system.

**Attempt 2: `subprocess.Popen` (non-blocking)**
Same approach but non-blocking. Same mouse click issue.

**Attempt 3: `curses.mousemask(0)` before menu**
Disabled curses mouse tracking to clear `mouse_any_flag`. Menu still didn't respond to mouse clicks.

**Attempt 4: `curses.endwin()` (full terminal restore)**
Restored terminal to normal mode before opening menu. Sidebar went black, mouse clicks still didn't work.

**Attempt 5: `-M` flag (force mouse tracking)**
Added `-M` flag to `display-menu`. Menu opened and immediately closed.

**Attempt 6: Temporary key binding via `send-keys`**
Bound menu to F63, sent key to sidebar. Curses consumed the key event.

**Attempt 7 (final): tmux `MouseDown3Pane` native binding**
Registered a tmux mouse binding that intercepts right-clicks on the sidebar pane. The binding runs a shell script synchronously (via `if-shell`) that determines what was clicked, writes a `display-menu` command to a temp file, and then `source-file` executes it — all within the same mouse event context. This enables `-xM -yM` positioning and native hold-release item selection.

The key insight: `display-menu` **must** be executed directly from a tmux key/mouse binding to receive mouse events. Any indirection through subprocess, `run-shell -b`, or CLI calls loses the mouse event context.

## Architecture

```
User right-clicks on sidebar
         │
         ▼
tmux MouseDown3Pane binding (registered by bind-context-menu.sh)
         │
         ├── Pane title matches "Sidebar"?
         │   │
         │   ▼ YES
         │   if-shell runs show-context-menu.sh (synchronous)
         │   │
         │   ├── Reads rowmap-{pane}.json (written by sidebar-ui.py)
         │   ├── Looks up row at mouse_y + scroll_offset
         │   ├── Determines kind (session/window/pane/empty)
         │   └── Writes display-menu command to menu-cmd.tmux
         │   │
         │   ▼
         │   source-file menu-cmd.tmux
         │   │
         │   ▼
         │   display-menu -xM -yM (in mouse event context)
         │   → Hold-release selection works
         │   → Keyboard shortcuts work
         │
         └── NO → default tmux right-click behavior
```

### IPC: Row Map File

`sidebar-ui.py` writes a JSON file after every render (with change detection to skip unchanged writes):

```json
{
  "scroll_offset": 3,
  "rows": [
    {"kind": "session", "session": "main"},
    {"kind": "window", "session": "main", "window": "@1"},
    {"kind": "pane", "session": "main", "window": "@1", "pane_id": "%0"},
    ...
  ]
}
```

The shell script uses `mouse_y + scroll_offset` to index into the rows array and determine what was clicked.

### Files

| File | Role |
|------|------|
| `sidebar.tmux` | Registers `bind-context-menu.sh` via `run-shell -b` |
| `scripts/features/context-menu/bind-context-menu.sh` | Writes and source-files the `MouseDown3Pane` tmux binding |
| `scripts/features/context-menu/show-context-menu.sh` | Reads rowmap, writes context-sensitive `display-menu` command |
| `scripts/ui/sidebar-ui.py` | Writes rowmap JSON on render; `m` key triggers fallback menu |

## Menu Items

### Session Menu
- Switch to — `switch-client -t <session>`
- Rename — interactive `command-prompt` + `rename-session`
- New Window — `new-window -t <session>`
- Detach — `detach-client -s <session>`
- Kill Session — `confirm-before` + `kill-session`

### Window Menu
- Select — `switch-client` + `select-window`
- Rename — interactive `command-prompt` + `rename-window`
- New Window After — `new-window -a -t <window>`
- Split Horizontal/Vertical — `split-window -h/-v`
- Kill Window — `confirm-before` + `kill-window`

### Pane Menu
- Select — `switch-client` + `select-window` + `select-pane`
- Zoom — `resize-pane -Z`
- Split Horizontal/Vertical — `split-window -h/-v`
- Break to Window — `break-pane -d`
- Mark — `select-pane -m`
- Kill Pane — `confirm-before` + `kill-pane`

### Empty Area Menu
- New Session — interactive `command-prompt` + `new-session`
- New Window — `new-window`
- Refresh — sends SIGUSR1 to sidebar
- Close Sidebar — runs `close-sidebar.sh`

## Code Review Findings

Three review agents analyzed the implementation:

| Finding | Severity | Fix Applied |
|---------|----------|-------------|
| 5 separate python3 process spawns per right-click (~250ms) | HIGH | Consolidated to single call (~50ms) |
| Dead `rows`/`scroll_offset` parameters on `_run_context_menu` | MEDIUM | Removed |
| Rowmap written to disk every 2s even when unchanged | MEDIUM | Added change-detection cache |
| `print_state_dir()` reimplemented instead of sourcing `lib.sh` | LOW | Now sources `lib.sh` |
| Duplicate `qs` escaping in each case branch | LOW | Hoisted above case statement |
| Unescaped session names in menu titles | LOW | Applied `escape_tmux` to title strings |

## Development Timeline

1. **Research phase**: 4 agents conducted parallel research on tmux APIs, codebase analysis, shell scripting, and UX design
2. **Cross-review**: Agents reviewed each other's findings, identified the `-x M -y M` positioning issue and `subprocess.run` blocking issue
3. **Implementation plan**: TUI expert created detailed plan with exact line numbers and code snippets
4. **Plan review**: Reviewer validated all technical decisions and line numbers
5. **Implementation v1**: Python-based `display-menu` via `subprocess` — menu appeared but mouse clicks failed
6. **7 iterations** on mouse click problem: subprocess.run → Popen → mousemask(0) → endwin() → -M flag → F63 keybinding → native MouseDown3Pane binding
7. **Architecture pivot**: Moved menu logic from Python to a tmux mouse binding + shell script + source-file pattern
8. **Code review**: 3 review agents identified 6 issues; all fixed
9. **Comments**: Added English documentation to all new code

## Future Work (Phase 2+)

- **Dynamic menu items**: Zoom/Unzoom based on current state, Mark/Unmark toggle
- **Agent-specific entries**: Send Ctrl-C, Send Enter for detected AI agents
- **Worktree integration**: fzf-based worktree picker via `display-popup`, branch info in tree view
- **Configurable shortcuts**: `@tmux_sidebar_menu_shortcut` option
