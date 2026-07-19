---
name: git-pr-review
description: Review BarSmith pull requests and diffs with a code-review mindset. Use when asked to review code, list findings, check for regressions, or verify Conventional Commits compliance in commits that are part of the change.
---

# Git PR Review

Use this skill to review patches, pull requests, and commit sets for BarSmith.

## Review Priorities
- Bugs and regressions
- Combat-safety and secure-frame issues
- Saved-variable and migration safety
- Missing tests or verification steps
- Conventional Commits compliance when commit messages are in scope

## Review Flow
1. Read the diff and identify the user-visible behavior.
2. Check the highest-risk paths first.
3. Confirm the change matches the requested task.
4. Verify edge cases, nil handling, and combat lockdown behavior.
5. If commits are included, check that each one follows `type(scope): subject` and uses `BREAKING CHANGE:` when needed.

## Output Shape
- Start with findings.
- Order findings by severity.
- Include file references for each finding.
- Keep the summary brief and secondary.

## What to Call Out
- Broken or missing migration logic
- UI changes that can fail in combat
- Inconsistent settings or slash-command behavior
- Missing or weak verification
- Vague commit messages like `fix stuff` or `update`
