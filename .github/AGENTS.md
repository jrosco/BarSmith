# AGENTS.md for BarSmith

These instructions apply to all Codex sessions in this repo.

## Repo Context
- Addon name: BarSmith
- Target client: World of Warcraft Retail
- API version: 12 (Midnight expansion)
- Lua version: WoW Lua (no external libs unless explicitly added)
- Primary entry points: `Init.lua`, `Core.lua`, `Config/Settings.lua`

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

## Workflow
- Prefer `rg` for searching.
- Avoid touching unrelated files or formatting.
- Keep changes minimal and focused on the requested behavior.
- Do not add dependencies unless explicitly requested.

## Code Style
- Use existing formatting and naming conventions.
- Prefer small helper functions over large inlined blocks.
- Avoid non-ASCII characters unless the file already uses them.
- Keep functionality simple and interactions easy for users.
- Use the minimal required settings for use.
- Keep the code modular and avoid files growing beyond ~1000 lines.

## Testing
- No automated tests available.
- If a change is behavior-impacting, describe how to verify in-game.

## Safety
- Never modify saved variables schema unless asked.
- Avoid combat-locked UI changes unless required.
