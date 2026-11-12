# countersign-skills

Skills, global rule modules and subagent types for coding agents (Claude Code, Codex,
Antigravity), installed by POSIX `sh` scripts (`install.sh`, `update.sh`, `uninstall.sh`, with
`lib.sh` shared) and described by a generated `catalog.json`. `jq` handles the JSON.

## Rules

- Zero comments in shell scripts, workflows and Markdown. Names carry the meaning. Rationale goes
  into `docs/`. A pinned action's `# vX.Y.Z` suffix stays.
- The only `# shellcheck` directive is `source=lib.sh` before each `. "$root/lib.sh"`. Fix the
  code otherwise, or use the exclusions in `.shellcheckrc` and `scripts/lint.sh`.
- POSIX `sh` with `set -eu`, BSD and GNU compatible, macOS first.
- Every `SKILL.md` ends with the exact `local.md` line, keeps `description` at most 200 bytes and
  its folder name equal to its `name`, and has `when_to_use` unless it disables model invocation.
- List every skill in `skills.tsv` and every rule in `rules.tsv`. Bump a skill's version there
  with every change to it.
- Regenerate `catalog.json` with `scripts/catalog.sh`; `./test.sh` fails while it is stale.
- A skill installed for Codex that the model may invoke names `Agent`, `AskUserQuestion` or
  `Artifact` only with an `**Under Codex**` paragraph saying what Codex does instead; `./test.sh`
  checks it.
- Prose: short declarative sentences, English only.
- Conventional Commits, one task per commit.

## Writing for agents

- A `SKILL.md` holds the path through the task. Detail goes into `references/` files, named at the
  step that needs them.
- Point at context, do not paste it: name the file and the line range.
- Every session pays for descriptions and rules; every step an agent holds at once costs focus. Cut
  the first before the second.

## Gates

gate: scripts/check.sh

Run it as `gate`, which runs that line and stamps the tree. It must pass before a change is done.
It runs `./test.sh`, every `scripts/test-*.sh` and `scripts/lint.sh`.

## Repo facts

| Fact | Detail |
| --- | --- |
| The surfaces, and how to reach each | `cli`: run `install.sh`, `update.sh` and `uninstall.sh` against a scratch home, `HOME="$(mktemp -d)" CLAUDE_CONFIG_DIR= ./install.sh`, never the real one. `bin/statusline`: reads Claude Code's status line JSON on stdin. `bin/gh`: wraps gh; run it with a stub gh first on PATH, as `scripts/test-gh.sh` does. `bin/harness-hook`: reads a Claude or Codex hook payload on stdin; run it as `scripts/test-hooks.sh` does. |
| Branches | One branch per release carries all of its work and its note, and goes into `main` through one pull request. There is no `staging`. |
| Reviews | No automated review and no required approval; reviews follow `docs/review-checklist.md`. |
| Release PRs | The release branch goes into `main` as a merge commit titled `chore(release): v<semver>`, with no promotion contract; the note is `releases/release-<semver>.md` (contract in `releases/README.md`) and is committed on that branch, and a `v*` tag on `main` starts the release workflow. No check runs only on release PRs. |
| Licence | MIT, no CLA. |
