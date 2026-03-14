# Sidebar Close Shortcut Design

**Date:** 2026-03-14

## Goal

Add a configurable sidebar action that closes the currently selected pane, while generalizing the shortcut system so each sidebar action can use any non-empty key sequence length.

## User-Facing Behavior

- The sidebar gains a new `close_pane` action.
- The default shortcut for `close_pane` is `x`.
- Users can configure the action with a tmux option:

```tmux
set -g @tmux_sidebar_close_pane_shortcut x
```

- Existing options remain supported:

```tmux
set -g @tmux_sidebar_add_window_shortcut aw
set -g @tmux_sidebar_add_session_shortcut as
```

- Shortcut values are no longer restricted to exactly two characters. Any non-empty printable sequence is valid.
- If configured shortcuts are invalid or duplicated, the sidebar falls back to the default shortcut map.

## Configuration Approach

Keep the current per-action tmux option model and extend it:

- `@tmux_sidebar_add_window_shortcut`
- `@tmux_sidebar_add_session_shortcut`
- `@tmux_sidebar_close_pane_shortcut`

This preserves backward compatibility, avoids a config migration, and keeps the UI code simple because each action still resolves from one tmux option.

## Interaction Model

`scripts/sidebar-ui.py` currently treats shortcuts as a special two-key state machine. That logic will be replaced with generic prefix matching:

- Read all configured shortcuts into one action map.
- Reject empty values and duplicates.
- Track the current typed prefix.
- If the typed prefix exactly matches an action, dispatch it.
- If the typed prefix is only a prefix of one or more actions, keep waiting.
- If the typed prefix cannot match any action, clear pending state.

This lets `x`, `aw`, `as`, or longer sequences all work through the same path.

## Close Behavior

The sidebar should not implement custom pane, window, or session deletion rules. Instead it should call:

```bash
tmux kill-pane -t <selected-pane>
```

tmux already handles the required cascade:

- closing the last pane removes the window
- closing the last window removes the session

Reusing tmux semantics is safer and smaller than reproducing those rules in plugin code.

## Error Handling

- If the selected row no longer points to a live pane, the action becomes a no-op.
- If `tmux kill-pane` fails, the sidebar remains open and continues refreshing.
- After a successful close, the sidebar refresh loop reconciles the selected pane to the next available pane using existing selection recovery behavior.

## Files Expected To Change

- `scripts/sidebar-ui.py`
- `tests/sidebar_ui_shortcuts_test.sh`
- `tests/sidebar_ui_navigation_test.sh` or a new focused interactive test for close behavior
- `tests/testlib.sh`
- `README.md`

## Testing Strategy

Use TDD:

1. Add failing tests for variable-length shortcut parsing and config validation.
2. Add a failing interactive/sidebar action test for the new close shortcut.
3. Implement the minimum UI changes to pass those tests.
4. Update README documentation and rerun the affected shell tests.
