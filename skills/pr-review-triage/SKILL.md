---
name: pr-review-triage
description: "Triage a PR: collect AI review findings, failed CI checks and open human threads, verify each at the PR head, and write a fix plan that proves every fix safe."
when_to_use: "Use when the message is a bare PR link, or when asked to triage a PR's review findings or failing checks."
context: fork
---

# PR review triage

A message that is only a PR link means: run the steps below and stop at the plan. This skill
verifies what others found. It runs no review of its own unless the request asks for one in words
("review it again", "find what it missed"); then `thorough-diff-review` over
`origin/<base>...<head>` adds its findings as one more source. It only reads the PR: it never
pushes, comments, resolves a thread, re-runs a check or edits the PR body.

A link to one comment (`#discussion_r…`, `#issuecomment-…`, `#pullrequestreview-…`) narrows the
run to that thread. Everything else stays the same.

Under Claude Code this skill runs forked: you see this file and its arguments (the PR number or
link), not the conversation that called you. You never wait on an answer: questions go into the
plan file (step 5).

## Repo facts

This skill needs the facts below. Look each one up in the repo's CLAUDE.md (or AGENTS.md) and
the files it imports or points to, then in `local.md` next to this file. If neither has it, report
it as missing, with the one line to add to CLAUDE.md so the next run finds it.

| Fact | Example |
| --- | --- |
| The review workflow, and who posts the formal review and the tracking comment | `.github/workflows/claude-review.yml`; the formal review by `github-actions`, the tracking comment by `claude` |
| The severity scale, and what is never reported | `docs/review-checklist.md` section 0: Blocker, Major, Minor, Nit |
| The gates, and the command behind each CI job | `pnpm lint` and `pnpm test`; the `ci` job runs `pnpm lint` |
| Git commands the repo denies, so the person lands fixes themselves | `merge`, `reset` and `branch -f` are denied; they run `git merge --ff-only <branch>` |

Read the review workflow and the reviewer identities from `.github/workflows` (grep for
`claude-code-action`) and from the PR's own reviews before reporting one missing.

## 1. Gather

Take `<owner>` and `<name>` from `gh repo view --json owner,name`. Run each `gh` call as a command
of its own.

```bash
gh pr view <N> --json number,title,state,baseRefName,headRefName,headRefOid,body,url
gh pr view <N> --json reviews --jq '.reviews[] | {author: .author.login, state, submittedAt, commit: .commit.oid}'
gh pr view <N> --json comments --jq '.comments[] | {author: .author.login, createdAt, body}'
gh api graphql -f query='query { repository(owner:"<owner>", name:"<name>") { pullRequest(number:<N>) { reviewThreads(first:100) { nodes { isResolved isOutdated path line comments(first:20) { nodes { author { login } body } } } } } } }'
gh pr checks <N> --json name,state,bucket,link,workflow
gh pr checks <N> --required --json name,bucket
```

Three sources, each labelled in the plan:

- **AI.** The formal review from the review workflow is the source of truth: verdict, severity
  table, findings with `file:line`, missing tests and nits. Take the newest. The tracking comment
  summarises it; read it only for what the body lacks. Any other bot reviewer and every
  unresolved bot thread count too.
- **CI.** Every check whose `bucket` is `fail`. For each, `gh run view <run-id> --log-failed`
  (the run id is in `link`). A long log comes back as a saved file: grep it for the first error.
- **Human.** Unresolved threads and review comments by people. Resolved threads do not count.
  Note `isOutdated`.

Compare the newest review's `commit` with `headRefOid`. If the review predates the head, name the
commits it has not seen: some findings may be fixed already (verdict _Stale_).

## 2. List every item

One row per claim. Keep the reviewer's severity from the repo's scale (Repo facts). A failing
required check is a Blocker; any other failing check is Major. Each "Missing tests" bullet gets its
own row, because a claim that a test is missing needs checking like any other. Split a bullet that
makes two claims.

## 3. Verify each item at the PR head

Read code at the head without a checkout: `git show <headRefOid>:<path>`. If the commit is not
local, `git fetch origin pull/<N>/head` needs the gh credential helper; `gh pr diff <N>` and
`gh api repos/{owner}/{repo}/contents/<path>?ref=<sha>` work without it. To run anything, use the
person's checkout when it is clean and at `headRefOid`, else a detached worktree:

```bash
git worktree add --detach .claude/worktrees/pr-<N> <headRefOid>
```

If the sandbox refuses it (a tracked path it write-protects), run that command alone outside it.

Run the repo's gates once at the head first and record each result. That baseline lets the fix
run tell its own breakage from what was already red.

For every row:

1. **Read the cited code,** plus whatever could disprove the claim: callers, and the value the
   claim says drives the behaviour.
2. **Check the reviewer's own evidence.** "The tests only cover X" is a claim too: grep the tests.
3. **Reproduce** anything behavioural: a failing test, the typecheck, or the CI job's own command.
   A failed check that reproduces at the head is run again at the base: red there too means
   _Pre-existing_.
4. **Check it against what was decided:** the PR body, the repo's feature docs, the plan for that
   work in `~/.claude/plans/`, commit messages, and project memory. A finding that goes against a
   recorded decision is _Intended_; cite the decision.
5. **Give it one verdict:**

| Verdict | Means |
| --- | --- |
| Real | Reproduced, or read to be wrong today |
| Real, latent | Right today, wrong after a plausible future edit |
| Not a defect | The path exists, but its output is well defined and right; say why |
| False positive | The claim's mechanism is wrong; cite the line that disproves it |
| Intended | Matches a recorded decision; cite it |
| Stale | Fixed by a commit the review did not see |
| Out of scope | Real, but it belongs to another PR or team |
| Pre-existing | A failed check that fails on the base too |
| Flaky | A failed check that does not reproduce, with an infra cause in its log; cite the line |
| Config | A failed check caused by the workflow or the ruleset, not the code |

Re-grade severity against the repo's scale: a defensive gap is a Nit at most, and prose is capped
at a Nit.

## 4. Prove each fix safe

Every _Real_ row, and every _Real, latent_ row worth fixing, gets these before it enters the plan:

1. **The fix:** the files, and the change in a sentence.
2. **Blast radius:** every caller, consumer and import of what changes, found by grep, and the
   tests that already cover it.
3. **The premise:** the one fact the fix is safe because of ("no caller passes `null`", "only the
   landing reads this key"), and the read or command that proved it, as `impact-check` does.
4. **The regression test:** its file, its case and what it asserts. The fix run writes it first
   and watches it fail for the finding's reason.
5. **The gates** that prove the commit, compared against the baseline.

A fix that changes a contract, a behaviour the user would notice or a recorded decision is a
question, not a plan line.

## 5. Write the plan, then stop

Write `~/.claude/plans/<repo>-pr-<N>.md`, where `<repo>` is the main checkout's folder name. It
has these sections:

1. **Sources:** each review (author, state, commit, and whether it is on the head), each failed
   check, and the open threads.
2. **Findings:** one row per item: source and author, severity, the claim, the verdict and the
   evidence (`file:line`, a test name, a log line or a measurement).
3. **Baseline:** each gate's result at the head.
4. **Fix plan:** one Conventional Commit per concern, each with step 4's five parts. Then the
   branch the commits land on; whether the work needs builders (`orchestrate` from three source
   commits up); and how the commits reach the PR branch while the person's checkout holds it. The
   git commands the repo denies (Repo facts) are the ones the person runs.
5. **No change:** each item left alone, with its verdict and the reason.
6. **Questions:** each with its options, your recommendation and an `Answer:` line.

Remove the worktree unless the fixes will reuse it. Reply with the plan's path, the count per
verdict and the questions; the caller puts the questions to the person. Nobody starts fixing until
they approve the plan.

## Related

- `impact-check`: the premise method in step 4
- `thorough-diff-review`: only when the request asks for a fresh review
- `feature-pr-description`: when a fix changes something the PR body claims, the person edits the
  body

If `local.md` exists next to this file, read it; where it disagrees with this file, it wins.
