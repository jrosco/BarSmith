---
name: wow-settings-ui
description: Build Blizzard Settings API UI for WoW addons. Use when adding or changing settings panels, dropdowns, buttons, subcategories, proxy settings, or refresh callbacks in BarSmith.
---

# WoW Settings UI

Use this skill when editing BarSmith's Blizzard Settings panel.

## Core Rules
- Prefer proxy settings when the UI must reflect live addon state.
- Use settings callbacks to write back into the real addon tables.
- Keep controls grouped by task so the panel stays easy to scan.
- Refresh dependent UI after changes that affect layout or visibility.
- Keep secure-frame updates out of the settings callback when combat safety matters.

## BarSmith Patterns
- Add new controls in `Config/Settings.lua`.
- Keep account-wide state in `BarSmith.db`.
- Keep profile state in the active `BarSmith.chardb`.
- Use subcategories for areas like Profiles, QuickBar, Modules, Filters, Mounts, and Advanced.
- Update `settingsProxy` when the visible control needs to follow runtime state.

## Workflow
1. Decide whether the value is account-wide or profile-specific.
2. Choose proxy or direct setting registration based on how live the value must be.
3. Add the control, tooltip, and callback.
4. Refresh dependent modules after the callback runs.
5. Verify the UI still opens cleanly and the setting persists after reload.

