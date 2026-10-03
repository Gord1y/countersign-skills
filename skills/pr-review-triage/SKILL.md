---
name: pr-review-triage
description: "Triage a PR's review: fetch the Claude review, human comments and open threads, verify each finding at the PR head, find what it missed, write a fix plan."
when_to_use: "Use when the message is a bare PR link, or when asked to triage or answer a PR's review."
context: fork
---

# PR review triage

A message that is only a PR link means: run the steps below and stop at the plan. This skill only
reads the PR. It never pushes, comments, resolves a thread, re-requests a review or edits the PR
body; the person does all of that on GitHub.

A link to one comment (`#discussion_r…`, `#issuecomment-…`, `#pullrequestreview-…`) narrows the
run to that thread. Everything else stays the same.

Under Claude Code this skill runs forked: you see this file and its arguments (the PR number or
link), not the conversation that called you. You never wait on an answer: questions go into the
triage file and your reply (step 5).

## Repo facts

This skill needs the facts below. Look each one up in the repo's CLAUDE.md (or AGENTS.md) and
the files it imports or points to, then in `local.md` next to this file. If neither has it, report
it as missing, with the one line to add to CLAUDE.md so the next run finds it.

| Fact | Example |
| --- | --- |
| The review workflow, and who posts the formal review and the tracking comment | `.github/workflows/claude-review.yml`; the formal review by `github-actions`, the tracking comment by `claude` |
| The severity scale, and what is never reported | `docs/review-checklist.md` section 0: Blocker, Major, Minor, Nit |
| How to serve the PR head for a browser pass | its own worktree on `:3001`, as `CONTRIBUTING.md` describes |
| Git commands the repo denies, so the person lands fixes themselves | `merge`, `reset` and `branch -f` are denied; they run `git merge --ff-only <branch>` |
| Where uncommitted drafts go | a gitignored `writeups/` folder in the main checkout |

Read the review workflow and the reviewer identities from `.github/workflows` (grep for
`claude-code-action`) and from the PR's own reviews before reporting one missing.

## 1. Gather

Take `<owner>` and `<name>` from `gh repo view --json owner,name`.

```bash
gh pr view <N> --json number,title,state,baseRefName,headRefName,headRefOid,reviewDecision,body,url
gh pr view <N> --json reviews --jq '.reviews[] | {author: .author.login, state, submittedAt, commit: .commit.oid}'
gh pr view <N> --json comments --jq '.comments[] | {author: .author.login, createdAt, body}'
gh api graphql -f query='query { repository(owner:"<owner>", name:"<name>") { pullRequest(number:<N>) { reviewThreads(first:100) { nodes { isResolved isOutdated path line comments(first:20) { nodes { author { login } body } } } } } } }'
```

Claude speaks on a PR in two places (Repo facts):

- **The formal review**, posted by the review workflow. Its body is the source of truth: the
  verdict, the severity table, findings with `file:line`, missing tests and nits. On a re-review it
  may also carry a reconciliation of prior findings. Take the newest one.
- **The tracking comment**, from the same run or from a manual re-request. It summarises the formal
  review. Read it only for anything the review body lacks.

Unresolved inline threads count; resolved ones do not. Note `isOutdated`. Human reviews and
comments are findings too.

Compare the formal review's `commit` with `headRefOid`. If the review predates the head, name the
commits it has not seen. Some findings may already be fixed (verdict _stale_), and the unseen
commits have had no review at all, so step 3 covers them.

If `gh api` needs approval, the GraphQL call is still required: unresolved threads are exactly what
the review body leaves out.

## 2. List every finding

One row per claim. Keep the reviewer's severity from the repo's severity scale (Repo facts):
Blocker, Major, Minor or Nit. Each "Missing tests" bullet gets its own row, because a claim that a
test is missing needs checking like any other claim. Split a bullet that makes two claims.

## 3. Look for what the review missed

Run the `thorough-diff-review` skill over `origin/<base>...<head>` (or `gh pr diff <N>`).

For a PR that changes layout, sizing, stickiness, scrolling or focus, a real-browser pass is part
of this step, not an extra. jsdom cannot see a 16px misalignment, a scrolled `overflow: hidden`
ancestor, or focus that never moves, and all three reach review unflagged. Serve the PR head for a
browser pass as the repo does (Repo facts) and drive it with the Playwright MCP. The `qa-tester`
skill's sign-in and evidence rules apply, with `reviews/pr-<N>/qa/` in the drafts folder as the
evidence folder.

## 4. Verify each finding

Work in a detached worktree at the PR head, never in the person's checkout:

```bash
git worktree add --detach .claude/worktrees/pr-<N> <headRefOid>
```

If the head commit is not local, `git fetch origin pull/<N>/head` needs the gh credential helper.
`gh pr diff <N>` and `gh api repos/{owner}/{repo}/contents/<path>?ref=<sha>` work without it.

For every row:

1. **Read the cited code at the head,** plus whatever could disprove the claim: callers, and the
   prop or value the claim says drives the behaviour. A claim can be disproved by reading what
   actually drives the behaviour.
2. **Check the reviewer's own evidence.** "The existing tests only cover X" is a claim too, so grep
   the tests: half of a missing-test claim can be wrong.
3. **Reproduce** anything behavioural: a failing test, the typecheck, or a browser measurement
   before and after. To prove a CSS fix before planning it, override the style in the page and
   measure again.
4. **Check it against what was decided:** the PR body, the repo's feature docs, the plan for that
   work in `~/.claude/plans/`, commit messages, and project memory. A finding that goes against a
   recorded decision is _intended_; cite the decision.
5. **Give it one verdict:**

| Verdict        | Means                                                              |
| -------------- | ------------------------------------------------------------------ |
| Real           | Reproduced, or read to be wrong today                              |
| Real, latent   | Right today, wrong after a plausible future edit                   |
| Not a defect   | The path exists, but its output is well defined and right; say why |
| False positive | The claim's mechanism is wrong; cite the line that disproves it    |
| Intended       | Matches a recorded decision; cite it                               |
| Stale          | Fixed by a commit the review did not see                           |
| Out of scope   | Real, but it belongs to another PR or team                         |

While you are at it, re-grade severity against the repo's severity scale (Repo facts): a defensive
gap is a Nit at most, and prose is capped at a Nit.

## 5. Plan, then stop

Write `reviews/pr-<N>/triage.md` in the drafts folder, resolved from the main checkout so that a
worktree cleanup cannot delete it, never anywhere it could be committed:

```bash
WRITEUPS="$(dirname "$(git rev-parse --path-format=absolute --git-common-dir)")/writeups"
TRIAGE="$WRITEUPS/reviews/pr-<N>/triage.md"
```

It has these sections:

1. **Sources:** each review (author, state, commit, and whether it is on the head), plus comments
   and threads.
2. **Verdicts:** one row per finding, with its severity, the claim, the verdict and the evidence
   (`file:line`, a test name or a measurement).
3. **Missed findings:** the same columns.
4. **Fix plan:**
   - one Conventional Commit per concern, and the branch the commits land on;
   - the gates and browser checks that prove each commit;
   - whether the work needs builders (`orchestrate` from three source commits up);
   - how the commits reach the PR branch while the person's checkout holds it: the git commands the
     repo denies (Repo facts) are the ones the person runs themselves.
5. **No change:** each finding left alone, with the reason.
6. **Decisions check:** one line saying no fix contradicts a recorded decision, or naming the one
   that does.
7. **Questions:** a fix that is a new behaviour decision rather than a repair goes here as a
   question, not in the plan.

Stop the server you started for the PR head (only that one, never one serving the person's
checkout), close the browser, and remove the worktree unless the fixes will reuse it. Reply with
the triage file's path, the verdict counts and the questions; the caller puts the questions to the
person. Nobody starts fixing until they approve the plan.

## Related

- `thorough-diff-review`: the local review pass in step 3
- `qa-tester`: sign-in and evidence rules for the browser pass, and the evidence folder's naming
- `feature-pr-description`: when a fix changes something the PR body claims, the person edits the
  body

If `local.md` exists next to this file, read it; where it disagrees with this file, it wins.
