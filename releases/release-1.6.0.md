---
version: 1.6.0
date: 2026-10-30
title: "countersign-skills 1.6.0: lighter skills, short handoffs, clean branch cleanup"
summary: "Skills read only their own part of a repo's facts, and handoffs carry only what the next session cannot read for itself. Worktree and branch cleanup now works after squash merges and never stops halfway. Orchestrated runs ask before changing behaviour you did not ask for."
type: minor
breaking: false
highlights:
  - "Squash-merged branches are cleaned up without asking"
  - "Handoffs shrink to what the next session cannot read itself"
  - "Orchestrated runs ask before changing behaviour you did not ask for"
tags:
  - claude-code
  - skills
testedWith:
  claudeCode: "2.1.312"
  codex: "0.159.3"
---

## Added

- **`prune-branches` deletes local branches whose changes are already on the remote**, including
  squash-merged ones, which `git branch -d` refuses. It never touches the default branch,
  `staging`, a checked-out branch or a branch with an open pull request.

## Changed

- Every skill that looks up repo facts reads only its own section of the repo-facts file.
- `context-transfer` 1.2.0 writes only what the next session cannot read for itself, points at the
  run's plan file instead of copying it, and keeps to about 3 KB.
- `orchestrate` 1.5.0 asks before a change you did not request that alters behaviour or reverts
  earlier work, confirms its reversible calls in one question, and keeps `orchestrator.md` under
  6 KB. With no `planner` agent installed, the main session writes the spec itself.
- The `safety` rule removes what `remove-worktree` or `prune-branches` verifies as landed without
  asking. The `orchestration` rule shows reversible calls for approval before building.
- Releases go from one branch straight into `main` through one pull request; the `staging`
  branch and its ruleset are gone.

## Fixed

- **`remove-worktree` stopped halfway when it was chained or piped**, leaving a worktree
  half-removed and calling its branch "not merged". It now exits before touching anything and says
  to run it as a command of its own. A branch it cannot delete is reported with git's error.

## Removed

- None.

## Security

- None.

## Upgrading

- Re-run `install.sh`: it links `prune-branches` into `~/.local/bin` and lets it run outside the
  sandbox.
