# Installer internals

The README covers the install routes and the common options. This page holds the detail behind
`install.sh`, `update.sh` and `uninstall.sh`: what gets linked or copied, where it goes, how the
settings merge, and what to expect when a run is unattended.

## Where skills go

`install.sh` links every skill into the skill folder of each installed agent that supports it:

| Agent | Folder |
| --- | --- |
| Claude Code | `~/.claude/skills` (or `$CLAUDE_CONFIG_DIR/skills`) |
| Codex | `~/.agents/skills`, when `~/.codex` exists |
| Antigravity CLI | `~/.gemini/antigravity-cli/skills`, when that folder exists |

It also links every file in `agents/` into `~/.claude/agents` (or `$CLAUDE_CONFIG_DIR/agents`), in
both modes.

A folder already at a skill's place is moved to `~/.config/countersign/skills/backups/<time>/`
first, never deleted; the newest 5 runs' backups are kept. A link to a skill this repo no longer has
is removed. Running it again changes nothing.
`--skills orchestrate,human-voice-writing` installs only the skills you name.

## Link or copy

Plain `install.sh` links, so an edit is a git commit and `git pull` updates the skill.

`--copy` copies each skill instead, for when you want to edit skills in place. It records every
copied file's version and checksum in `~/.config/countersign/skills/manifest.tsv` and keeps the
shipped version in `~/.config/countersign/skills/base/<agent>/<skill>/`, so later updates can be
merged with your edits. A second `--copy` run leaves the copies it made alone. Running without
`--copy` turns a copy back into a link, after moving the copy to the backup folder.

## Global instructions

`install.sh` writes `~/.claude/CLAUDE.md` from your profile's `CLAUDE.md`, else from
`claude/CLAUDE.template.md`, with this repo's path filled in for `{ROOT}`. An existing file that
differs is moved to the backup folder first. Claude Code reads the imported rule files as if they
were part of the file. Edit `claude/CLAUDE.template.md`, never `~/.claude/CLAUDE.md`, so the change
reaches every machine.

Codex and Antigravity don't read `@` imports, so `install.sh` also generates their global
instructions from your `~/.claude/CLAUDE.md`, with every import expanded and only the rules
`rules.tsv` marks for that agent (the orchestration rule needs a skill only Claude Code has):

| Agent | File | When |
| --- | --- | --- |
| Codex | `~/.codex/AGENTS.md` | `~/.codex` exists |
| Antigravity | `~/.gemini/GEMINI.md` | `~/.gemini/antigravity-cli` exists |

Both are generated files: edit `claude/CLAUDE.template.md` or the rules, then run `install.sh`
again. A file that differs from what it would write is moved to the backup folder first.

## Profile, additions and state

Everything personal stays out of this repo, in `~/.config/countersign/` (under `$XDG_CONFIG_HOME`
when that is set, as Countersign does):

- **`profile/`**, your layer, usually a link into a private repo. Every part is optional:
  - `CLAUDE.md`: "Who I am" and the list of rule imports, used instead of
    `claude/CLAUDE.template.md`. Drop an import line to switch that rule off.
  - `settings.json`: merged over `claude/settings.json`, so your keys win and permission lists
    add up.
  - `bin/`: linked into `~/.local/bin` next to this repo's `bin/`.
- **Additions**: `install.sh --addition <folder>` records a folder in this repo's layout
  (`skills.tsv` and `skills/`, `rules.tsv` and `rules/`, `agents/`) and installs it alongside on
  every later run: its skills and agents are linked, and its rules are imported into `CLAUDE.md`
  for the agents its `rules.tsv` names. A name that two sources both install stops the run.
- **`skills/`**, the installer's state: the copies' manifest and base versions, the backups, the
  list of additions (`additions.tsv`), `settings-layer.json` (the exact settings the last run
  merged), `sources.tsv` (the folders the last run installed from), and `originals/` (your files
  from before the first install, for `uninstall.sh`).
- A link that points into a folder in `sources.tsv` counts as the installer's own. So after this
  repo or an addition moves or is dropped, the next `install.sh` removes the links left dangling
  into the old place, and `uninstall.sh` removes them too. Until that run every skill, agent and
  rule from the moved folder is missing, so run `install.sh` from the new place right after a
  move.

## Settings merge

`install.sh` merges `claude/settings.json`, then your profile's `settings.json`, into
`~/.claude/settings.json` (it needs `jq`):

- Every key the repo file sets wins, including whole arrays such as the sandbox's domain list.
  Your profile's `settings.json` is layered over the repo file the same way: an array it sets
  replaces the repo's whole array, so a profile `sandbox.filesystem.allowWrite` would hide every
  path the repo lists. Leave the sandbox lists to `claude/settings.json`.
- Keys it doesn't set stay as they are: hooks another tool installed (Countersign's), and anything
  Claude Code writes for this machine.
- `permissions.allow`, `permissions.ask` and `permissions.deny` are merged, so rules Claude Code
  saved from a "don't ask again" answer survive.
- Before merging, each value the last run merged (`settings-layer.json`) comes out again, the way
  `uninstall.sh` takes it out. So a key or rule that the repo or your profile drops is removed
  on the next run, and so is a path-bound rule after the repo moves. A value you changed since,
  and one you had before the first install, stay.
- There is no `ask` list: inside the sandbox nothing prompts, and outside it the auto-mode
  classifier decides. `deny` blocks `git push` and reading `.env`, `.env.local`, `.env.*.local`, `.env.development`, `.env.production`,
  `.env.staging` and `.env.test` at any depth, for the Read tool and sandboxed commands alike.
  `.env.example` and other templates stay readable and editable. The files are named because a
  deny always beats an allow: `Read(.env.*)` would also hide `.env.example`, and no `allowRead`
  re-opens it for the Read tool. Each rule starts with `**/` because a relative rule such as
  `Read(.env)` reaches sandboxed commands only at the top of the working folder, so a nested or
  worktree `.env` stayed readable.
- `deny` and `sandbox.filesystem.denyRead` both list the credential stores: `~/.ssh`, `~/.aws`,
  `~/.gnupg`, `~/.kube`, `~/Library/Keychains` and the shell histories. Each covers what the other
  misses: a `denyRead` entry doesn't stop the Read tool, and a `Read(...)` deny doesn't stop a
  script that opens the file itself. Every remote these repos use is https, so git needs none of
  them. `~/.npmrc` and `~/.netrc` stay readable, because pnpm and curl read them.
- `skillListingBudgetFraction` is `0.02`: the skill listing (each model-invocable skill's name
  and description) may use 2% of the context window instead of the default 1%. In a 200K window,
  1% holds Claude Code's built-in skills and only some of these: measured with Opus 5.5 in Claude
  Code 2.1.278, 7 of the 12 lost their descriptions, and a skill without one never starts on its
  own. At 2% all 12 keep them, for about 0.6K more tokens. In a 1M window 1% is already enough, so
  the setting changes nothing there. Claude Code doesn't document it yet; it drops the descriptions
  of the least-used skills first.
- `sandbox.filesystem.allowWrite` lists the cache folders sandboxed builds write: pnpm's
  `~/Library/pnpm`, `~/.npm`, `~/.cache`, `~/Library/Caches`, Xcode's
  `~/Library/Developer/Xcode/DerivedData` and Godot's `~/Library/Application Support/Godot`. On
  macOS the per-user temp folder (`getconf DARWIN_USER_TEMP_DIR`) is added to them, because Apple's
  `git` and `xcrun` write caches there.
- `permissions.allow` gets `Read(/<folder>/**)` for `~/.claude/skills` and for each source's
  `skills/`, under its path as given and its real path. So a skill reading its own reference
  files never prompts, in any project. Both sides are needed: Claude Code applies an allow rule
  to a read through a link only when the rule covers the link's path and the file it resolves to.
  These are `Read` rules on purpose: `permissions.additionalDirectories` would also allow edits,
  so any session could change the installed skills without asking. A `cd` into a skill folder
  from Bash can still prompt.

The previous file goes to the backup folder first, and an unchanged file prints `ok`. Change
settings in your profile's `settings.json` (or in `claude/settings.json`, for everyone), not in
`~/.claude/settings.json`, so the change reaches your next machine. `--no-settings` skips this
step. Personal choices (model, theme, plugins, the auto-mode entries naming your organizations) go
in your profile's `settings.json`, not here.

The sandbox protects `~/.claude` from sandboxed commands, so run `install.sh` from your own
terminal, not through an agent.

## Updating copies

Linked skills and imported rules update with `git pull`. Run `install.sh` again afterwards when
rules changed, so the Codex and Antigravity files are regenerated.

Copied skills update with `git pull && ./update.sh && ./install.sh --copy`. For each file,
`update.sh` replaces it if you never edited it, keeps it if only you changed it, and otherwise
merges your edits with the new version using `git merge-file`. Your version is kept next to a
merged file as `<file>.mine`, and a merge that conflicts leaves conflict markers for you to
resolve (`update.sh` then exits 1). It prints one line per skill, for example
`merged  claude orchestrate 1.0.0 -> 1.1.0`. `local.md` is never touched. The last command
regenerates the Codex and Antigravity files and installs any skill added since.

## Uninstall details

`uninstall.sh` undoes `install.sh` for this repo, its additions and your profile's `bin/`:

- Every link it made goes: skills, agents and `bin/`. Links it didn't make stay.
- Copies move to the backup folder.
- In `~/.claude/settings.json`, each value the last install merged (`settings-layer.json`) is put
  back to what you had before the first install, or removed if you had nothing there. A value you
  changed since is kept, and so is everything Claude Code wrote. When the install created the file
  and nothing is left in it, the file goes.
- `~/.claude/CLAUDE.md`, `~/.codex/AGENTS.md` and `~/.gemini/GEMINI.md` go back to the versions you
  had before the first install (`install.sh` keeps them in `originals/`), or move to the backup
  folder if there were none.

Everything it replaces goes to the backup folder first. Your profile and the list of additions
stay, so `install.sh` puts it all back.

## Unattended runs

The aim: approve one plan, then subagents finish the work with no permission prompts and no
questions.

- **Questions are settled before the run.**
  - The orchestration rule and the `orchestrate` skill put every load-bearing decision to you up
    front, at most four at a time.
  - A builder (`agents/builder.md`) can't ask. It takes the stated default for a reversible call,
    and logs it.
- **Prompts go away through two Claude Code features,** both turned on by `claude/settings.json`:
  - **The Bash sandbox, in auto-allow mode.** Every Bash command, in the main session and in every
    subagent, runs under macOS Seatbelt. It writes only to the working folder, the temp folders and
    the listed caches, and reaches only the listed hosts. Inside that boundary it needs no
    approval. `gh` and `docker` run outside it and are approved as usual, but only as a command
    of their own: a line that pipes or chains one with anything else runs sandboxed as a whole.
    There `gh` can't read its token from the keychain or verify TLS, so it looks logged out; the
    tooling rule has agents filter with `gh --jq` instead. A `git worktree *` entry was dropped:
    on Claude Code 2.1.278 it left `git worktree` sandboxed even as a command of its own (tested
    2026-10-04).
  - **Protected paths stay write-denied inside the sandbox:** the `.claude` settings files and
    its `hooks`, `skills`, `agents` and `commands` folders, `.mcp.json`, `.vscode` and any `.idea`
    folder. So `land-worktree` refuses a unit that changes one, for the orchestrator to port with
    Edit. From the sandbox, `git worktree add` can't check out a repo that tracks `.mcp.json` or
    `.vscode/`, or remove a worktree holding one. An `.idea` folder a dependency ships into
    `node_modules` blocks both the install and the removal. Builder worktrees still work: Claude
    Code creates them outside the sandbox. The orchestrator leaves a failed removal to you. A repo
    hit by the install failure lets its exact install command out, such as
    `pnpm install --frozen-lockfile`, with an `excludedCommands` entry and a matching allow rule.
    Builders then run that command on a line of its own.
  - **Auto mode's trust entries** (`autoMode.environment` and `autoMode.allow`). They tell the
    classifier which organizations, hosts and data are yours. They also say that a subagent may
    edit, delete and run gates inside its own worktree, that the orchestrator may land, commit and
    force-remove its own builders' worktrees, and that `qa-` test data on the local stack is
    routine.
  - **Builder worktrees start from your current `HEAD`** (`worktree.baseRef: "head"`), not from
    the remote default branch, so a builder sees the commits already on the working branch.
- **Project settings and hooks never ask.** A project `ask` rule prompts for sandboxed commands
  too, and a PreToolUse hook's `ask` forces a prompt even in auto mode: the classifier can deny it
  but never approve it. So a repo's layer denies what must never happen, such as a secret path,
  and returns nothing for the rest, leaving it to the sandbox and the classifier. A hook that
  can't resolve a path stays silent rather than asking: a `$(mktemp …)` log or a `$p` in a URL is
  not an access. Dropping a repo's asks takes three more changes, because the asks did other jobs:
  - **Drop the Bash allow rules the sandbox makes redundant.** A sandboxed command already runs
    without a prompt, so an allow rule only matters once the sandbox is off, and there it approves
    the call with no review. `Bash(find *)` then lets `find -exec`, `-fls` and `-fprint` run or
    write anything, as `sort -o`, `rg --pre` and `prettier --write` do for theirs, and no deny list
    keeps up with every flag. Keep an allow only for a command in `excludedCommands`, and deny
    its forms that run another program or write outside the repo.
  - **Keep the CI bounds.** Where a workflow runs Claude with the repo's settings, nothing can
    answer a prompt, so every ask was a deny. A runner has no sandbox, so a hook that went silent
    locally still denies when `GITHUB_ACTIONS` is `true`, and a workflow's `--allowedTools` gives
    `Read`, `Grep` and `Glob` rather than `Bash(find *)`, `Bash(rg *)` or `Bash(sort *)`.
  - **Mirror the change in Codex's rules,** `.codex/rules/*.rules`: a `prompt` rule there is an ask
    by another name.
- **Writing a permission rule:** for files only `Edit(path)` and `Read(path)` are consulted.
  `Edit` also covers Write, NotebookEdit and shell redirects, and a `Write(path)` rule is silently
  ignored. Precedence is deny, then ask, then allow. Never allow an interpreter or a shell by rule
  (`python3`, `node`, `sh -c`, `pnpm exec`) or "anything not denied"; make the narrow safe action
  free instead.
- **What still stops a run:** `git push` (denied), anything the classifier
  judges destructive or outside the trust boundary, and a Bash command that can't run in the
  sandbox. A builder that hits one reports it, and the orchestrator parks that unit and finishes
  the rest.

To adjust, use `/sandbox` or the Auto mode tab of `/permissions`, then copy the change into
`claude/settings.json`.

## Writeups

Every draft the skills write goes into one gitignored `writeups/` folder in the main checkout,
resolved from the main checkout so that a worktree cleanup never deletes it:

```
writeups/
  changes/<date>-<branch-or-run>/   pr.md, walkthrough.md, shots/, qa/
  releases/<version>/               promotion-staging.md, promotion-main.md, walkthrough.html, shots/
  briefs/<date>-<topic>.md          asks for other repos or teams
  scratch/                          delete any time
```

A `changes/` folder can go once its PR is merged and released, a `releases/` folder once the next
release ships, and `scratch/` any time. `/writeups-cleanup` proposes exactly those, and deletes
only what you approve.

## The land-worktree helper

`skills/orchestrate/scripts/land-worktree <worktree>` copies a builder worktree's uncommitted
changes into the current checkout and stages them, for the orchestrator to commit. It copies
nothing when the worktree holds commits or when one of its files changed on the branch since the
worktree was cut. It ships inside the skill, so a skills-only install has it too.

## Setting up a new machine

The whole setup is this repo, a private profile repo in the same layout, and the few secrets no
repo may hold:

1. **This repo:** `git clone https://github.com/Gord1y/countersign-skills ~/countersign-skills`.
2. **Your profile repo:** clone it and link its `profile/` as `~/.config/countersign/profile`. If
   it also keeps Claude Code's memory, clone your projects and link each project's memory folder
   back into it.
3. **Install:** run `~/countersign-skills/install.sh --addition <profile repo>` from your own
   terminal. It installs the skills, the agents, `CLAUDE.md`, the settings and the profile's
   `bin/`, and installs the profile repo's own skills and rules on every later run.
4. **Secrets:**
   - The research rule looks up library docs through the context7 MCP server. Add it with your
     key, as a user-scope server:
     `claude mcp add-json context7 '{"command":"npx","args":["-y","@upstash/context7-mcp"],"env":{"CONTEXT7_API_KEY":"<key>"}}' -s user`.
   - Anything your profile's tools read, such as an MCP catalog with keys, set up by hand.
5. **Countersign:** install it. It adds its own hooks to `~/.claude/settings.json`, and
   `install.sh` keeps them.
