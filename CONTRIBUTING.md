# Contributing to countersign-skills

The repo is MIT licensed (see [LICENSE](LICENSE)), with no contributor license agreement. By
opening a pull request you agree your change is offered under the same licence.

## Test

Requirements: POSIX `sh`, `git`, `jq`, `shellcheck` and `actionlint`.

Before any change is considered done, run the gate:

```sh
scripts/check.sh
```

It runs `./test.sh`, every `scripts/test-*.sh`, and `scripts/lint.sh` (shellcheck at warning
severity, then actionlint). Install and update scripts are tested against a scratch home, never
your real one:

```sh
HOME="$(mktemp -d)" CLAUDE_CONFIG_DIR= ./install.sh
```

## Commit hook

Turn on the commit message check once per clone:

```sh
git config core.hooksPath scripts/git-hooks
```

It enforces Conventional Commits (`<type>[(scope)][!]: <subject>`) with a header of at most 100
characters, and rejects any `Co-Authored-By` line naming an AI tool or a "Generated with" line.

## Branches and pull requests

Open every pull request against `staging`; `main` only moves when a release is cut.

- One task per pull request. It is squash-merged into `staging` as a single commit whose subject
  is the pull request's title followed by ` (#<number>)`, and whose body is empty, so write the
  title as a Conventional Commit (`<type>[(scope)][!]: <subject>`). The `title` check enforces it.
- A pull request merges once `gates`, `commits`, `lint` and `title` pass and the branch is up to
  date with `staging` ("Update branch" on the pull request brings it up to date). The maintainer
  reviews every pull request someone else opens before merging it (their review is requested
  automatically), and reviews their own work locally before each release, against
  [docs/review-checklist.md](docs/review-checklist.md).
- No ruleset requires an approving review. Nobody can approve their own pull request and only the
  maintainer merges, so a required approval would only block the maintainer's own work. An
  automated Claude review supplied it until 1.0.0 and was removed, as in Countersign.
- For a pull request from a fork, the workflows wait until the maintainer approves them to run.
- Nobody pushes to `staging` or `main` directly, the maintainer included.

## Rulesets

Three rulesets enforce this, and none has a bypass actor, so they bind the maintainer too:

- `main`: no deletion, no force push, changes only through a pull request merged with a merge
  commit, and the required checks `gates`, `commits`, `lint` and `title`, each expected from the
  GitHub Actions app. No up-to-date requirement.
- `staging`: the same, but squash only and up to date.
- `release tags`: a `v*` tag can never be moved or deleted.

Each is committed as `.github/rulesets/<name>.json` in GitHub's own ruleset format, and the files
are the source of truth. GitHub never reads them itself: `scripts/rulesets.sh --apply` writes each
one to GitHub, updating the ruleset of the same name or creating it, then checks. Run it with `gh`
signed in as the maintainer. `scripts/rulesets.sh --check` fails on any difference, on a file with
no ruleset and on a ruleset with no file. The `lint` job runs it with its read-only token, which can
read a public repository's rulesets, so a ruleset changed in GitHub's settings fails CI until its
file follows. GitHub hides bypass actors from a token without admin rights; then the check compares
everything else, and only `--check` run by the maintainer covers them. To change a ruleset, edit its
file in a pull request and run `--apply` from that branch. The script never deletes a ruleset:
remove it in GitHub's settings and delete its file in the same pull request.
`scripts/test-rulesets.sh` covers the script offline, against a fake `gh` that serves the committed
files.

Auto-merge is on. With no approval required, "Enable auto-merge" on a pull request merges it by
itself once the required checks pass, and for `staging` once the branch is up to date. GitHub
Actions may run only GitHub's own actions, each pinned to a full commit SHA. The workflows' default
token is read-only and may not create or approve pull requests, and the repository has no Actions
secrets: no workflow reads one.

## Releases

A release is cut by the maintainer:

1. Add the release note under `releases/` in a `docs(release): add <x.y.z> notes` commit, in the
   format described in [releases/README.md](releases/README.md). It comes first.
2. Review the whole release locally against [docs/review-checklist.md](docs/review-checklist.md):
   every file of `git diff origin/main...origin/staging`, after `git fetch origin`. Fix what it
   finds through pull requests into `staging` first.
3. Merge `staging` into `main` with a merge commit, through a pull request.
4. Tag the merge commit on `main` as `v<x.y.z>`.

The tag starts the release workflow. It checks that the note exists and that its `version` matches
the tag, then publishes `countersign-skills-<v>.tar.gz`, its `.sha256` and `catalog.json`.

## Working with an AI agent

Claude Code reads [CLAUDE.md](CLAUDE.md). Codex reads the same instructions through `AGENTS.md`, a
symlink to `CLAUDE.md`. The rules are the same for both agents.

## House rules

The short version is in [CLAUDE.md](CLAUDE.md); in full:

- Zero comments in shell scripts, workflows and Markdown: no `#` comment lines in `.sh`, no
  `<!-- -->`. Names carry the meaning. Rationale that would have been a comment goes into `docs/`.
  The one exception is a pinned action's `# vX.Y.Z` suffix, which dependabot reads.
- POSIX `sh` with `set -eu`, working with both BSD and GNU tools, macOS first. Match the style of
  `install.sh`, `lib.sh` and `test.sh`.
- Skill conventions, enforced by `./test.sh`:
  - the folder name equals the frontmatter `name`;
  - the `description` line is at most 200 bytes;
  - every skill without `disable-model-invocation: true` has a `when_to_use`;
  - the last line of every `SKILL.md` is exactly
    ``If `local.md` exists next to this file, read it; where it disagrees with this file, it wins.``;
  - every skill is listed in `skills.tsv` and every rule in `rules.tsv`;
  - every file in `agents/` sets `model` and lists its preloaded skills as a YAML list.
- Run the trigger evals before changing a skill's `description` or `when_to_use`, and after. See
  [docs/evals.md](docs/evals.md).
- Bump a skill's version in `skills.tsv` with every change to that skill, so `update.sh` can say
  what moved.
- Regenerate `catalog.json` with `scripts/catalog.sh` after changing a skill, a rule, an agent,
  `skills.tsv` or `rules.tsv`. `./test.sh` fails while it is stale. The contract is in
  [docs/catalog.md](docs/catalog.md).
- The only `# shellcheck` directive is `# shellcheck source=lib.sh`, on the line before each
  `. "$root/lib.sh"`: it lets shellcheck follow the shared file, so a variable `lib.sh` sets isn't
  reported as unassigned. Two exceptions are set outside the code:
  - `.shellcheckrc` disables SC1007, because `test.sh` runs commands as
    `CLAUDE_CONFIG_DIR= ./install.sh`, which deliberately sets the variable to empty for one
    command.
  - `scripts/lint.sh` checks `lib.sh` with `-e SC2034`, because `lib.sh` defines paths that only the
    scripts sourcing it use, which shellcheck cannot see when it checks `lib.sh` alone. Shellcheck
    doesn't report problems inside a sourced file, so `lib.sh` gets this check of its own.
- One task per commit, as a Conventional Commit.

Everyone taking part follows the [Code of Conduct](CODE_OF_CONDUCT.md). Report security issues
privately, as [SECURITY.md](SECURITY.md) describes.
