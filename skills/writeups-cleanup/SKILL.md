---
name: writeups-cleanup
description: Propose what in a repo's writeups/ folder can go (merged and released changes, superseded releases, scratch) and delete only what the user approves. Run with /writeups-cleanup.
disable-model-invocation: true
---

# Writeups cleanup

`writeups/` collects every draft the skills write: PR bodies, QA evidence, walkthroughs, release
drafts, briefs, review triage. It is gitignored, so nothing removes it, and a deletion cannot be
undone. This skill finds what has done its job, proposes it with the evidence, and deletes only
the paths the user approves.

## Repo facts

This skill needs the facts below. Look each one up in the repo's CLAUDE.md (or AGENTS.md) and
the files it imports or points to, then in `local.md` next to this file. If neither has it, ask
the user once, then suggest the one line to add to CLAUDE.md so the next run finds it.

| Fact | Example |
| --- | --- |
| Where drafts go | a gitignored `writeups/` folder in the main checkout |
| The ref that holds what has been released | `origin/main`, which moves only at releases |
| How releases are tagged | `v<semver>` tags; or no tags, and the release notes index lists each version |

## The layout and its rules

```
writeups/
  changes/<date>-<branch-or-run>/   pr.md, walkthrough.md, shots/, qa/
  releases/<version>/               promotion-staging.md, promotion-main.md, walkthrough.html, shots/
  briefs/<date>-<topic>.md          asks for other repos or teams
  reviews/pr-<n>/                   triage.md, qa/
  scratch/                          delete any time
```

| Entry | Proposed for deletion when |
| --- | --- |
| `changes/<x>/` | its PR is merged and the merge commit is in the released ref |
| `releases/<version>/` | a later version has shipped |
| `reviews/pr-<n>/` | the PR is merged or closed |
| `scratch/` | always |
| `briefs/<file>` | never by rule: listed with its age, for the user to judge |
| anything outside the layout | never by rule: listed as "outside the layout", with the place it would move to when its name makes that clear |

## Step 1: inventory, read-only

Resolve the folder from the main checkout, and work only inside it:

```bash
WRITEUPS="$(dirname "$(git rev-parse --path-format=absolute --git-common-dir)")/writeups"
find "$WRITEUPS" -mindepth 1 -maxdepth 2 -exec du -sh {} +
```

Gather the evidence in as few calls as possible:

```bash
git fetch origin --tags
gh pr list --state all --limit 300 --json number,headRefName,state,mergedAt,mergeCommit
git tag --list 'v*' --sort=-v:refname
```

Match each `changes/<date>-<x>/` to a PR by its head branch, written with `/` as `-`. A merge
commit counts as released when `git merge-base --is-ancestor <merge commit> <released ref>`
succeeds. A folder with no matching PR (a run on the default branch, a renamed branch) is listed
with "no PR found" and never proposed.

## Step 2: one proposal

One table, nothing deleted yet:

```
| Path | Size | Last changed | Evidence | Proposal |
| --- | --- | --- | --- | --- |
| changes/2026-09-12-feat-invoices/ | 4.1 MB | 2026-09-14 | PR #312 merged 2026-09-15, in origin/main | delete |
| releases/1.2.0/ | 9.8 MB | 2026-09-02 | v1.3.0 shipped | delete |
| changes/2026-09-30-fix-totals/ | 0.3 MB | 2026-09-30 | PR #331 open | keep |
| briefs/2026-08-20-backend-totals.md | 4 KB | 2026-08-20 | 44 days old | your call |
```

Then the total the proposed deletions free. State plainly that `writeups/` is gitignored, so a
deleted path is gone for good.

## Step 3: delete only on a yes

Ask once: delete everything proposed, pick paths, or nothing; and the same for each "your call"
row the user wants gone. A path the user did not approve stays, whatever the rules say.

Delete exactly the approved paths, each named in full, never a glob:

```bash
rm -rf -- "$WRITEUPS/changes/2026-09-12-feat-invoices"
```

Then report each deleted path and the space freed, and anything that failed. Never touch anything
outside `writeups/`, never an entry whose PR is open, and never move a file without the same yes.

If `local.md` exists next to this file, read it; where it disagrees with this file, it wins.
