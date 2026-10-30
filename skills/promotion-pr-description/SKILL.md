---
name: promotion-pr-description
description: "Write a release or hotfix PR body (into staging or main) from its release note, rendered for GitHub."
when_to_use: "Use when asked to write, draft or update the description of a release, promotion or hotfix PR: a release branch into staging, staging into main, or a hotfix branch into either."
effort: medium
---

# Release PR description

A release PR's body is the release note, made readable on GitHub. The note is the one record of
what ships, so the body never rewrites it.

## Repo facts

This skill needs the facts below. Look each one up in the repo's CLAUDE.md (or AGENTS.md) and
the files it imports or points to (of a repo-facts file, only this skill's section:
`sed -n '/^## promotion-pr-description$/,/^## /p' <file>`), then in `local.md` next to this file. If neither has it, ask
the user once, then suggest the one line to add to CLAUDE.md so the next run finds it.

| Fact | Example |
| --- | --- |
| Promotion contract for `staging` into `main` (a doc the body must follow, if any) | `releases/PROMOTION.MD` |
| Branch flow | feature → `release-x.y.z` → `staging` → `main` |
| Title convention for release PRs | `release: <semver>`, or `release: <v1>, <v2>` for a batch |
| Where release notes live | `releases/release-<semver>.md`, contract in `releases/README.md` |
| Does the repo tag releases? | no tags; the version lives in `package.json` and the branch name |
| Where uncommitted drafts go | a gitignored `writeups/` folder in the main checkout |
| Hotfix flow: branch, target, title, and which note gets the entry | before promotion `release-<semver>-hotfix` into `staging`, titled `release: <semver> hotfix`; after it `release-<semver>-hotfix-<n>` into `main`, then a PR from `main` into `staging`; the entry goes in that version's note |

## The two release PRs

|                 | release branch → `staging`                       | `staging` → `main`                                       |
| --------------- | ------------------------------------------------ | -------------------------------------------------------- |
| Ships           | one version                                      | every version sitting in `staging`                       |
| Body            | that version's note, rendered                    | the promotion contract, or one section per version       |
| Reader wants    | what this release contains and what is still open | what reaches production since the last promotion        |

## 1. Bound the range

The most common error is describing work that already shipped. Find the previous promotion's
merge time and let it cut the list:

```bash
gh pr list --state all --base main --limit 10 --json number,title,headRefName,mergedAt,url
gh pr list --state all --base staging --limit 20 --json number,title,headRefName,mergedAt,url
```

A branch merged into `staging` before the previous promotion is already in production; say so when
it still shows there. If the repo does not tag releases, bound the range with the place Repo facts
says the version lives, not a tag.

## 2. Bring the note up to date first

The body copies the note, so a stale note makes a stale PR. Run the `release-notes` check: every
commit the branch holds that the PR's target lacks has an entry or a reason it has none.

```bash
git fetch origin
git log --oneline origin/<target>..HEAD
```

Fix the note in its own commit before writing the body. An entry that reads wrong in the PR is wrong
in the note: change the note, never only the PR.

## 3. Render the note (release branch → `staging`)

- The note's `title` as the first heading, `## <title>`.
- Its `summary` as the first paragraph, and its `highlights`, if any, as a list under it.
- Then its body sections, word for word, in the note's order. Leave out a section whose only entry
  is `- None.`.
- Leave out the fields only tooling reads: `version`, `date`, `type`, `tags`, visibility flags,
  compatibility lists. A `breaking: true` becomes the first line under the title: what breaks.
- Never paste the frontmatter itself. In a PR body GitHub reads the YAML lines and the closing
  `---` as one setext heading, so the top of the PR becomes a wall of bold YAML.

## 4. `staging` → `main`

Read the promotion contract first: its structure and style win over this section. Lead each
version's part with that version's note `summary`, link to the note, and add only what the note may
not say: the renamed constant, the CI job removed, the guard that was tripped. Pull the real diff
(`git show --stat <sha>`, then `git show <sha>`) for any line that names something specific. Without
a contract, write a table of the release PRs being promoted, then one section per version.

## 5. A hotfix PR

A hotfix fixes a version that has already left its release branch: before promotion it goes into
`staging`, after promotion into `main`. Repo facts says how it branches, where it goes and how it
is titled. The body is built the same way for both:

- **Range:** only the hotfix branch's commits, `git log --oneline origin/<target>..HEAD`. The rest
  of the version shipped in an earlier PR.
- **Note first:** the fix gets its entry in the note Repo facts names before the body is written.
  It is `Fixed` only when the bug reached a released version. A bug that never left `staging`
  changes the entry of the work it broke, or gets none.
- **Body:** `## <title>`, then one paragraph: what was broken and for whom, and what the fix
  changes. Then the note entries this hotfix added or changed, word for word, and nothing else
  from the note.

## 6. Where it goes

Write the body to `releases/<version>/promotion-staging.md` (a release into `staging`),
`releases/<version>/promotion-main.md` (`staging` into `main`) or
`releases/<version>/<hotfix branch>.md` (a hotfix) in the drafts location; a batch uses its newest
version's folder. Resolve it in the main checkout, never in a worktree, whose copy is deleted with
it:

```bash
WRITEUPS="$(dirname "$(git rev-parse --path-format=absolute --git-common-dir)")/writeups"
PR_BODY="$WRITEUPS/releases/<version>/<promotion-staging, promotion-main or the hotfix branch>.md"
```

`gh pr create --body-file` never applies the repo's pull request template, so the body carries it:
copy the template's fixed blocks (a heading with content under it, a table, a footer after a `---`
rule) verbatim and in place, as
[`feature-pr-description`](../feature-pr-description/SKILL.md#4-carry-the-repos-pr-template)
describes. A footer such as a list of review commands ends the body, exactly as the template has
it.

Opening or editing the PR is a separate, visible action that needs the user's go-ahead each time:

```bash
gh pr create --base <target> --head <branch> --title "<title convention>" --body-file "$PR_BODY"
gh pr edit <N> --body-file "$PR_BODY"
```

Never push to the target branch directly.

## Before handing it over

- The body opens with the note's title and summary, not YAML; a hotfix body opens with what was
  broken.
- Each rendered section or entry matches the note's word for word.
- Every fixed block of the repo's pull request template is in the body, word for word.
- The title follows the title convention.

## Related

- [`release-notes`](../release-notes/SKILL.md): writes and checks the note this body renders
- [`feature-pr-description`](../feature-pr-description/SKILL.md): a feature or fix PR into a
  release branch

If `local.md` exists next to this file, read it; where it disagrees with this file, it wins.
