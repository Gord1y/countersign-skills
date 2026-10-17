---
version: 1.3.0
date: 2026-10-17
title: "countersign-skills 1.3.0: PR templates kept, shorter release PRs, worktrees cleaned up"
summary: "PR descriptions now keep the fixed parts of a repo's PR template, such as a list of review commands. Release PR bodies are the rendered note, without the before-and-after section. Orchestrators remove their own finished builder worktrees with a new remove-worktree command, which only removes work that is already committed."
type: minor
breaking: false
highlights:
  - "PR descriptions keep the repo's PR template, footers included"
  - "Release PR bodies drop the before-and-after section"
  - "remove-worktree clears finished builder worktrees instantly and safely"
tags:
  - claude-code
  - skills
testedWith:
  claudeCode: "2.1.302"
  codex: "0.159.3"
---

## Added

- `remove-worktree` (in `bin/`, and in `orchestrate`'s `scripts/`) removes builder worktrees under
  `.claude/worktrees/` whose changes are already committed on the current branch, and says why it
  keeps any other. It returns at once, deleting the files in the background, and runs outside the
  sandbox through `sandbox.excludedCommands`. `--landed` sweeps every finished agent worktree,
  `--dry-run` only reports. See `docs/install.md`.

## Changed

- `feature-pr-description` 1.1.0 and `promotion-pr-description` copy the fixed blocks of the
  repo's pull request template (headings with content, tables, checklists, a footer after `---`)
  into the body word for word, since `gh pr create --body-file` never applies the template.
- `promotion-pr-description` 3.0.0 renders the release note and nothing more: the "Before and
  after merging" section is gone, and the skill no longer asks for the release-only CI checks or
  the branch protection.
- `orchestrate` 1.2.0 runs `remove-worktree` after each landed unit and no longer hands you
  `git worktree remove --force` or `rm -rf` commands.

## Fixed

- None.

## Removed

- None.

## Security

- None.

## Upgrading

- Re-run `install.sh`: it links `remove-worktree` into `~/.local/bin` and adds
  `remove-worktree *` to `sandbox.excludedCommands` in `~/.claude/settings.json`.
