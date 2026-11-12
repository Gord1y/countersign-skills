---
version: 1.8.0
date: 2026-11-13
title: "countersign-skills 1.8.0: one entry point, enforced walls, Codex parity"
summary: "Every coding task now starts from one skill that picks a checklist for the kind of work. Hooks on Claude Code and Codex guard protected branches, keep writes inside the project, cap pull request size and stop an unchecked finish. Codex gets the orchestration skill, the same walls and settings that follow you between devices."
type: major
breaking: true
highlights:
  - "One entry point with ten checklists, from bug fix to release"
  - "Hooks that block unsafe pushes, stray writes and unchecked finishes"
  - "Codex shares the checklists, the walls and your profile settings"
tags:
  - claude-code
  - codex
  - skills
  - hooks
testedWith:
  claudeCode: "2.1.322"
  codex: "0.159.3"
---

## Added

- **`orchestrate` routes every task to one of ten playbooks.** Feature, bug fix, refactoring,
  investigation, prototype, UI change, release, PR triage, knowledge update and unattended run
  each have a checklist. Every checklist keeps a retro step for rough runs; a knowledge update
  closes each one that merges code.
- **`orchestrate` installs for Codex.** Codex builds each unit in its own worktree under
  `.claude/worktrees/agent-codex-<NN>`, so the scope fence and the landing allowlist hold for it
  too. Under T3 Code its code goes to Claude for review; without T3, you run that review.
- **A plan contract for orchestrated runs.** `plan-lint` checks and stamps the approved plan,
  `land-worktree --files` lands only the files a brief names, and a decision log records parked
  questions, deviations and every agent's calls.
- **Hooks for Claude Code and Codex, from one shared policy.**
  - Pushes to feature branches pass; pushes to `main`, `staging` and `release-*` are denied.
  - File writes stay inside the session's repo and worktree; `~/.claude/plans`, the session
    scratchpad, `$TMPDIR` and, from a worktree, the main checkout's `writeups/` stay open.
  - While a batch is fenced, writes into its builder worktrees stay inside the approved plan's
    slices, whichever session makes them.
  - A pull request over 400 changed lines is denied, except from a release or promotion branch.
  - A pull request that changes the UI needs a walkthrough.
- **`gate` runs the repo's checks and stamps the tree.** Claude Code and Codex block the first
  attempt to finish a turn whose changed files have no passing stamp.
- **The `repo-knowledge` skill.** It bootstraps, updates and lints a repo's knowledge graph:
  feature nodes, a path index, a glossary and decision records, with a drift lint for CI.
- **The `retro` skill.** It turns a session's mistakes into tests, lint rules or docs, and proves
  each fix on the real mistake. Agents can run it and `repo-knowledge` on their own.
- **The `conformance` agent.** It checks a change against its plan: every changed file maps to a
  slice and every criterion to evidence.
- **The install writes a managed block into Codex's `config.toml`.** It sets compaction at 200K
  tokens, `approval_policy = "never"` and `sandbox_mode = "workspace-write"`, merges the hooks into
  `~/.codex/hooks.json`, and `uninstall.sh` puts back what it displaced.
- **Your profile can carry Codex settings to every device.** A `codex/config.toml` in the profile
  is merged on install: top-level keys join the managed block, and table keys such as a plugin's
  `enabled` are changed in place. `uninstall.sh` restores the lines it changed.
- **The `responses` rule asks for plain speech.** No dashes as punctuation, no stock AI
  vocabulary, and every claim says whether it was measured, inferred or guessed.
- **The checks flag a skill installed for Codex that names a Claude-only tool** without saying
  what Codex does instead.

## Changed

- **The `orchestration` rule invokes `orchestrate` for every task that changes, investigates or
  ships code, routes each role between Claude and Codex, and now installs for Codex too.**
- **`orchestrate` keeps its step detail in reference files and no longer falls back to
  `general-purpose` subagents.** Without a `builder` agent it builds each unit in the main
  session.
- **The agents have sharper briefs.** Every agent starts from a fresh context, compacts at 300K
  tokens, reports the calls it made, and runs without a turn limit.
- **`writeups-cleanup` stays hidden from agents on Claude Code and Codex**, since only you run it.
- **`feature-pr-description`, `how-it-works`, `human-voice-writing`, `qa-tester` and
  `thorough-diff-review` gained evidence and merge-danger blocks, a history mode, two writing
  tells, a UI state matrix with base and head runs, and spec and reader-load lenses.**
- **The push deny rules left the Claude Code settings.** The push hook replaces them and allows
  feature branch pushes.

## Fixed

- **The README counted four subagents where five ship, and 11, 9 and 9 rules where 10, 8 and 8
  ship.**
- **`remove-worktree` called from the sandbox could leave a worktree half removed.** It now
  removes nothing and says to rerun it by its bare name.

## Removed

- **The `memory-review` skill.** `retro` replaces it.

## Security

- **Hooks deny pushes to protected branches and file writes outside the session's repo, on both
  Claude Code and Codex.**
- **Hooks deny `gh pr merge`, `gh auth token`, and `gh api` calls that change rulesets, branch
  protection, refs or merges.** A merge stays your action.

## Upgrading

- Re-run `install.sh` to install the hooks, `gate`, the Codex config block and your profile's
  Codex settings.
- In Codex, trust the new hooks when it asks ("Review hooks" or "Trust all and continue").
- Codex now runs with `approval_policy = "never"` inside a workspace-write sandbox; the hooks are
  the walls. Put a different value in your profile's `codex/config.toml` to change it.
