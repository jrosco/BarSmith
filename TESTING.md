# BarSmith In-Game Verification Checklist

Use this checklist after changes to `BarFrame` or related modules.

1. Reload UI and confirm addon loads without errors (`/reload`).
2. Run `/bs` and confirm the help text prints.
3. Run `/bs status` and confirm the active profile name is shown.
4. Verify the bar appears and auto-fills on login (wait a few seconds after reload).
5. Create a new profile from the settings panel, then switch to it and confirm it becomes active.
6. Clone the active profile, rename it, and confirm the new name persists after `/reload`.
7. Switch between two profiles and confirm the bar, QuickBar, and module toggles update correctly.
8. Toggle lock state with `/bs lock` and confirm the drag anchor shows only when unlocked.
9. Drag the bar and `/reload`, then confirm the position persists.
10. If auto-hide on mouseover is enabled, confirm the bar fades and restores on hover.
11. Hover buttons and confirm tooltips show correctly with the configured tooltip modifier.
12. Click a parent button with a flyout and confirm children show and auto-close.
13. Click a flyout child and confirm it promotes to primary.
14. Open keybinds and confirm module bindings trigger the correct buttons.
15. Drag a consumable, toy, mount, or spell to the bar and confirm it is included.
16. Shift + Right Click on a button opens the settings menu.
17. Ctrl + Shift + Right Click removes or excludes as before.
18. Alt + Left Click on a flyout child adds it to QuickBar.
19. Confirm profile delete/reset actions behave correctly and the Default profile cannot be removed.
20. Cooldowns animate and range coloring updates in combat and out of combat.
