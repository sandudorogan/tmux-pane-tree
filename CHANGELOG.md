# Changelog

All notable project versions are documented here.

## Unreleased

- Claude SubagentStart/Stop hooks now maintain a per-pane subagent count and show a dedicated `↳`-prefixed badge while subagents run, instead of being suppressed. The count resets at turn and session boundaries so a lost stop event can't pin the badge.
- Hook wrappers opt into subagent lifecycle events via `HOOK_SUBAGENT_TRACKING`; other agents keep the previous suppression behavior.
- The built-in hook installer now keeps only the three most recent backups per config file.
- Recognize Claude Code builds that report their version with underscores (`2_1_201`) as `pane_current_command`, restoring claude detection for panes without hook state.
- A `✳`-prefixed pane title now marks claude as idle, clearing stale running badges left behind by `/compact`, aborted turns, or lost Stop events.
- Stopped treating a `delegate` permission mode as a subagent marker for non-codex apps; claude sessions in delegate mode no longer have their completion events suppressed.
- Keep the cursor label on idle cursor-agent panes while the pane still runs the command captured in hook state, instead of falling back to `node`.
- `hook-cursor.sh` no longer uses `mapfile`, so it survives being run by the system bash 3.2.

## 0.3.3

- Fixed macOS+fish bug where Ctrl-b t stacked new sidebars because detection only matched `python` as `pane_current_command`; allowlist now covers common shells while still excluding agent CLIs like codex/cursor.
- Hardened the live-tmux integration test helper against CI flakes by widening the run-shell poll budget and dropping login-shell profile loading.
- Release commit `c4ab2b4`.

## 0.3.2

- Added built-in Pi and Kiro hook installers, example hook scripts, parser support, and sidebar icons/status badges.
- Documented the Pi and Kiro hook setup and expanded runtime coverage for the new examples and installers.
- Persisted sidebar width across sessions so reopened sidebars keep the user-selected width.
- Fixed a recursive sidebar spawning race when pane selection re-entered sidebar creation.
- Release commit `fa24093`.

## 0.3.1

- Follow-up fixes for the subagent detection and suppression work.
- Tagged on commit `aa1e7f3`.

## 0.3.0

- Added the initial subagent detection and shared suppression state.
- Tagged on commit `199de73`.

## 0.2.0

- Landed Nerd Font icon and badge support for the sidebar UI.
- Tagged on commit `3631ceb`.

## 0.1.0

- Initial project release.
- Tagged on commit `73714a4`.
