# The approved plan is the contract

Read this at Step 2, before you write the plan, and at Step 8, before you land.

The plan the user approves binds the run. Builders do what its slices say. Anything it does not
say is a deviation: the unit stops, and the user decides in the next planning session.

## A slice

One slice is one unit and one commit. The heading carries the commit message, and the block runs
to the next line that starts with `#`, `##` or `###`.

```
### Slice 01: feat(auth): add the login form
- Scope: `src/auth/**`, `**/*.test.ts`
- Sensitive: `package.json`: adds zod, Q1
- Acceptance: a wrong password shows the error under the field
- Evidence: `pnpm test auth` passes
- Out of scope: password reset
```

- The heading is `### Slice NN: <commit message>`. NN is two digits and unique in the plan.
- Field lines start at column 0 and may repeat. `Acceptance:`, `Evidence:` and `Out of scope:`
  each need text. A slice needs all three.
- `Scope:` lists the paths the slice may change, as backticked globs.
- `Sensitive:` names a sensitive path the slice must change: backticked globs, then the reason.
  It widens the slice's scope by those globs.
- Globs are repo-relative. `*` and `?` stay inside one path segment. `**` is a whole segment and
  matches any depth. Refused: a leading `/`, a `..` segment, `[ ] { } \` and a trailing `/`.
- Every brief's `Files:` line (Step 4) lists paths inside its slice's globs. The approval does
  not cover the brief: `land-worktree` reads `Files:` at landing time, so the list is only as
  trusted as the plans folder, and a builder could edit its brief.

## Sensitive surfaces

A slice that changes one of these needs a `Sensitive:` line for it, even when its `Scope:`
globs already match:

- dependencies: package manifests and lockfiles
- migrations
- API contracts: OpenAPI, GraphQL and Prisma schemas
- environment and config: `.env*`, `*.config.*`, `settings.json`
- CI workflows (`.github/workflows/`) and rulesets
- i18n source keys: the source locale catalog

## Check, approve, verify

`scripts/plan-lint` takes the plan's path.

- `plan-lint check <plan>`: run it before the first question and after each edit. It lists every
  structural problem and exits 1.
- `plan-lint approve <plan>`: run it on the user's yes to the final approval question. It checks
  the plan, refuses an empty `Answer:` line, and appends `Approved: <sha256> <date>` as the
  last line.
- `plan-lint verify <plan>`: run it before each landing. It exits 0 only when the plan is
  unchanged since its approval.

An answer is `Answer:` plus the decision text. `approve` refuses an `Answer:` line, in the forms
`Answer:`, `- Answer:`, `**Answer:**` and `> Answer:`, whose text is empty or starts with
`(pending`.

The hash covers the plan without its `Approved:` line, which is a line of the form
`Approved: <64 hex digits> <date>`. Any other line that starts with `Approved:` is plan text.

Any later edit voids the approval: show the user the change and approve again. Never edit an
approved plan to make a landing pass.

## The decision log

`decisions.tsv` in the run folder, else `~/.claude/plans/<repo>-<run>.decisions.tsv`. The header
is `date`, `unit`, `kind`, `what`, `why`, separated by tabs. Only the orchestrator writes rows,
with Edit, as each thing happens. No tab or newline inside a cell.

- `parked`: a load-bearing gap stops a slice, such as a question from a builder or planner, a
  second failure or a `Files:` refusal. `what` holds the question, its options and your
  recommendation.
- `call`: a hand-back lists a "Calls made" item. One row per item.
- `deviation`: you did what the plan did not say, such as correcting a `Files:` line, porting by
  hand or skipping QA. `what` holds what you did.

The closing summary reads this file: each `parked` row is a ❓, each `deviation` a ⚠️, and the
`call` rows are one line with the file's path.
