---
version: 1.11.0
date: 2026-11-17
title: "countersign-skills 1.11.0: a blind UX probe for releases, and fewer translator agents"
summary: "Releases can run a black-box UX probe: a separate T3 Code thread with no code access that explores the local app from a user-terms brief and writes issue candidates, which the codebase session triages. Translators are batched, and the installer names every Codex hook T3 Code's shadow home has not trusted."
type: minor
breaking: false
highlights:
  - "A blind UX probe reviews each release as a user, then the codebase session triages it"
  - "Translators are batched: one for under 20 strings, else one per 5 locales"
  - "The installer names Codex hooks that T3 Code's shadow home has not trusted"
tags:
  - claude-code
  - codex
  - t3-code
  - qa
  - i18n
testedWith:
  claudeCode: "2.1.326"
  codex: "0.159.3"
---

## Added

- **The UX probe.** `probe-init` sets up a probe folder outside every repo, refuses a folder inside
  a git work tree, and denies the code folders you pass with `--deny` plus T3 Code's worktrees,
  Claude Code's projects and plans, and Codex sessions. The probe thread reaches the product only
  through T3 Code's browser preview tools on the local stack, judges what a user meets and writes
  issue candidates. See `docs/ux-probe.md`.
- **The `release-brief` skill.** It writes what changed for users since the last probed ref, in
  user terms only: no paths, code names, selectors or click paths.
- **The release playbook runs the probe.** `orchestrate`'s release playbook gains three steps:
  `release-brief`, `probe` and `ux-triage`. Triage marks each candidate as confirmed, by design,
  duplicate or not reproducible against the code. The probe is skipped when the repo sets no UX
  probe, or outside T3 Code.

## Changed

- **`i18n-translate` batches translators.** Under 20 strings, one translator takes every locale
  that has work. From 20 strings, one translator handles each group of up to 5 locales. One run
  had started 14 agents for 4 strings.

## Fixed

- **The installer names every untrusted Codex hook, T3 Code's shadow homes included.** T3 Code
  runs Codex from `~/.t3/userdata/providers/codex/<instance>/shadow`, and Codex keys hook trust
  by the path it opened. Trust given for `~/.codex/hooks.json` therefore did not cover T3 Code,
  and every Codex hook was skipped there. Each home with an untrusted hook now gets one `trust` line
  with its `CODEX_HOME=<home> codex` command. The installer never writes `trusted_hash` itself.

## Removed

- None.

## Security

- None.

## Upgrading

- Re-run `install.sh` to link the new `release-brief` skill and `probe-init`, then run any `trust`
  command it prints.
