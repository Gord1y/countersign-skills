---
version: 1.2.0
date: 2026-10-13
title: "countersign-skills 1.2.0: effort per agent, phased runs, QA per batch"
summary: "Every agent now runs at a set effort, and every spawn names it. Big work is planned in one session and built in others, at most 20 commits each, with QA after every batch that changes something you can see. A gh wrapper picks the GitHub account from the repo, so nobody switches accounts."
type: minor
breaking: false
highlights:
  - "Every agent and every spawn runs at a set effort, not the session's"
  - "Plan in one session, build in others, and QA every batch as it lands"
  - "gh picks the GitHub account from the repo, with no account switching"
tags:
  - claude-code
  - codex
  - antigravity
  - skills
testedWith:
  claudeCode: "2.1.296"
  codex: "0.159.3"
---

## Added

- `bin/gh` wraps `gh` and picks the account from the owner of the repo's `origin` remote, through
  `gh-accounts.tsv` in your profile. It never runs `gh auth switch`, so parallel sessions on
  different accounts don't break each other. As git's credential helper it gives `git push` and
  `fetch` the same account. Without the map, `gh` runs unchanged. See `docs/gh.md`.
- A `SessionEnd` hook removes the empty `.claude/.cc-writes` folders Claude Code leaves in
  subfolders, never the one at the project's top. `install.sh` now joins `hooks.SessionEnd`, so
  your own `SessionEnd` hooks stay.
- A rule that files shown to you (option sheets, screenshots, evidence, drafts) go into the
  project's `writeups/`, and plans and handoffs into `~/.claude/plans`.

## Changed

- The four agents pin their effort: `researcher` low, `builder` and `qa` medium, `reviewer` high.
  The orchestration rule, `orchestrate` 1.1.0, `how-it-works` 1.0.1, `i18n-translate` 1.0.1 and
  `impact-check` 1.0.1 name `effort` with `model` on every spawn.
- `orchestrate` plans in one session and executes in others, lands at most 20 units per session,
  and splits work bigger than one PR into phases under one index plan. The run folder stays current
  after every landing, so a handoff is a short write.
- `orchestrate` runs QA after every landed batch that touches a surface, with or without a dev
  server, and records each verdict in the run folder. The final QA covers what the batches could
  not.

## Fixed

- `codebase-research` 1.0.1 said the `Agent` tool takes no `effort`, so research spawns ran at the
  session's effort. They now pass `effort` with `model`.

## Removed

- None.

## Security

- None.

## Upgrading

- Run `install.sh` again: it links `gh` into `~/.local/bin`, adds the `SessionEnd` hook, and
  rewrites the Claude Code, Codex and Antigravity instructions from the changed rules.
- To use the gh wrapper, keep `~/.local/bin` ahead of the real `gh` on `PATH`, and add
  `gh-accounts.tsv` to your profile, one `owner<TAB>account` line per GitHub owner. Every account
  in it must be signed in to `gh`. For git, point its GitHub credential helper at the wrapper, as
  `docs/gh.md` shows.
