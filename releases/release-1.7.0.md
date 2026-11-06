---
version: 1.7.0
date: 2026-11-06
title: "countersign-skills 1.7.0: cheap translators under T3 Code"
summary: "Under T3 Code, translating new strings runs one ChatGPT model per locale, so your Claude quota pays only for judgement. Outside T3 Code nothing changes. A malformed row in the skill or rule lists now fails the checks."
type: minor
breaking: false
highlights:
  - "Translations run on a cheap ChatGPT model under T3 Code"
  - "One routing table says which work leaves Claude"
tags:
  - claude-code
  - skills
  - t3-code
testedWith:
  claudeCode: "2.1.318"
  codex: "0.159.3"
---

## Added

- **The `orchestration` rule has a routing table for T3 Code.** It sends the per-locale
  translators to `gpt-6.1-terra` with low reasoning through `delegate_task` and keeps every other
  kind of work on Claude, with Haiku as the fallback outside T3 Code.

## Changed

- **`i18n-translate` 1.1.0 runs its per-locale translators on `gpt-6.1-terra` under T3 Code.**
  Without T3 Code or its codex provider it uses Haiku as before, and its report says which route
  ran.
- `orchestrate` 1.5.1 leaves a fan-out skill's own routing alone and never sends a builder,
  planner, reviewer or researcher to the cheap model.

## Fixed

- **A `skills.tsv` or `rules.tsv` row with a missing tab or a malformed version passed the
  checks.** `scripts/catalog.sh` now names the line and the fields it needs.

## Removed

- None.

## Security

- None.
