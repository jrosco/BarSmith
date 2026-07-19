---
name: git-release
description: Draft BarSmith release notes and version guidance from Conventional Commits history. Use when asked to prepare release notes, changelogs, version bumps, or release plans from git history.
---

# Git Release

Use this skill to turn commit history into a release plan or release notes.

## Release Rules
- Base the release on Conventional Commits v1.0.0.
- Treat `feat` as a minor bump, `fix` as a patch bump, and `BREAKING CHANGE:` as a major bump.
- Group notes by user-facing impact instead of by raw commit order.
- Call out migration or saved-variable changes explicitly.

## Release Flow
1. Review commits since the last release tag.
2. Classify each commit by type and impact.
3. Decide the release bump from the highest-impact change.
4. Draft notes in clear sections.
5. Include verification or rollout notes where useful.

## Suggested Sections
- Summary
- Added
- Changed
- Fixed
- Breaking Changes
- Verification

## Good Practice
- Keep the summary short.
- Mention any compatibility or migration concerns.
- Avoid copying every commit verbatim when a grouped note is clearer.
