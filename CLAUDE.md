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
- Prose: short declarative sentences, English only.
- Conventional Commits, one task per commit.

## Gates

```sh
scripts/check.sh
```

It must pass before a change is done. It runs `./test.sh`, every `scripts/test-*.sh` and
`scripts/lint.sh`.

## Repo facts

| Fact | Detail |
| --- | --- |
| The surfaces, and how to reach each | `cli`: run `install.sh`, `update.sh` and `uninstall.sh` against a scratch home, `HOME="$(mktemp -d)" CLAUDE_CONFIG_DIR= ./install.sh`, never the real one. `bin/statusline`: reads Claude Code's status line JSON on stdin. |
| Branches | Pull requests go into `staging`; `main` moves only at releases. |
| Reviews | No automated review and no required approval; reviews follow `docs/review-checklist.md`. |
| Licence | MIT, no CLA. |
