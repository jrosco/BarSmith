# Changelog

All notable changes to BarSmith are documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [1.2.0] - 2026-11-11

### Added

- World of Warcraft: Forever support (`interface 16001`) alongside retail Midnight, from a single package.
- Vanilla content data for Forever: class utility abilities (all 9 classes), mount spells, and the Hearthstone.
- `Legacy` micro-menu entry on Forever.

### Changed

- Micro menu entries are now version-specific:
  - Retail keeps Character, Spellbook, Talents, Professions, Achievements, Quest Log, Housing, Guild, Group Finder, Collections, Adventure Guide, Shop, and Help.
  - Forever shows Character, Spellbook, Talents, Professions, Legacy, Quest Log, Guild, Group Finder, Account Collection, Shop, and Menu.
- Mount auto-fill on Forever scans known vanilla mount spells instead of the (absent) mount journal.
- Combat safety: spell range indicators no longer update during combat, matching the existing item-range behavior.

### Fixed

- `GetSpecialization*` no longer errors on Forever, which has no specializations.
- Guarded `PlayerHasToy` / toy-box calls so the Toys and Hearthstones modules no-op cleanly on Forever.

## [1.1.0] - 2026-07-16

### Added

- Shared account-wide profile system.

<!-- Earlier versions are not listed here; history can be backfilled from the git tags. -->