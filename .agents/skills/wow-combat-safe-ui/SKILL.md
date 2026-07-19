---
name: wow-combat-safe-ui
description: Defer secure WoW UI changes out of combat and keep frame updates taint-safe. Use when changing BarSmith layout, secure buttons, attributes, visibility, or any behavior that must avoid combat lockdown.
---

# WoW Combat Safe UI

Use this skill when a change touches secure or combat-locked UI behavior.

## Core Rules
- Do not call protected frame methods in combat unless the API allows it.
- Defer secure updates until `PLAYER_REGEN_ENABLED` or another safe callback.
- Keep runtime-only state off saved variables unless it truly belongs there.
- Separate layout rebuilds from data refreshes when that reduces combat risk.
- Prefer clear queues or pending flags over ad-hoc retries.

## BarSmith Hotspots
- `BarFrame` layout, visibility, and secure button attributes.
- `QuickBar` secure toggle and button refresh paths.
- `SetAttribute`, `Show`, `Hide`, and `RegisterStateDriver` style behavior.
- Anything that changes button size, layout, or bindings while combat may be active.

## Workflow
1. Identify whether the change is protected or can be done immediately.
2. If protected, queue the update for out of combat.
3. Re-run refreshes after the safe callback fires.
4. Keep transient state on runtime objects, not in persistent profile data.
