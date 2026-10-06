---
version: 1.1.0
date: 2026-10-06
title: "countersign-skills 1.1.0: triage that verifies, no prompts in the sandbox, lighter rules"
summary: "PR triage now verifies what reviewers and CI found and plans fixes it proves safe, instead of reviewing again. The settings defaults stop asking inside the sandbox and deny credential stores instead. The always-loaded rules are half their size, and closing summaries mark work found and fixed with its own marker."
type: minor
breaking: false
highlights:
  - "pr-review-triage verifies AI findings and failed CI, and proves every planned fix safe"
  - "No permission prompts inside the sandbox; credential stores denied outright"
  - "Rules at half their size, and a 🔧 marker for work found and fixed"
tags:
  - claude-code
  - codex
  - antigravity
  - skills
testedWith:
  claudeCode: "2.1.291"
  codex: "0.159.3"
---

## Added

- `pr-review-triage` takes failed CI checks as a source. It reproduces each failure at the PR head
  and at the base, and tells a real failure from a pre-existing, flaky or configuration one.
- A 🔧 marker in closing summaries, for work found along the way and fixed, the agent's own earlier
  mistakes included.

## Changed

- `pr-review-triage` 2.0.0 verifies what reviewers and CI found instead of running a review of its
  own; a fresh review runs only when you ask for one. Every planned fix carries its blast radius,
  the premise it is safe because of, a regression test that fails first, and the gates. The plan
  goes to `~/.claude/plans/<repo>-pr-<N>.md` with `Answer:` lines, no longer to
  `writeups/reviews/`.
- The settings defaults no longer ask before anything. Inside the sandbox a command runs without a
  prompt; outside it, auto mode's classifier decides.
- The always-loaded rules are about half their former size, 14.6 KB to 6.6 KB. Each keeps its rule
  and drops its mechanism, which moved to `docs/install.md`.
- Closing summaries show the state when the turn ends, so nothing fixed in that turn is ❌, and stop
  at 12 lines before the TL;DR.
- The gate recipe is `set -o pipefail; <cmd> 2>&1 | tail -n 60`, with no temp log.
- `writeups-cleanup` 1.0.1: the drafts layout has no `reviews/` folder any more.
- Sandboxed commands may also write Godot's `~/Library/Application Support/Godot`.
- `promotion-pr-description` 2.0.0 builds a release PR from its release note: the note's title,
  summary, highlights and entries, then what developers need before and after the merge. It starts
  when you ask for a release PR description, and `feature-pr-description` 1.0.1 leaves release PRs
  to it.

## Fixed

- A sandbox or auto-mode list in your profile replaced the repo's whole list, so the repo's entries,
  including any it added later, never reached you. `install.sh` now joins the sandbox's
  `excludedCommands`, filesystem read and write lists and `network.allowedDomains`, and
  `autoMode.environment` and `allow`, across the repo file, your profile and
  `~/.claude/settings.json`, as it already joined the permission lists.
- The tooling rule said a failing command's output keeps only its start. It keeps the start and the
  end, so the gate recipe no longer writes a `$(mktemp …)` log, a path project hooks could not
  resolve and prompted on.

## Removed

- The `context-transfer` rule module. Its one line now lives in `orchestration`.
- The five `ask` rules from the settings defaults: `git reset --hard`, `git clean`, `git branch -D`,
  `gh pr merge` and `gh repo delete`.

## Security

- `~/.ssh`, `~/.aws`, `~/.gnupg`, `~/.kube`, `~/Library/Keychains` and the shell histories are
  denied both to the file tools, with `Read(...)` rules, and to sandboxed commands, with
  `sandbox.filesystem.denyRead`. Each covers what the other misses.

## Upgrading

- Run `install.sh` again. It removes the old `ask` rules from `~/.claude/settings.json`, adds the
  credential-store denies, and rewrites the Claude Code, Codex and Antigravity instructions from
  the shorter rules.
- If your profile's `CLAUDE.md` imports `rules/context-transfer.md`, delete that line.
- If your profile's `settings.json` repeats the repo's sandbox paths, you can delete them: the
  lists are joined now, so the repo's entries reach you either way.
- If a repo of yours has its own `ask` rules, a hook that asks, or Bash allow rules, read "Project
  settings and hooks never ask" in `docs/install.md` before dropping them: the allow rules go with
  the asks, CI keeps its bounds, and Codex's rules follow.

## Notes

- This repository has no automated review and no required approval any more. Reviews follow
  `docs/review-checklist.md`, and the rulesets live in `.github/rulesets/`, where the `lint` check
  fails on any drift from GitHub.
