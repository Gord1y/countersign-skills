---
name: promotion-pr-description
description: "Write a release or hotfix PR body (into staging or main) from its release note, plus what developers need before and after the merge."
when_to_use: "Use when asked to write, draft or update the description of a release, promotion or hotfix PR: a release branch into staging, staging into main, or a hotfix branch into either."
effort: medium
---

# Release PR description

A release PR's body is the release note, made readable on GitHub, followed by what only developers
need. The note is the one record of what ships, so the body never rewrites it.

## Repo facts

This skill needs the facts below. Look each one up in the repo's CLAUDE.md (or AGENTS.md) and
the files it imports or points to, then in `local.md` next to this file. If neither has it, ask
the user once, then suggest the one line to add to CLAUDE.md so the next run finds it.

| Fact | Example |
| --- | --- |
| Promotion contract for `staging` into `main` (a doc the body must follow, if any) | `releases/PROMOTION.MD` |
| Branch flow | feature → `release-x.y.z` → `staging` → `main` |
| Title convention for release PRs | `release: <semver>`, or `release: <v1>, <v2>` for a batch |
| Where release notes live | `releases/release-<semver>.md`, contract in `releases/README.md` |
| Does the repo tag releases? | no tags; the version lives in `package.json` and the branch name |
| CI checks that run only on release PRs | an e2e suite and a coverage run on PRs into `staging` and `main` |
| Branch protection and merge method on the target branch | `staging` squash only, `main` merge commits only |
| Where uncommitted drafts go | a gitignored `writeups/` folder in the main checkout |
| Hotfix flow: branch, target, title, and which note gets the entry | before promotion `release-<semver>-hotfix` into `staging`, titled `release: <semver> hotfix`; after it `release-<semver>-hotfix-<n>` into `main`, then a PR from `main` into `staging`; the entry goes in that version's note |

## The two release PRs

|                 | release branch → `staging`                       | `staging` → `main`                                       |
| --------------- | ------------------------------------------------ | -------------------------------------------------------- |
| Ships           | one version                                      | every version sitting in `staging`                       |
| Body            | that version's note, rendered, then the tail     | the promotion contract, or one section per version       |
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
  compatibility lists. A `breaking: true` goes into the tail as its first line, with what breaks.
- Never paste the frontmatter itself. In a PR body GitHub reads the YAML lines and the closing
  `---` as one setext heading, so the top of the PR becomes a wall of bold YAML.

## 4. Add the developer tail

Under `## Before and after merging`, only the parts that hold, each a short list:

- **Before merging:** the gates still to pass, such as the release-only CI checks from Repo facts,
  trigger evals after a skill's description changed, or the local review the repo asks for. Write
  them as `- [ ]` items.
- **After merging:** what a person must do: a setting, a secret or an environment variable to set,
  a tag to push, a follow-up left on purpose.
- **Already live:** what changed outside the diff while the branch was built, such as repository
  settings, rulesets or secrets, so a reviewer doesn't look for it in the files.
- **Size:** commits, changed files, additions and deletions from
  `gh pr view <N> --json additions,deletions,changedFiles,commits`, next to the previous
  promotion's, so the number means something.
- **How it was checked:** the gates run at the branch head and what they cover. Verification
  belongs here and never in the note.

The tail is for developers, so it may name files, commands and settings. It says what holds and
what to do, never the story behind the work: not what prompted the release, nor what went wrong or
needed a second try while it was built. It still describes only this repo: no other repository by
name or path, no machine path, no developer name. Anything another repository needs goes to the
maintainer as a private brief, `briefs/<date>-<topic>.md` in the drafts location, never into the PR.

## 5. `staging` → `main`

Read the promotion contract first: its structure and style win over this section. Lead each
version's part with that version's note `summary`, link to the note, and add only what the note may
not say: the renamed constant, the CI job removed, the guard that was tripped. Pull the real diff
(`git show --stat <sha>`, then `git show <sha>`) for any line that names something specific. Without
a contract, write a table of the release PRs being promoted, then one section per version, then the
developer tail.

## 6. A hotfix PR

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
- **Tail:** as in step 4. A hotfix into `main` adds under After merging what brings the other
  branches level, such as a PR from `main` into `staging`, and the tag if the repo tags releases.

## 7. Where it goes

Write the body to `releases/<version>/promotion-staging.md` (a release into `staging`),
`releases/<version>/promotion-main.md` (`staging` into `main`) or
`releases/<version>/<hotfix branch>.md` (a hotfix) in the drafts location; a batch uses its newest
version's folder. Resolve it in the main checkout, never in a worktree, whose copy is deleted with
it:

```bash
WRITEUPS="$(dirname "$(git rev-parse --path-format=absolute --git-common-dir)")/writeups"
PR_BODY="$WRITEUPS/releases/<version>/<promotion-staging, promotion-main or the hotfix branch>.md"
```

Opening or editing the PR is a separate, visible action that needs the user's go-ahead each time:

```bash
gh pr create --base <target> --head <branch> --title "<title convention>" --body-file "$PR_BODY"
gh pr edit <N> --body-file "$PR_BODY"
```

Never push to the target branch directly. When the target squash-merges, the PR body is the only
record of the release's commits on that branch: say so in the tail.

## Before handing it over

- The body opens with the note's title and summary, not YAML; a hotfix body opens with what was
  broken.
- Each rendered section or entry matches the note's word for word.
- The title follows the title convention, and the tail holds only what is true and still useful.

## Related

- [`release-notes`](../release-notes/SKILL.md): writes and checks the note this body renders
- [`feature-pr-description`](../feature-pr-description/SKILL.md): a feature or fix PR into a
  release branch

If `local.md` exists next to this file, read it; where it disagrees with this file, it wins.
