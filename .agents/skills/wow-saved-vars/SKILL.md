---
name: wow-saved-vars
description: Handle WoW saved-variable migrations, defaults, resets, and compatibility safely. Use when changing BarSmithDB, BarSmithCharDB, profile storage, default values, or any migration path that must preserve player data.
---

# WoW Saved Vars

Use this skill when changing saved variables or migrating old data forward.

## Core Rules
- Preserve existing player data unless the task explicitly says otherwise.
- Keep true account-wide values separate from profile data.
- Migrate old shapes into the new shape before reading them.
- Default missing fields from `BarSmith.DEFAULTS`.
- Never silently discard unknown legacy data unless the migration is intentional.

## BarSmith Targets
- Account-wide: `BarSmithDB` values such as debug and minimap state.
- Profile store: named profiles under `BarSmithDB.profiles`.
- Character selection: `BarSmithCharDB.profile`.
- Legacy compatibility: old per-character fields and older profile keys.

## Workflow
1. Identify the data that must survive.
2. Split account-wide state from per-profile state.
3. Write a migration that normalizes legacy tables.
4. Keep defaults idempotent so repeated loads do not change state.
5. Update any reset paths to preserve the intended data only.
