---
version: 1.4.0
date: 2026-10-19
title: "countersign-skills 1.4.0: builder worktrees cleaned up for real"
summary: "Finished builder worktrees now go away: remove-worktree recognises work landed on any checkout of the repo, and work a commit hook reformatted, and a session-end hook sweeps landed worktrees automatically. Release notes are written only while a release is prepared, never during feature work."
type: minor
breaking: false
highlights:
  - "Landed builder worktrees are removed when a session ends"
  - "Work landed on a feature branch or reformatted on commit counts as landed"
  - "Release notes wait for release preparation"
tags:
  - claude-code
  - skills
testedWith:
  claudeCode: "2.1.303"
  codex: "0.159.3"
---

## Added

- A second `SessionEnd` hook runs `remove-worktree --landed` in the project folder, so builder
  worktrees whose work is committed go when a session ends, whichever session cut them. It stays
  silent and keeps locked worktrees and anything uncommitted.

## Changed

- `orchestrate` 1.3.0: `land-worktree` records what it landed, and units land from whichever
  checkout has the working branch out, the main checkout or the worktree the session works in.
- `release-notes` 1.2.0 triggers only on a request or while a release branch is prepared for
  production, never during feature or fix work.
- `remove-worktree --landed` sweeps only builder worktrees (`.claude/worktrees/agent-*`), never a
  worktree a session entered to work on a branch.

## Fixed

- **`remove-worktree` kept every worktree whose work landed outside the main checkout's branch.**
  It now accepts work committed in any checkout of the repository, such as a feature branch out in
  a linked worktree.
- **`remove-worktree` kept every worktree whose files a commit hook reformatted.** A file
  `land-worktree` recorded, unchanged since, and committed afterwards now counts as landed.
- **Builder branches piled up after their worktrees were removed.** The branch now goes once its
  tip is on the branch the work landed in.

## Removed

- None.

## Security

- None.

## Upgrading

- Re-run `install.sh`: it adds the worktree sweep to `hooks.SessionEnd` in
  `~/.claude/settings.json`.
- Worktrees landed before this release have no landing record, so `remove-worktree` may still keep
  them. Check each with `remove-worktree --dry-run --landed` and remove it by hand once you know its
  work landed.
