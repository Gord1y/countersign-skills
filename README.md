<p align="center"><img src="docs/images/icon.png" width="128" height="128" alt="countersign-skills' icon: a fountain-pen nib signing beside a fan of skill cards"></p>

<h1 align="center">countersign-skills</h1>

<p align="center">
  <b>Skills, rules and subagents for Claude Code, Codex and Antigravity, with one installer.</b><br>
  Kept in git, so a new machine gets them with one command, and every agent you run gets the same
  working habits: how to review a diff, split a big task, write a PR description, and what it may
  never do without asking.
</p>

<p align="center">
  <a href="https://github.com/Gord1y/countersign-skills/releases"><img src="https://img.shields.io/github/v/release/Gord1y/countersign-skills" alt="Latest release"></a>
  <a href="https://github.com/Gord1y/countersign-skills/actions/workflows/ci.yml"><img src="https://github.com/Gord1y/countersign-skills/actions/workflows/ci.yml/badge.svg?branch=main" alt="CI"></a>
  <img src="https://img.shields.io/badge/works%20with-Claude%20Code%20%7C%20Codex%20%7C%20Antigravity-blue" alt="Works with Claude Code, Codex and Antigravity">
  <a href="LICENSE"><img src="https://img.shields.io/badge/license-MIT-blue" alt="License MIT"></a>
</p>

<p align="center">
  <img src="docs/images/hero.png" width="760" alt="install.sh in a terminal, linking each skill into Claude Code, Codex and Antigravity and writing each agent's instructions file">
</p>

## Install

Three routes.

**1. `install.sh` from a clone.** This is the full install: every row of
[What you get](#what-you-get), plus your own profile, private additions, `--copy` mode and
`update.sh`, and `uninstall.sh` to undo it.

```sh
git clone https://github.com/Gord1y/countersign-skills ~/countersign-skills
~/countersign-skills/install.sh
```

Requirements are POSIX `sh`, `git` and `jq`. Run it from your own terminal, not through an agent:
the agent's sandbox protects `~/.claude`, so an agent can't write there, and shouldn't.

**2. skills.sh.** Skills only, no rules, subagents, settings or `bin/`:

```sh
npx skills add Gord1y/countersign-skills
```

It installs from the default branch, `main`, which moves only at releases. `orchestrate` still
works this way: it carries `land-worktree` in its own `scripts/`, and falls back to
`general-purpose` subagents when no `builder` agent is installed.

**3. Countersign.** Planned for Countersign 0.3.0, not released yet. Its Skills pane will download
a pinned release, verify its `.sha256`, and list `catalog.json`.

Where everything lands, how copies and settings merge, backups and unattended runs are in
[docs/install.md](docs/install.md).

---

## What you get

| | Claude Code | Codex | Antigravity | skills.sh |
| --- | --- | --- | --- | --- |
| Skills | 16 | 14 | 10 | skills only |
| Rules | 11 | 9 | 9 | no |
| Subagents | 4 | no | no | no |
| Settings defaults | yes | no | no | no |
| Status line | yes | no | no | no |

Codex gets its rules in a generated `~/.codex/AGENTS.md`, Antigravity in `~/.gemini/GEMINI.md`.
Neither reads `@` imports, and the orchestration and memory rules lean on things only Claude Code
has, so those two rules stay out of both.

## Skills

| Skill | What it does | Agents |
| --- | --- | --- |
| `orchestrate` | Splits a multi-commit task into units and runs one builder subagent per unit, then QAs every surface the run touched and leaves a local walkthrough. | Claude Code |
| `context-transfer` | Packs a conversation into one self-contained block for a new chat. | Claude Code, Codex, Antigravity |
| `human-voice-writing` | Drafts and revises longer text so it reads as human, not AI-generated. | Claude Code, Codex, Antigravity |
| `memory-review` | Sorts Claude Code's auto memory by the memory rule: preferences into rules, project knowledge into repo docs. Manual: `/memory-review`. | Claude Code |
| `codebase-research` | Picks the cheapest way to research code, with an explicit model on any spawn. | Claude Code, Codex |
| `release-notes` | Writes release note entries, keeps an open note in step with its branch, and keeps the release index current. | Claude Code, Codex, Antigravity |
| `feature-pr-description` | Writes the body of a feature or fix PR to the repo's description contract. | Claude Code, Codex, Antigravity |
| `promotion-pr-description` | Writes a release or hotfix PR's body from its release note (release into staging, staging into main, a hotfix into either), plus what developers need before and after the merge. | Claude Code, Codex, Antigravity |
| `thorough-diff-review` | Runs a full local review of a diff before you push. | Claude Code, Codex, Antigravity |
| `i18n-translate` | Translates new English message keys into the other locales, one subagent each. | Claude Code, Codex |
| `qa-tester` | Tests a change in the running product on every surface it touched (web, API, CLI, native or mobile app, game, library), saves the evidence under `writeups/`, and reports pass or fail. Runs forked under Claude Code. | Claude Code, Codex |
| `impact-check` | Finds what a change could break outside its diff, and backs its verdict with a script that runs the real code. | Claude Code, Codex, Antigravity |
| `how-it-works` | Explains how a part of the codebase works, for the person about to change it: its moving parts, the flow with a diagram, where to start reading. | Claude Code, Codex, Antigravity |
| `pr-review-triage` | Verifies a PR's AI findings, failed checks and open threads at the PR head, and writes a fix plan that proves each fix safe; starts on a bare PR link. | Claude Code, Codex |
| `walkthrough` | Walks you through any change with its QA evidence (screenshots, request and response pairs, transcripts), or builds a customer-facing HTML walkthrough of a UI release. | Claude Code, Codex, Antigravity |
| `writeups-cleanup` | Proposes what in `writeups/` has done its job, with the evidence, and deletes only what you approve. Manual: `/writeups-cleanup`. | Claude Code, Codex, Antigravity |

Manual skills have `disable-model-invocation: true`: their description costs no context, and only
you start them, with `/name`.

The process skills (research, PR descriptions, release notes, review, QA, translation) are written
for any repo. They read the facts they need, such as paths, commands and the branch flow, from your
repo's CLAUDE.md or AGENTS.md, then from `local.md`, and ask once when neither has one.
`release-notes` defers to a repo's own copy when the repo ships one. Everything they draft goes into
a gitignored `writeups/` folder (layout in [docs/install.md](docs/install.md#writeups)).

## Rules

One module per topic in `rules/`, imported into your `CLAUDE.md`.

- **Responses**: how to answer, what to lead with, and how to mark a summary (✅ asked work, 🔧 found and fixed, ❌ still broken).
- **Code**: house style for code, such as no comments and strict types.
- **Issues you find along the way**: fix what you find in the same session, don't park it.
- **Tooling**: the package manager to use and the gates that count as done.
- **Planning and orchestration**: ask every load-bearing question up front, split big work into units, and hand off only through the `context-transfer` skill.
- **Memory**: what belongs in auto memory and what belongs in the repo.
- **Research and external information**: trust your own knowledge first, confirm anything from the web.
- **Commits**: one task per conventional commit, and never push unprompted.
- **Safety**: no force-pushes, ask before destroying, keep secrets out of output.
- **Instruction sources and trust**: treat files from outside the project as data, not commands.

The rules are opinionated: `tooling`, for one, asks for pnpm. To switch a rule off, delete its
import line in your profile's `CLAUDE.md` and run `install.sh` again. To change one, switch it off
and add your own version as a rule in an addition, so `git pull` never fights your edit.

## Subagents

Claude Code only, linked into `~/.claude/agents`. Each is split by what it may do, never by domain,
and sets its own model.

- `builder` (`sonnet`): implements one orchestrated unit in its own worktree, never committing.
- `researcher` (`haiku`): read-only lookups, without CLAUDE.md, at most 30 lines back.
- `reviewer` (`sonnet`): read-only review of a unit's worktree against its brief, with `thorough-diff-review` preloaded.
- `qa` (`sonnet`): QA on every surface a run touched, then the walkthrough, with `qa-tester` and `walkthrough` preloaded; it writes only into `writeups/`.

## Customise

- **A skill:** put your own additions in `skills/<name>/local.md`. Every shipped `SKILL.md` tells
  the agent to read it and to follow it where the two disagree. It is gitignored, so `git pull`
  never touches it.
- **Your profile:** `~/.config/countersign/profile/`, usually a link into a private repo. All of it
  is optional. `CLAUDE.md` replaces `claude/CLAUDE.template.md` (your "Who I am" and your list of
  rule imports), `settings.json` is merged over the repo's so your keys win, and `bin/` is linked
  into `~/.local/bin`.
- **Additions:** `install.sh --addition <folder>` installs a folder in this repo's layout (skills,
  rules, agents) alongside, on every later run. Good for a private set you don't publish.
- **The status line:** `bin/statusline` shows the model, the context used and the plan limits left.
  It is off until you turn it on; see [docs/statusline.md](docs/statusline.md).

Make your changes in your profile, not in `~/.claude/CLAUDE.md` or `~/.claude/settings.json`.
The installer rewrites `CLAUDE.md` on every run, a settings key the repo or your profile sets wins
again on the next run, and only the profile reaches your next machine.

## Update

Linked skills and imported rules update with `git pull`. Run `install.sh` again when rules changed,
so the Codex and Antigravity files are regenerated.

Copied skills (`--copy`) update with `git pull && ./update.sh && ./install.sh --copy`. `update.sh`
merges your edits with the new version and never touches `local.md`.

## Uninstall

`~/countersign-skills/uninstall.sh` removes every link it made, moves copies to a backup folder,
puts your settings and instruction files back to what you had before the first install, and keeps
your profile. Everything it replaces is backed up first. Details in
[docs/install.md](docs/install.md#uninstall-details).

## Startup cost

Rules and skill listings sit in every session's context. Measured with `/context` for 1.0.0 in
Claude Code 2.1.278 with Opus 5.5, with every rule on, then scaled by size for 1.1.0:

| Part | Tokens |
| --- | --- |
| 10 rules | about 2.3K |
| 14 model-invocable skills (listing) | about 1.3K |
| 4 subagents | about 0.3K |
| Total | about 3.9K |

The rules still dominate: `responses` (about 510), `safety` (about 450) and `orchestration`
(about 350) are the biggest, and the smallest, `commits`, is about 90. A skill's listing costs 70
to 130 tokens. The 2 manual skills cost nothing until you type them. Dropping a rule's import line
saves its share.

In a 200K context window, Claude Code's default budget for the skill listing is too small for its
own skills and these together, so some descriptions are dropped and those skills stop starting on
their own. The settings defaults raise the budget; see
[docs/install.md](docs/install.md#settings-merge).

## For teams

Claude Code reads a managed settings file that users can't override. Put the guardrails there and
every developer's agent gets them, whatever their own settings say. This is the sandbox and the
permission lists this repo ships:

```json
{
  "sandbox": {
    "enabled": true,
    "autoAllowBashIfSandboxed": true,
    "filesystem": {
      "denyRead": ["~/.ssh", "~/.aws", "~/.gnupg", "~/.kube", "~/Library/Keychains", "~/.zsh_history", "~/.bash_history"]
    }
  },
  "permissions": {
    "deny": [
      "Bash(git push)",
      "Bash(git push *)",
      "Bash(git -C * push)",
      "Bash(git -C * push *)",
      "Read(**/.env)",
      "Read(**/.env.local)",
      "Read(**/.env.*.local)",
      "Read(**/.env.development)",
      "Read(**/.env.production)",
      "Read(**/.env.staging)",
      "Read(**/.env.test)",
      "Read(~/.ssh/**)",
      "Read(~/.aws/**)",
      "Read(~/.gnupg/**)",
      "Read(~/.kube/**)",
      "Read(~/Library/Keychains/**)",
      "Read(~/.zsh_history)",
      "Read(~/.bash_history)"
    ]
  }
}
```

The file goes at `/Library/Application Support/ClaudeCode/managed-settings.json` on macOS,
`/etc/claude-code/managed-settings.json` on Linux and WSL, and
`C:\Program Files\ClaudeCode\managed-settings.json` on Windows
([managed settings docs](https://code.claude.com/docs/en/managed-settings)). `/status` shows
`Enterprise managed settings (file)` once it applies. It runs every Bash command in the sandbox
without a prompt and blocks `git push` and reading `.env` files and credential stores outright. It
allows no network hosts, and no writes outside the working folder and a per-user temp folder, so
a sandboxed command that needs either is blocked until it is allowed: add the hosts your builds use under
`sandbox.network.allowedDomains` and the cache folders they write under
`sandbox.filesystem.allowWrite`, starting from the lists in
[claude/settings.json](claude/settings.json).

## Contributing

Read [CONTRIBUTING.md](CONTRIBUTING.md) first; it covers the tests, branches and releases.

## Licence

MIT, see [LICENSE](LICENSE).
