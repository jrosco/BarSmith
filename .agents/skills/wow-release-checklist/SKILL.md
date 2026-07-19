---
name: wow-release-checklist
description: Draft WoW release notes, version guidance, and verification steps from commit history. Use when preparing BarSmith releases, changelogs, or release plans from Conventional Commits history.
---

# WoW Release Checklist

Use this skill when turning git history into a release plan.

## Release Rules
- Base the release on Conventional Commits v1.0.0.
- Treat `feat` as a minor bump, `fix` as a patch bump, and `BREAKING CHANGE:` as a major bump.
- Group notes by user-facing impact instead of commit order.
- Call out migration, saved-variable, and combat-safety changes explicitly.

## Suggested Sections
- Summary
- Added
- Changed
- Fixed
- Breaking Changes
- Verification

## Release Flow
1. Review commits since the last tag.
2. Classify each commit by type and user impact.
3. Decide the version bump from the highest-impact change.
4. Draft notes with grouped bullets and a short summary.
5. Include verification steps and any migration warnings.
