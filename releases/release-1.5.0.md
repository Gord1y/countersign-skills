---
version: 1.5.0
date: 2026-10-23
title: "countersign-skills 1.5.0: no stray worktrees, HTML walkthroughs, opus plans"
summary: "Orchestrated runs leave no worktree behind, and a run that changed the UI ends in a walkthrough page whose screenshots open full size. Opus plans the intricate units and sonnet builds them all. QA checks in code first and sets up its own data, and the closing summary leads with what needs you."
type: minor
breaking: false
highlights:
  - "Every finished worktree goes, including hand-ported units and scratch copies"
  - "UI walkthroughs are one HTML page with sharp, zoomable screenshots"
  - "A read-only planner on opus, every build on sonnet"
tags:
  - claude-code
  - skills
testedWith:
  claudeCode: "2.1.299"
  codex: "0.159.3"
---

## Added

- **The `planner` agent turns an intricate unit's brief into an exact spec, read-only.** A sonnet
  builder then implements the spec. A product or contract decision still parks for you.
- **`land-worktree --ported <worktree>` records a unit you ported by hand**, after its commit, so
  `remove-worktree` can clear it.
- **A UI change's walkthrough is one self-contained `walkthrough.html`.** Screenshots sit inline,
  and each opens full size in a viewer you step through with the arrow keys. Other changes keep
  `walkthrough.md`.
- **`qa-tester` checks loading states.** Skeletons must match the loaded layout, layout shift stays
  low, and no empty state flashes in between.

## Changed

- `remove-worktree --landed`, and the `SessionEnd` sweep that runs it, also remove clean detached
  worktrees under `.claude/worktrees/` and folders there that hold only ignored output. Either is
  kept while a process still runs inside it.
- `orchestrate` 1.4.0 never runs a builder on opus. A session hands off at 10 landed units or about
  300K tokens of context, and stops an over-budget builder with `TaskStop`. Run state is read by
  range, and the PR description draft is refreshed when a run closes.
- `qa-tester` 1.1.0 asserts in code first and takes one screenshot per check, sharp at 2x and
  cropped to what matters. It sets up missing data itself through the API, the local database or
  the running servers before it calls a case blocked.
- `feature-pr-description` 1.2.0 describes the whole branch again when a PR gained commits, and
  always proposes the title.
- The `responses` rule puts a **Needs you** block first in the closing summary, with every line a
  list item. The `tooling` rule reads an Artifact once and works from the saved file.

## Fixed

- **`remove-worktree` kept a builder worktree forever once its unit was ported by hand.** Record the
  port with `land-worktree --ported`, and the worktree goes.
- **`land-worktree` failed partway when the work it landed changed `land-worktree` itself.** Both
  worktree scripts now read the whole file before running.

## Removed

- None.

## Security

- None.

## Upgrading

- Re-run `install.sh`: it links the new `planner` agent into `~/.claude/agents`.
- A worktree ported by hand before this release has no record. If you know its work landed, run
  `land-worktree --ported <worktree>` from the checkout that has it, then `remove-worktree
  <worktree>`.
