---
name: wow-addon-review
description: Review WoW addon diffs for bugs, regressions, combat-safety issues, and saved-variable mistakes. Use when reviewing BarSmith Lua patches, PRs, or commits that change settings, secure UI, migration logic, or release risk.
---

# WoW Addon Review

Use this skill to review BarSmith changes with a WoW-addon code review mindset.

## Review Order
1. Check the user-facing behavior first.
2. Check combat-locked paths, secure buttons, and deferred updates.
3. Check saved variables, migration, and defaulting.
4. Check settings UI and callbacks for consistency.
5. Check test coverage and manual verification notes.

## BarSmith Checks
- Saved variables: `BarSmithDB`, `BarSmithCharDB`, profile selection, migration, and reset behavior.
- Secure UI: `SetAttribute`, `RegisterStateDriver`, flyouts, layout changes, and combat lockdown.
- Settings UI: Blizzard Settings API proxies, dropdowns, buttons, and refresh callbacks.
- Runtime refresh: QuickBar, BarFrame, and any code that must defer until out of combat.
- Commit quality: if commit messages are part of the review, verify Conventional Commits format.

## Review Output
- Start with findings ordered by severity.
- Include file references for each finding.
- Keep the summary brief and secondary.
- Call out any missing verification steps or risky assumptions.
