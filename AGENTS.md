# BarSmith Agent Guide

This is the canonical agent guide for the repo.

## Repo Context
- Addon name: BarSmith
- Target client: World of Warcraft Retail
- API version: 12 (Midnight expansion)
- Lua version: WoW Lua only, no external libs unless explicitly added
- Lua flavor: WoW Lua only, no new external dependencies unless explicitly requested
- Main entry points: `Init.lua`, `Core.lua`, `Config/Settings.lua`

## Terminology
- Bar frame: The main container frame for BarSmith (`BarSmithBarFrame`).
- Button: A secure action button on the bar (`BarSmithButtonN`).
- Parent button: The main button that represents a group/flyout.
- Child button: A flyout button spawned from a parent.
- Flyout: The set of child buttons shown around a parent.
- Flyout group: A data group that supplies children and a primary item.
- Primary item: The item/spell/toy currently assigned to the parent button.
- Flyout open: State where child buttons are shown (visible).
- Module button: Hidden secure buttons used for keybinds (`BarSmithModule_*`).

## Working Rules
- Prefer `rg` for searching and keep changes focused.
- Avoid unrelated formatting churn.
- Use `apply_patch` for edits.
- Do not change saved variable schema unless the task explicitly asks for it.
- Avoid combat-locked UI changes unless they are required.

## Code Style
- Match the existing naming and formatting conventions.
- Prefer small helpers over large inline blocks.
- Keep behavior simple and predictable.
- Use ASCII unless the file already uses non-ASCII characters.

## Verification
- No automated test suite is available.
- For behavior changes, describe how to verify in-game.

## Git Workflow Notes
- Use `.codex\skills\git-commit` for Conventional Commits messages.
- Use `.codex\skills\git-pr-review` for PR and diff reviews.
- Use `.codex\skills\git-release` for release notes and version guidance.
- The matching human-readable references live in `git-skills/commit.md`, `git-skills/pr-review.md`, and `git-skills/release.md`.
