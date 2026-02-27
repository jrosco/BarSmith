# BarSmith In-Game Verification Checklist

Use this checklist after changes to `BarFrame` or related modules.

1. Reload UI and confirm addon loads without errors (`/reload`).
2. Run `/bs` and confirm the help text prints.
3. Verify the bar appears and auto-fills on login (wait a few seconds after reload).
4. Toggle lock state with `/bs lock` and confirm the drag anchor shows only when unlocked.
5. Drag the bar and `/reload`, then confirm the position persists.
6. If auto-hide on mouseover is enabled, confirm the bar fades and restores on hover.
7. Hover buttons and confirm tooltips show correctly with the configured tooltip modifier.
8. Click a parent button with a flyout and confirm children show and auto-close.
9. Click a flyout child and confirm it promotes to primary.
10. Open keybinds and confirm module bindings trigger the correct buttons.
11. Drag a consumable, toy, mount, or spell to the bar and confirm it is included.
12. Shift + Right Click on a button opens the settings menu.
13. Ctrl + Shift + Right Click removes or excludes as before.
14. Alt + Left Click on a flyout child adds it to QuickBar.
15. Cooldowns animate and range coloring updates in combat and out of combat.
