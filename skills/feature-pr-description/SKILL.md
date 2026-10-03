---
name: feature-pr-description
description: "Write the body of a feature or fix PR from the branch's real diff, following the repo's PR contract."
when_to_use: "Use when asked to write, draft or update a PR description."
effort: medium
---

# Feature PR description

## Repo facts

This skill needs the facts below. Look each one up in the repo's CLAUDE.md (or AGENTS.md) and
the files it imports or points to, then in `local.md` next to this file. If neither has it, ask
the user once, then suggest the one line to add to CLAUDE.md so the next run finds it.

| Fact | Example |
| --- | --- |
| PR description contract (a doc the description must follow, if any) | `docs/pr-description.md` |
| Branch flow and the default base branch for a feature PR | feature → `release-<semver>` → `staging` → `main`; a feature targets the open `release-<semver>` branch |
| Paths whose change widens a PR's blast radius (for example middleware, auth, shared UI) | `src/lib/`, `src/middleware.ts`, CI config, lint and test config, `package.json` |
| Where uncommitted drafts go | a gitignored `writeups/` folder in the main checkout |
| Allowed PR title types | `feat`, `fix`, `refactor`, `chore`, `docs`, `ci`, with `release` reserved for promotion merges |
| Release index command, if any | `scripts/release-index.sh` |

The contract doc, when the repo has one, owns the shape, the section rules, the tone and the list of
things that must not appear. This skill is the workflow around it: how to gather the material the
contract asks for, and where the result goes. If the two ever disagree, the doc wins.

## 1. Establish the range

A description covers a branch, not a working tree.

```bash
git log --oneline <base>..HEAD          # base is the PR's target branch
git diff --stat <base>...HEAD
gh pr view <N> --json title,body,baseRefName,headRefName   # when a PR already exists
```

Use the three-dot form for the diff so the base's own commits stay out of it. If no PR exists yet,
target the base the branch flow from Repo facts names for a feature PR. Ask rather than assume when
the branch name does not make it obvious.

## 2. Read the diff, not the commit messages

Commit subjects are what you intended; the diff is what shipped. Every claim in the description has
to come from one of:

- a hunk you read,
- a test that pins the behaviour,
- a command you ran and whose output you saw.

The contract's highest-value section is **where you deviated from the obvious approach**, and that
is never in a commit subject. Look for it deliberately: a shared primitive you touched, a wire
payload you changed, a route you renamed, a default you flipped, a second design you rejected. If a
commit was a follow-up fixing an earlier commit on the same branch, describe the end state, never
the detour.

## 3. Find the blast radius yourself

Anything under the blast-radius paths from Repo facts reaches past the feature. Name the other
consumers and say why they stay inert. Search the source folder for every use of what changed,
excluding the files the branch already touches:

```bash
grep -rn "<ChangedComponent" <source-folder> | grep -v "$(git diff --name-only <base>...HEAD | tr '\n' '|')"
```

When the branch adds or renames translation keys, name them, and check every locale that consumes
them. A reviewer who discovers a shared change you did not mention reads the rest of the document
with less trust.

## 4. Write it to a file

Write the body to `changes/<date>-<branch>/pr.md` in the uncommitted drafts location from Repo
facts: `<date>` is today as `YYYY-MM-DD`, `<branch>` the branch name with `/` written as `-`. When
the branch already has a folder under `changes/` (a QA run or a walkthrough made it), write into
that one instead. Resolve the location from the **main checkout**, never from a worktree: a
gitignored folder inside a worktree is deleted along with the worktree. For a `writeups/` folder in
the main checkout, this resolves to the right folder from the main checkout and from any worktree
alike:

```bash
WRITEUPS="$(dirname "$(git rev-parse --path-format=absolute --git-common-dir)")/writeups"
PR_BODY="$WRITEUPS/changes/<date>-<branch>/pr.md"
```

Do not open or edit a PR as part of writing the description. Pushing a branch, creating a PR, and
editing a PR body are visible actions that need the user's explicit go-ahead each time. When they
give it:

```bash
gh pr create --base <base> --head <branch> --title "<type>: <subject>" --body-file "$PR_BODY"
gh pr edit <N> --body-file "$PR_BODY"
```

Use only the allowed PR title types from Repo facts.

## 5. Check it against the contract before handing it over

Walk the contract's "Do not include" list and delete anything that crept in: a verification or
testing section, a locales section, a recap of what a backend now sends, a commit list, a
file-by-file tour, a screenshot gallery, a restatement of the ticket.

Then check that the title and body describe this repo's change only: no other repo by name, no
machine path, no private infrastructure. That context goes in the uncommitted drafts. Anything
another repo needs goes to the maintainer as a private brief, `briefs/<date>-<topic>.md` in the
drafts location, never into the PR.

Then check the headings. Each one has to be a claim a reviewer could disagree with. `Contract
changes`, `Improvements`, `Testing` and `Other` are labels, not claims: rewrite them into the
sentence the section actually argues, or fold the section into a neighbour.

Last, read the opening two paragraphs alone. A reader who stops there should know what merged and
why it was needed. If they only learn that "several improvements" landed, the description has not
started yet.

## Related

- [`promotion-pr-description`](../promotion-pr-description/SKILL.md): release branch → staging and
  staging → main PRs
- [`release-notes`](../release-notes/SKILL.md): the release record a release branch carries, and
  the release index command from Repo facts that regenerates its index
- [`thorough-diff-review`](../thorough-diff-review/SKILL.md): review the diff before describing it

If `local.md` exists next to this file, read it; where it disagrees with this file, it wins.
