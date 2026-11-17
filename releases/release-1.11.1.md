---
version: 1.11.1
date: 2026-11-17
title: "countersign-skills 1.11.1: agent https fetch and push work again from worktrees"
summary: "agent-gh-token no longer refuses a private key outside every repo when git runs it as a credential helper from a worktree. The work-tree check now ignores the repo variables git passes to the helper."
type: patch
breaking: false
highlights:
  - "agent-gh-token works as a git credential helper from worktrees again"
tags:
  - claude-code
  - codex
testedWith:
  claudeCode: "2.1.326"
  codex: "0.159.3"
---

## Added

- None.

## Changed

- None.

## Fixed

- **`agent-gh-token` no longer blocks https fetch and push from worktrees.** Run as a git
  credential helper from a linked worktree, the tool inherited git's absolute `GIT_DIR`. Its check
  that the private key sits outside every repo then reported every folder as a work tree, so it
  refused a key that was in no repo, and every https fetch and push from an agent session failed.
  The check now clears the variables `git rev-parse --local-env-vars` lists before it runs. A key
  inside a work tree is still refused.

## Removed

- None.

## Security

- None.

## Upgrading

- A symlinked install picks up the fix when you pull `main` in the checkout `install.sh` ran from.
  Run `update.sh` only for copies installed with `install.sh --copy`.
