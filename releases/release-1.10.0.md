---
version: 1.10.0
date: 2026-11-17
title: "countersign-skills 1.10.0: gates no longer run the machine out of memory"
summary: "At most two gates run on a machine at once and one per tree, and a subagent working in its parent's tree no longer runs its own gate. Long sessions under T3 Code now remove landed worktrees and merged branches on their own."
type: minor
breaking: false
highlights:
  - "At most two gates run at once per machine, and one per tree"
  - "Subagents in a shared tree, such as translators, no longer run a gate"
  - "Landed worktrees and merged branches are cleaned up during long sessions"
tags:
  - claude-code
  - codex
  - hooks
  - gate
testedWith:
  claudeCode: "2.1.326"
  codex: "0.159.3"
---

## Added

- **`COUNTERSIGN_GATE_SLOTS` caps concurrent gates per machine.** The default is 2. A further
  gate prints one "waiting for a slot" line and queues until a slot frees. A value that is not a
  positive integer exits 2 with a clear message.
- **The stop sweep.** On a main session's stop, `harness-hook` starts `remove-worktree --landed`
  and then `prune-branches` in the background, at most once in 30 minutes per repository, for
  Claude Code and Codex. Under T3 Code a session lives for hours and is killed, so `SessionEnd`
  almost never fired and landed worktrees piled up. The sweep runs from the hook both providers
  already trust, so Codex asks for no new trust. See `docs/hooks.md`.

## Changed

- **A subagent's stop asks for a gate only in its own `.claude/worktrees/agent-*` worktree.** A
  subagent working in its parent's tree, a T3 Code worktree or the main checkout leaves the gate
  to the parent, whose own stop still demands one.
- **Translators never run a gate.** The `i18n-translate` subagent rules say so, and the
  orchestrator gates once after every locale lands. `orchestrate` tells agents that a waiting gate
  is normal and that they must not start a second one.
- **`remove-worktree --landed` also covers `.claude/worktrees/` inside every linked worktree.** It
  never removes a linked worktree itself, so T3 Code's own worktrees stay with T3 Code.

## Fixed

- **Concurrent gates in one tree no longer all run.** A per-tree lock makes a second `gate` wait
  for the running one. It then exits 0 without rerunning when that tree has already passed. Before
  this, 14 translator subagents in one worktree each ran the full gate, and parallel runs
  overwrote one `gate.log` and one ESLint cache.
- **A dead gate's lock is cleared safely.** The holder counts as dead only when `kill` reports no
  such process, because the macOS sandbox refuses `kill -0` on live processes. A lock with a
  malformed pid is kept until it ages.
- **`scripts/test-gate.sh` no longer leaves waiting `gate` processes behind.** It killed the
  subshell around each backgrounded gate, so the gate itself kept polling forever.

## Removed

- None.

## Security

- None.

## Notes

- Codex's `workspace-write` sandbox cannot write `~/.cache`, so a gate started by Codex runs
  without a slot and prints a warning.
