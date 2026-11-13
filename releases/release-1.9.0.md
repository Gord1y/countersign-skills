---
version: 1.9.0
date: 2026-11-13
title: "countersign-skills 1.9.0: agents work as a GitHub App, and the completion check works again"
summary: "Agents in Claude Code and Codex can push and open pull requests as a GitHub App you choose per owner, never as you. The completion check works again in repos that ignore their builder worktrees, and builders hit fewer false blocks."
type: minor
breaking: false
highlights:
  - "Agents push and open pull requests as a GitHub App, never as you"
  - "The completion check works again in repos that ignore their builder worktrees"
  - "Work in another repo you develop goes to a new thread there"
tags:
  - claude-code
  - codex
  - hooks
  - github
testedWith:
  claudeCode: "2.1.323"
  codex: "0.159.3"
---

## Added

- **`agent-gh-token` runs a command as a GitHub App.** It signs in as the app you map to a repo
  owner, gets a one-hour token that always covers that one repo alone, and runs the command with it.
- **`gh`, and git through it, uses that app in Claude Code and Codex sessions.** List an owner in
  `agent-gh-apps.tsv` in your profile. Agents then push and open pull requests as the app for every
  call tied to a repo, whether it comes from the checkout, `-R`, `--repo` or `GH_REPO`. The app has
  no administration rights and no bypass, so GitHub refuses its pushes to protected branches. Your
  own terminal keeps your account. See `docs/gh.md`.

## Changed

- **Work in another repo you develop starts in a new T3 Code thread in that repo.** The
  `orchestration` rule starts it without asking, and the `issues-found` rule sends a defect found
  there the same way. A repo owned by another team still gets only a note for that team.
- **Under T3 Code, builders and translators now run on Claude.** Codex only reviews Claude-written
  code, so every review comes from the other model family.
- **The write wall tells an agent how to get out.** In a worktree-only repo, a denied write now
  names the `git worktree add` command and the `EnterWorktree` tool.
- **The main checkout's `writeups/` stays writable in a worktree-only repo.** Evidence and briefs
  go there.
- **A builder is no longer blocked at the end of its turn when the repo has no `gate:` line.** It
  cannot edit `CLAUDE.md`. The main session still gets one block per session.
- **The `orchestrate` clickup step skips with a clear reason when no `clickup` agent is
  installed.**
- **The docs and tests use neutral example names** for owners, accounts and app ids.

## Fixed

- **`gate` failed with "could not hash the working tree" when `.claude/worktrees` was ignored.**
  That is the normal state after builders have run. The stop check failed open in the same repos,
  so it never blocked. Both work again, and a change inside `.claude/worktrees` still does not
  change the stamped tree.

## Removed

- None.

## Security

- **The app's sign-in token stays out of the process list.** `agent-gh-token` hands it to `curl`
  on standard input, so `ps` and other processes cannot read it.
- **A private key inside a git work tree is refused, also when it is reached through a symlink.**
- **An app that holds the administration permission is refused.** Keep it out of every ruleset's
  bypass list too, which you check in each repo.
- **The write wall denies a path with a `..` component and follows a symlink at the end of a path.**
  A write cannot reach a repo's source through `writeups/` any more.

## Upgrading

- Re-run `install.sh` to link `agent-gh-token` into `~/.local/bin`.
- To use an app, add `owner<TAB>app id<TAB>private key path` lines to `agent-gh-apps.tsv` in your
  profile, keep the key outside every repo, and install the app on every repo agents work in. Where
  it is not installed, `gh` fails in agent sessions.
