---
name: orchestrate
description: "Run work of 3+ independently verifiable commits as an orchestrator: split into units, brief one builder per unit in its own worktree, land and commit each unit, gate once."
when_to_use: "Use for a task of three or more independently verifiable commits, or on request at any size."
---

# Orchestrate

You brief, review, verify, land and commit. You do not write the code.

Builders sharing one working tree break each other's gates, and a main session that writes code
stops reviewing. So each builder edits in its own worktree and never commits; you land its files
on the working branch and commit them. The evidence behind each rule is in
`references/rationale.md`.

---

## When this engages

**3 or more independently verifiable commits.** Count units that can each be proven green on
their own, not files touched. Below that, there is no orchestrator and no worktrees: do the work
yourself. The no-writing rule is a property of orchestrator mode, not a standing ban. It also
engages on request, at any size, or on `/orchestrate`.

## Repo facts

Look each one up in the repo's CLAUDE.md (or AGENTS.md) and the files it imports or points to,
reading only this skill's section of a repo-facts file (`sed -n '/^## orchestrate$/,/^## /p'`),
then in `local.md` next to this file. If neither has it, take the default and suggest the one line
to add to CLAUDE.md.

| Fact | Default |
| --- | --- |
| When a run ends with a walkthrough: `always`, `when UI changed` or `off` | `always` |
| The surfaces the product has, and how to reach each | `qa-tester`'s Repo facts |

## The steps

Steps 1 and 2, research and the approved plan: `references/planning.md`. Steps 3 to 10, builders
to close: `references/orchestrator-mode.md`.

## Reporting

One or two lines in the terminal as each unit lands. One closing summary at the end, in the
session's summary convention. It reads the decision log: each `parked` row is a ❓, each
`deviation` a ⚠️, and the `call` rows are one line with the file's path. It also lists every
builder's "Calls made", the QA verdict with each FAIL and BLOCKED case, and the commands only the
user can run. It ends with the path of the walkthrough (of the QA report when the walkthrough is
off), or with the check the user should do when QA was skipped. Never an artifact page, unless
asked.

If `local.md` exists next to this file, read it; where it disagrees with this file, it wins.
