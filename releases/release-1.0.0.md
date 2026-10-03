---
version: 1.0.0
date: 2026-10-03
title: "countersign-skills 1.0.0: skills, rules and subagents for coding agents"
summary: "The first public release. Sixteen skills, eleven rule modules and four subagent types for Claude Code, with the skills and rules that work there also installed for Codex and Antigravity. One installer links them, layers your own profile and private additions on top, merges safe settings defaults, and undoes all of it on uninstall."
type: major
breaking: false
highlights:
  - "Sixteen skills: orchestrated multi-commit work, QA on any surface, reviews, PR text, handoffs"
  - "One installer for Claude Code, Codex and Antigravity, with profiles, additions and uninstall"
  - "A status line that records your plan limits for Countersign's quota view"
tags:
  - claude-code
  - codex
  - antigravity
  - skills
testedWith:
  claudeCode: "2.1.278"
  codex: "0.159.3"
  antigravity: "1.2.14"
---

## Added

- Sixteen skills in the open Agent Skills format. Twelve start on their own when a request fits
  them: `orchestrate`, `qa-tester`, `walkthrough`, `thorough-diff-review`, `impact-check`,
  `pr-review-triage`, `feature-pr-description`, `codebase-research`, `how-it-works`,
  `context-transfer`, `human-voice-writing` and `i18n-translate`. Four run only when you type them:
  `/memory-review`, `/promotion-pr-description`, `/release-notes` and `/writeups-cleanup`.
- Eleven rule modules for the global instructions, from responses and code to safety and trust.
  Each is one import line, so dropping the line switches the rule off.
- Four subagent types for Claude Code, split by what they may do: `builder`, `researcher`,
  `reviewer` and `qa`, each with its own model.
- `install.sh`, `update.sh` and `uninstall.sh`. The installer links each skill into every installed
  agent that supports it, writes the global instructions for Claude Code, Codex and Antigravity,
  and merges the settings defaults into `~/.claude/settings.json`. `--copy` copies skills instead,
  and `update.sh` merges later releases into your edited copies.
- A profile in `~/.config/countersign/profile/` for your "who I am", settings layer and own
  tools, and additions: folders in this repo's layout whose skills, rules and agents install
  alongside.
- `bin/statusline`, a Claude Code status line with the model, the context used and the plan limits
  left. It also records the limits for Countersign's quota view. It is off until you turn it on.
- `catalog.json`, a generated list of every skill, rule and agent for loaders such as Countersign,
  attached to each release next to the tarball and its checksum.

## Changed

- None.

## Fixed

- None.

## Removed

- None.

## Security

- The settings defaults run Bash commands in Claude Code's sandbox (all but `gh`, `docker` and
  `git worktree`, which have to reach outside it), deny `git push`, deny reading `.env`,
  `.env.local` and the other conventional secret env files at any depth while `.env.example`
  stays readable, and ask before `git reset --hard`, `git clean`, `git branch -D`, `gh pr merge`
  and `gh repo delete`, even in auto mode.
- The installer allows reading, never editing, the installed skills' folders, so a skill's
  reference files load without a prompt in any project.
