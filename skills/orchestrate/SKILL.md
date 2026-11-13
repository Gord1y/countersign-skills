---
name: orchestrate
description: "Route every task to one playbook (feature, bug-fix, refactor, investigation, prototype, UI change, release, PR triage, knowledge, unattended run); at 3+ commits, brief builders."
when_to_use: "Use for every task that changes, investigates or ships code: a feature, a bug, a refactor, how or why code works, a spike, a UI change, a release, a PR link or its findings, a knowledge-graph update, an unattended run. Not for a question answered without the repo."
---

# Orchestrate

Every task starts here: pick one playbook, copy its steps into the todo list, work through them.

In orchestrator mode you brief, review, verify, land and commit, and you do not write the code.
Builders sharing one working tree break each other's gates, and a main session that writes code
stops reviewing. So each builder edits in its own worktree and never commits; you land its files
on the working branch and commit them. The evidence behind each rule is in
`references/rationale.md`.

---

## When this engages

Every task that changes, investigates or ships code. A question answered without the repo needs
no playbook. Orchestrator mode engages at 3 or more independently verifiable units where the
`builder` agent is installed; otherwise build each slice yourself, one commit each. Count units
that can each be proven green on their own, not files touched. It also engages on request, at any
size, or on `/orchestrate`.

**Under Codex** there is no `builder` agent, so you are the builder, and every unit gets a worktree
so the scope fence holds. Per unit: `plan-lint fence` as Step 6 says, then `git worktree add -b
worktree-agent-codex-<NN> .claude/worktrees/agent-codex-<NN> HEAD`, edit only by absolute path
inside it, run `gate` there. From the main checkout run `land-worktree --files <brief> <worktree>`,
commit, then `remove-worktree` by bare name. The scripts are in
`~/.agents/skills/orchestrate/scripts/`. Codex-written code is reviewed on Claude: under T3 Code,
`delegate_task` with provider `claudeAgent`, `claude-sonnet-5-5`, effort `high` and role
`agents/conformance.md`; without T3, the user runs that review.

## Step 0: route

1. The first output line is `Goal: <one sentence, your words>. Playbook: <name>.`
2. The first matching row wins.
3. Copy `playbooks/<name>.md` into the todo list (TodoWrite, or Codex's plan tool).
4. Two rows with different steps: attended, ask once and recommend one; unattended, take the
   first and log a `call` row.

| Playbook | Signals |
| --- | --- |
| `autonomous-run` | started unattended: a scheduled or delegated thread, a task marked ready for an agent, "run it without me" |
| `pr-triage` | a bare PR link, review findings or failing checks on a PR |
| `release` | cut, prepare or ship a release; a release note; a promotion or hotfix PR |
| `investigation` | how, why, is it safe, what breaks, about this code or system; ends in a report |
| `prototype` | a spike, a proof of concept, "try whether"; throwaway |
| `knowledge-update` | refresh or bootstrap the knowledge graph, a glossary entry, an ADR |
| `bug-fix` | something fails that should work: an error, a regression, a failing test or check |
| `refactoring` | structure changes, behaviour stays: rename, extract, move, migrate callers, delete dead code |
| `ui-change` | the point is what a user sees: layout, styling, copy, a component, a screen |
| `feature` | new or extended behaviour; the default |

## The shared steps

Each playbook names these steps in this order and adds its own delta.

- **restate**: Step 0's line.
- **research**: `references/planning.md` Step 1; read `docs/knowledge/index.md` first and put its
  path in every spawn.
- **grill**: every open question at once, each with options and a recommended answer.
- **slice**: vertical, prefactor first, expand then contract, blockers first, at most 400 lines
  each, stacked PRs past one.
- **approve**: `plan-lint check`, the user's yes, `plan-lint approve`, and no question after it.
  One slice with no load-bearing question skips the plan.
- **build**: per When this engages; fence each batch (`references/orchestrator-mode.md` Step 6).
- **knowledge**: `repo-knowledge` "Update and lint" for touched paths, before prove so the gate
  covers it; `skip: no docs/knowledge/index.md`.
- **prove**: `gate` passes; a fix lands with a test that failed first; `qa` or `qa-tester` per
  surface; a UI diff gets a `walkthrough`.
- **review**: `conformance` per the orchestration rule's routing table; an unplanned file keeps
  the PR in draft.
- **pr**: `feature-pr-description` writes `pr.md`; give the push commands, never push.
- **clickup**: `skip: no ClickUp task` until a task id is known, and `skip: no clickup agent` when no
  `clickup` agent is installed; that agent comes from a profile, not from these skills.
- **retro**: `retro` after a user correction, a failed gate, a revert or a parked unit, else
  `skip: clean run`.

A skipped step stays in the todo list as `skip: <reason>`. The closing report counts steps done
and skipped.

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
to close: `references/orchestrator-mode.md`. Read the second in orchestrator mode, and under Codex.

## Reporting

One or two lines in the terminal as each unit lands. One closing summary at the end, in the
session's summary convention. It reads the decision log: each `parked` row is a ❓, each
`deviation` a ⚠️, and the `call` rows are one line with the file's path. It also lists every
agent's "Calls made", the QA verdict with each FAIL and BLOCKED case, and the commands only the
user can run. It ends with the path of the walkthrough (of the QA report when the walkthrough is
off), or with the check the user should do when QA was skipped. Never an artifact page, unless
asked.

If `local.md` exists next to this file, read it; where it disagrees with this file, it wins.
