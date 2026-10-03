---
name: promotion-pr-description
description: Write the body of a promotion PR (a release branch into staging, or staging into main) following the repo's promotion contract.
disable-model-invocation: true
effort: medium
---

# Promotion PR description

## Repo facts

This skill needs the facts below. Look each one up in the repo's CLAUDE.md (or AGENTS.md) and
the files it imports or points to, then in `local.md` next to this file. If neither has it, ask
the user once, then suggest the one line to add to CLAUDE.md so the next run finds it.

| Fact | Example |
| --- | --- |
| Promotion PR contract (a doc the description must follow, if any) | `docs/promotion-prs.md` |
| Branch flow | feature → `release-x.y.z` → `staging` → `main` |
| Title convention for promotion PRs | `release: <semver>`, or `release: <v1>, <v2>` for a batch |
| Does the repo tag releases? | no tags; the version lives in `package.json` and the branch name |
| CI checks that run only on promotion PRs | an e2e suite and a coverage run on PRs into `staging` and `main` |
| Branch protection on the target branch | `staging` and `main` are protected |
| Where uncommitted drafts go | a gitignored `writeups/` folder in the main checkout |

## Read the contract first

If the repo has a promotion PR contract, read it before anything else: it holds the gathering
recipe, the exact structure and the style rules. This skill adds what a contract usually leaves
open: which promotion you are describing, how to bound it, and where the draft goes. If the two
disagree, the contract wins. Follow its sections as written; a common shape is a table of the PRs
being promoted, then the items grouped by release.

## The two promotions are not the same document

|                 | release branch → `staging`                        | `staging` → `main`                                                 |
| --------------- | ------------------------------------------------- | ------------------------------------------------------------------ |
| Ships           | one version being assembled                       | every version sitting in staging                                   |
| Reader wants    | what this release contains and what is still open | what reaches production, and how it compares to the last promotion |
| Constituents    | feature PRs merged into the release branch        | release PRs merged into staging                                    |
| Reviewed before | mostly yes, on each feature PR                    | yes, twice                                                         |

A contract is usually written for the `staging` → `main` case. For a release branch → `staging`,
keep its structure but read one level down: the constituent PRs are the feature and fix branches
merged into the release branch, and the previous boundary is the last PR from that same release
branch, if it had one. Use the title convention from Repo facts; if it reserves a title type for
promotion merges, nothing else in the repo may use that type.

## Bound the range before summarising anything

The single most common error is describing work that already shipped. Find the previous promotion's
merge timestamp and let it cut the list:

```bash
gh pr list --state all --base main --limit 10 --json number,title,headRefName,mergedAt,url
gh pr list --state all --base staging --limit 20 --json number,title,headRefName,mergedAt,url
```

A branch merged into `staging` **before** the previous promotion is already in production; say so
explicitly if it is still visibly sitting there, for example a hotfix promoted on its own. Take
stats from
`gh pr view <N> --json baseRefOid,headRefOid,additions,deletions,changedFiles,commits` rather than
computing them locally, and quote the previous promotion's size next to this one so the number
means something. If the repo does not tag releases, do not go looking for a tag to bound the range
with: use the place Repo facts says the version lives.

## Go deeper than the release notes

This document is developer-only. Cross-check it against the repo's release record (see
[`release-notes`](../release-notes/SKILL.md)) so the two do not contradict each other, then say the
things a release note may not: the constant that was renamed, the guard that was tripped, the CI
job that was removed, the bug that existed since inception and was never exercised.

Pull the real diff (`git show --stat <sha>`, then `git show <sha>`) for any bullet that names
something specific. Do not paraphrase a commit message that claims a rename or a new file without
opening it.

## Operational notes earn their section

The last section of the structure is where a promotion pays for itself. Put in it what the next
person needs and would otherwise rediscover: a gate that must pass before merging, a generated
artifact nothing consumes yet, a repo setting a human must change after the merge, a follow-up
deliberately left.

The title and body describe only this repo: no other repository by name or path, no defect or ask
for another service, no edge configuration, no developer name or machine path. Anything another
repository needs goes to the maintainer as a private brief, `briefs/<date>-<topic>.md` in the
place Repo facts gives for uncommitted drafts, never into the PR.

## Where it goes

Write the body to `releases/<version>/promotion-staging.md` (a release into `staging`) or
`releases/<version>/promotion-main.md` (`staging` into `main`), in the place Repo facts gives for
uncommitted drafts; a batch uses its newest version's folder. Resolve it in the main checkout,
never in a worktree: with a gitignored `writeups/` folder it never lands in a commit, and a copy
inside `.claude/worktrees/<name>/writeups/` is deleted with the worktree. From the main checkout or
any worktree:

```bash
WRITEUPS="$(dirname "$(git rev-parse --path-format=absolute --git-common-dir)")/writeups"
PR_BODY="$WRITEUPS/releases/<version>/promotion-<staging or main>.md"
```

Creating or editing the PR is a separate, visible action that needs the user's explicit go-ahead
(`gh pr edit <N> --body-file "$PR_BODY"`).

Confirm before opening a promotion PR that does not exist yet, and never push to the target branch
directly; its protection is whatever Repo facts says, no more. A promotion PR is where the heavier
CI can land: say which of the promotion-only checks from Repo facts ran and their result, and
expect a longer, noisier check list than on a feature PR.

If `local.md` exists next to this file, read it; where it disagrees with this file, it wins.
