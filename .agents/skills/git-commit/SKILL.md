---
name: git-commit
description: Draft Conventional Commits v1.0.0 commit messages for BarSmith changes. Use when asked to write or revise a git commit message, choose a commit type or scope, or format a commit body/footer for a repo diff.
---

# Git Commit

Use this skill to turn a repo diff into a clean Conventional Commits message.

## Workflow
1. Identify the main user-facing impact.
2. Choose the best type:
   - `feat` for new behavior
   - `fix` for bug fixes
   - `docs` for documentation only
   - `style` for formatting only
   - `refactor` for code changes with no behavior change
   - `perf` for performance work
   - `test` for tests or test docs
   - `chore`, `ci`, `build`, or `revert` when appropriate
3. Add a scope when it helps readability, using repo terms like `profiles`, `settings`, `quickbar`, or `barframe`.
4. Write the subject in imperative mood, lowercase, and keep it concise.
5. Add a body when the change needs context, tradeoffs, or migration notes.
6. Add `BREAKING CHANGE:` in the footer when the change is incompatible.

## Format
- `type(scope): subject`
- `type!: subject` for breaking changes
- Use `body` and `footer` sections only when they add value.

## Good Examples
- `feat(profiles): add shared profile selection`
- `fix(quickbar): defer refresh until combat ends`
- `docs(testing): add profile migration checklist`

## Guardrails
- Prefer one logical change per commit.
- Do not overstate the impact with `feat` or `fix` if the change is only maintenance.
- If the request is vague, infer the message from the actual diff rather than inventing a feature.
