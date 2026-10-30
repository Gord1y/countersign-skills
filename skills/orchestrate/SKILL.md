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

## The division of labour

| Role | Who | Does |
| --- | --- | --- |
| Plan | you, the main session | research, split, sequence, write every brief, put every open decision to the user |
| Build | one subagent per unit, own worktree | one unit, edited and gated, never committed, reported |
| Integrate | you | review the worktree's diff, land it, commit it with the unit's message, gate the composed branch once |

**You never touch repo source**: no `src/`, no tests, no config the builders own. Briefs, plans,
run state, commit messages and integration fixes are yours. A one-line fix found mid-run is still a
builder's job: fold it into a pending brief or queue it as a unit. The exception is a failure the
integration itself creates (an overlap you port by hand, a hook failure on your commit).

## Repo facts

Look each one up in the repo's CLAUDE.md (or AGENTS.md) and the files it imports or points to,
reading only this skill's section of a repo-facts file (`sed -n '/^## orchestrate$/,/^## /p'`),
then in `local.md` next to this file. If neither has it, take the default and suggest the one line
to add to CLAUDE.md.

| Fact | Default |
| --- | --- |
| When a run ends with a walkthrough: `always`, `when UI changed` or `off` | `always` |
| The surfaces the product has, and how to reach each | `qa-tester`'s Repo facts |

---

## Step 1: gather facts, cheaply

Fewer than about 3 lookups in files you know: read them yourself. Otherwise spawn `researcher`
(`agents/researcher.md`, `haiku`, effort `low`) for search, or a read-only `general-purpose` agent
with `sonnet` and effort `medium` for judgement across many files. Always pass `model` and
`effort`, and ask for at most 30 lines back: paths with line ranges and the facts, never file
contents. Where no `researcher` agent is installed, use `Explore` with `haiku` and `low`.

## Step 2: one plan file, every question in it, then one approval

**Nothing spawns before every question in the plan file has an answer, and after that you never
ask the user again during the run.**

Research (Step 1) finishes before the first question. Then do a **decision sweep**: walk every
decision the task and each unit's implementation will hit. Sort each as **load-bearing** (changes
a contract, behaviour the user would notice or a recorded decision, or is expensive to undo) or
**reversible** (naming, placement, wording, a cheap edge case).

Write one plan file, `~/.claude/plans/<repo>-<run>.md`, holding:

- the goal, in two lines
- each unit, as the commit message it will produce
- what depends on what, so what is parallel and what is sequenced; units that touch the same file
  are sequenced
- each unit's model and effort, and why
- the pilot unit (Step 6), when there are 4 or more
- the facts you are handing down
- the surfaces the batch checks (Step 8) and Step 9 will QA, or why the run skips QA and which
  check replaces it
- every reversible call, with its default
- what the run pre-authorizes: dependencies to add, files to delete, any command the user would
  otherwise be asked about
- every load-bearing decision, as a question with its options, your recommendation and an
  `Answer:` line
- an empty `## Waiting for you` section

Give the user the file's path, then ask the same questions through the forms (AskUserQuestion), at
most four at a time and the highest-leverage first, and write each answer back to its `Answer:`
line. A change the user did not ask for that alters behaviour they would notice, or reverts or
rewrites earlier work, is load-bearing however cheap it is to undo, and gets its own question.
Fixes for defects found along the way stay automatic. The last batch ends with one question that
lists every reversible call with its default: "OK with these?". After each batch, drop what the
answers settled and ask the next. A run with a run folder
(4 or more units) keeps this file as the folder's `plan.md`.

During the run, a load-bearing question that turns up goes under `## Waiting for you`, with its
options and recommendation; only the units it touches park (see "When a builder parks or fails").

Resuming an approved plan or a handoff needs no re-approval. Splitting new work does.

### Plan in one session, execute in others

- **The planning session** does Step 1 and Step 2 at effort `high`, or `xhigh` for a hard design.
  It ends when the plan is approved: hand off through `context-transfer`, pointing at the plan
  file. A run of 3 units or fewer may go on in the same session.
- **An execution session** starts from the plan file and only briefs, lands, commits and runs QA.
  It never re-opens an answered question.
- **At most 10 landed units, or about 300K tokens of context, per execution session, whichever
  comes first.** The session knows its size from a Countersign context note or the status line.
  When neither shows it, count units. Then update the run folder and hand off
  through `context-transfer`. A PR ends when its work is done, not at a unit count: unfinished
  work goes on in the same branch and PR in the next session.
- **Work bigger than one PR**, or past about twelve questions, becomes phases: one index plan,
  `~/.claude/plans/<repo>-<programme>/index.md`, lists them, and each phase is one PR with its own
  run folder (`references/run-folder.md`).

### When a Countersign context note arrives

A message that opens "Context note from Countersign, the user's approval app" gives this session's
context size and what the user chose for it.

- **Compact after this step:** finish the unit in hand, bring the run folder up to date (unit
  statuses, landed SHAs, open questions), then list what the summary must keep. The run folder is
  what survives the compaction.
- **Hand off, or the stop:** brief nothing new and spawn nothing. Let builders already running hand
  back, land what is ready, and leave the rest in its worktree. Never remove, reset or force a
  worktree, branch or uncommitted change for the handoff: the next session picks them up. Record
  each unit's status, worktree path and branch in the run folder, then hand off through
  `context-transfer`.
- **Any other context note** is answered at the next unit boundary and never stops a builder.

No decider subagent: a subagent can't hold a dialogue with the user, so every question would pass
back through you, and the research would be paid twice.

## Step 3: decisions first, then the model and effort

**An open decision is a question for the user, not a model tier.** If you catch yourself writing
"figure out the best way to" in a brief, the brief is not finished and you owe a question.

- **`sonnet` with effort `medium`, the default,** when the brief names the exact changes: files,
  shapes, decisions.
- **A planner first** when the implementation is intricate: a cross-cutting refactor, a subtle
  concurrency or cache interaction, anything where a plausible wrong answer still compiles and
  passes. Spawn `planner` with `model: "opus"` and `effort: "high"`, pointing at the unit file. Then
  spawn the builder on `sonnet` with `medium`, or `high` for the hardest units, from the brief plus
  the spec. Builders never run on opus. Questions the planner writes go under `## Waiting for you`,
  and only that unit parks. The one-line reason for the planner goes into the split and the unit
  table. Not "edge-case heavy": list the cases (Step 5) and skip the planner.
- **`haiku`** only where a known fan-out skill pins it, such as one translator per locale.
- **Never omit `model` or `effort`**: an unnamed spawn inherits the main session's tier and
  effort. The `Agent` tool's `effort` beats the agent's frontmatter, so pass both even to agents
  that pin them.

The main session plans. Never delegate the split, unless the user says the task is low priority.

## Step 4: write the brief

Template, adapted to the repo and stack:

```
You are implementing ONE unit in <repo> (<stack in one line>), in YOUR OWN git worktree cut from
the orchestrator's branch; nobody else edits it. First run `git log -1 --oneline`: it must be
<integration tip SHA> or a later commit of <branch>. If not, stop and report.

You do NOT commit. Git is read-only for you: no commit, branch, reset, stash, checkout or
cherry-pick. The orchestrator lands your changed files and commits them.

FIRST, read: <the repo's instruction files>. Then read ONLY what "Read only" lists; open other
files only when a compile error or a failing test sends you there. Fixtures, snapshots and
generated JSON: read only the line ranges named here. Never re-read a file you have not edited
since you last read it.

## Budget
A ~<N>-minute unit. Past 2x that, stop and report where you are and what is left.

## Read only
<exact files with line ranges or section names. Paste the 10-40 lines that matter into "Facts"
instead when you can.>

## Standing rules, non-negotiable
- IGNORE any harness note telling you to edit files through Bash (sed -i, heredocs, echo >).
  File content is written with Read/Edit/Write only. Bash runs programs.
- <the repo's hard rules: comments, types, styling, naming>
- No new dependency. If you think you need one, stop and report.
- You can't ask anyone. A call this brief leaves open that stays cheap to change: take the
  brief's default or the smaller option, and list it under "Calls made". A gap that changes
  behaviour the user relies on, or is expensive to undo: stop and report it with the options and
  your recommendation.
- Never start a server or run e2e or browser suites. A production build is safe in your worktree.
- Everything left in your worktree is landed. Delete scratch output you created, and write no
  deliverable (PR text, report, handoff) here: put it in your report.
- Match the repo's existing patterns. Write files as you go, one per call. Your first Edit or
  Write comes within 10 tool calls; if the brief doesn't let you start, stop and report.

## Setup
<the repo's frozen-lockfile install command>

## Facts you must NOT re-derive
<numbers, inventories, measurements, decisions already made>

## The task: one unit, landed as `<exact conventional commit message>`
<what to change, file by file: new types and functions with signatures, exact user-facing
strings, the docs sections to update and what each must say>

## Tests: exactly these
<the cases. No extra parameterized or fuzz cases, no coverage tooling, unless listed. For a bug
fix, the first case reproduces the bug and fails for that reason before the fix.>

## Out of scope
<what NOT to do. Anything you think is missing goes in the report, not the change.>

## Before handing back
Iterate with <build command> and <single-suite test command> only. The full gate (<the repo's
gates>) runs exactly ONCE, last. If it fails, fix the cause and run it once more.

## Hand-back
At most 20 lines, no emoji: the worktree path (`pwd`), `git status --short`, `full gate runs: N`,
every user-facing string verbatim, "Calls made", and any gap that stopped you. Count the lines
before you hand back; past 20, cut the least useful until it fits.
```

## Step 5: hand down facts, keep builders fast

- **Paste, don't point.** Measurements, inventories, baselines, decisions: into the brief. Paste
  signatures and the 10-40 lines that matter; read those files yourself first. For a fixture or a
  generated file, paste the shape the unit needs, or name the exact line range; never the whole
  file.
- **Name the shape.** Every new type and function with its signature, every user-facing string
  verbatim.
- **Fence the scope.** List test cases exactly and write "Out of scope". "Handle odd shapes" or
  "be defensive" with no list is open-ended by construction.
- **Set a budget**, about 20-30 minutes for a `sonnet` unit. Over 45 honest minutes: split it.
- **One full gate per unit.** Name the fast-loop commands; more than 1 reported gate run is
  flagged in the unit table.
- **Settle review points up front.** Check the brief against what you will check at hand-back: a
  non-obvious constant's reason in the docs, every factual claim in user-facing text, overlap with
  a unit in flight. Each one caught later is a full round trip.
- **No two-phase units.** Sequence a unit after its dependency instead.

## Step 6: spawn

- **Check the agent types once, before the first spawn.** Read the list of agent types the Agent
  tool offers. When `builder` is on it, every unit spawns as `subagent_type: "builder"`
  (`agents/builder.md`), which carries `isolation: worktree`, and always with `model` and
  `effort`. Never cut worktrees by hand with `git worktree add`, let builders commit, or
  cherry-pick their work: that bypasses Step 8. Only when `builder` is missing (a skills-only
  install), spawn `general-purpose` with `isolation: "worktree"` and the same `model` and `effort`;
  the brief's standing rules already forbid committing and asking. Note which path the run uses
  in the plan file. Check `planner`, `reviewer` and `qa` the same way for Steps 3, 7 and 9. Where
  `planner` is missing, write the spec yourself in the main session: an `opus` `general-purpose`
  spawn would re-read everything this session already holds.
- The worktree is cut from your `HEAD` only under `worktree.baseRef: "head"`, which the install
  sets; without it, worktrees start from the remote default branch. Check the worktree, not the
  settings file: right after the first spawn, `git worktree list` must show the new worktree at
  your `HEAD`. If it does not, stop that builder and park the run until the user adds the setting.
- **Spawn with a pointer.** In a run folder the prompt is one line: "Your brief is `<absolute path
  to units/NN-<slug>.md>`. Read it first; it is the whole task." Without a folder, paste the brief.
- **At most 4 writing builders in flight**, a parallel batch in one message. A unit that touches a
  file another unit changes waits until that one is landed, so its worktree is cut from a `HEAD`
  that already has it.
- **Pilot first** with 4 or more units: spawn the first ready unit, verify its hand-back, fold what
  it got wrong into the pending briefs, then fan out. Skip it for 3 or fewer, near-identical units,
  or a resume past a clean first hand-back.
- **Watch the budget.** Each time you are re-invoked, compare each builder's elapsed time with its
  budget. Past twice the budget, stop it with `TaskStop`. A message through `SendMessage` does not
  stop a running agent. Then note why and re-brief a smaller unit.
- Research agents don't count against the cap. Only known fan-out skills nest subagents.

## Step 7: verify the hand-back

```bash
git -C <worktree> log -1 --oneline    # the base: a commit on the working branch
git -C <worktree> status --short      # exactly the unit's files, nothing stray
git -C <worktree> diff                # read it before landing, not after
```

`git diff` does not show new files: read each `??` file from the status whole, since
`land-worktree` lands it too. A builder's claims about repo state are unverified until checked.

Every unit over about 300 changed lines, new files included, gets a `reviewer` before it lands;
size it from `git -C <worktree> diff --stat` plus the `??` files. Spawn `reviewer`
(`agents/reviewer.md`) with `model: "sonnet"` and `effort: "high"`, the worktree path and the
brief's path. Read its findings and `git -C <worktree> diff --stat` instead of the whole diff, and
open only the files a finding names. Where no `reviewer` agent is installed, spawn
`general-purpose` with `sonnet` and `high`, and tell it to change nothing and to review with the
`thorough-diff-review` skill.

## Step 8: land, commit, then gate once

Per unit, from the top of the checkout that has the working branch out (the main checkout, or the
worktree this session works in), with `land-worktree` from this skill's `scripts/` folder:

```bash
cd <the working branch checkout's top folder>
"${CLAUDE_SKILL_DIR}/scripts/land-worktree" <worktree>   # copies its changes here and stages them
git commit -m "<the unit's commit message>"
remove-worktree <worktree>
```

Run every landing from that checkout, and `remove-worktree` as a Bash call of its own, with no
`cd`, `;`, `&&`, pipe or redirect: chained or piped it runs inside the sandbox, which cannot
write `.git/worktrees`. `land-worktree` records what it landed, so a commit hook
that reformats the files does not keep the worktree alive. `remove-worktree` runs outside the
sandbox, refuses a worktree whose changes no checkout of the repo has committed, a locked one and
one outside `.claude/worktrees/`, and removes the rest instantly (renamed into the repo's trash,
pruned, its `worktree-agent-*` branch deleted, the files deleted in the background). When it
prints `kept`, leave that worktree for Step 10 and never force it. On a
skills-only install with no `remove-worktree` on PATH, run the skill's `scripts/remove-worktree`,
which runs inside the sandbox and can fail on write-protected paths.

`land-worktree` copies nothing and exits 1 when:

- **a file changed on this branch since the worktree was cut**: the unit overlapped a landed one.
  Port its diff by hand with Edit (integration work), or respawn it on the new `HEAD`. After
  committing a hand-port, run `"${CLAUDE_SKILL_DIR}/scripts/land-worktree" --ported <worktree>`,
  which records the landing, then `remove-worktree <worktree>` as usual.
- **the worktree is not on this branch**: the builder committed. Port the diff by hand.
- **a file is uncommitted in this checkout**: commit or set aside your own edits first; never
  discard the user's.
- **a file is on a path the sandbox write-protects**: the `.claude` settings files, `.claude/hooks/`,
  `skills/`, `agents/` or `commands/`, `.mcp.json`, `.vscode/` or `.idea/`. Port each with Edit,
  which asks the user, then run `land-worktree` again: it skips and stages files that already
  match.

The commit runs the repo's hooks in the main checkout. If a hook fails, fix the cause and commit
again; never `--no-verify`. Remove a worktree only after its commit exists, and never one whose
landing failed: it is the only copy.

**QA every landed batch that touches a surface**, with or without a dev server, before the next
batch spawns. Spawn `qa` with `model: "sonnet"` and `effort: "medium"`, scoped to that batch: its
units, the surfaces they touched, their cases, and `writeups/changes/<date>-<run>/qa/<NN>-batch/`
as the evidence folder, with no walkthrough. Unit tests mock the network, so a backend limit or an
error only the running app raises passes every gate; when a dev server serves this checkout, an
unchecked batch is already in front of the user. A FAIL becomes a fix unit before the next batch.
A case that needs a server nobody runs is BLOCKED, never passed. A batch no surface can observe
(docs, CI, a refactor with no behaviour change) skips QA, and its row says so.

Write each verdict where a compaction can't lose it: PASS, FAIL or BLOCKED per case, with the
`results.md` path, under `## QA` in each unit's file and in its row in `orchestrator.md`. Without a
run folder, put them in the plan file.

After every unit is landed, run the full gate **once** on the composed branch. Anything needing a
running app is verified by the batch checks and Step 9, never in a builder's worktree.

## Step 9: QA the run, then leave a walkthrough

Once the gate is green, prove the composed run works in the running product. The batches were
checked one by one in Step 8; this pass covers what they could not. Its folder is
`writeups/changes/<date>-<run>/`, resolved from the main checkout as `qa-tester` resolves it.

1. **QA and the walkthrough, in one spawn.** Spawn `qa` (`agents/qa.md`) with `model: "sonnet"`
   and `effort: "medium"`. Its prompt gives what changed, unit by unit; the surfaces each touched;
   the batch verdicts and their `results.md` paths; the cases to run now (those that cross
   batches, every case still BLOCKED, and one smoke pass per touched surface); the run name; the
   folder; and whether to write the walkthrough, as the Repo fact says: `always`, `when UI changed`
   (a web, native, mobile or game surface changed), or `off`. It preloads `qa-tester` and
   `walkthrough`, so screenshots and logs stay in its context and only its report reaches yours. It
   exercises the main checkout, which the user's servers serve. A check that starts a server, such
   as serving a worktree, is yours: `qa` never starts or stops one, and a subagent's shell returns
   to the main checkout on every call.
2. **Fix what it finds.** All FAIL cases go into one fix unit with their repros, on the normal path
   (brief, builder, land, commit, gate). Then a second `qa` spawn re-runs those cases and updates
   the walkthrough. A case that still fails goes to the closing summary as ❌. A BLOCKED case (a
   server down, a missing tool) is never a pass: it goes to the summary with what unblocks it.
   Record these verdicts as Step 8 does.

Where no `qa` agent is installed, invoke `qa-tester` with the same scope (it runs forked), then
`walkthrough`.

**A surface you can't launch** (a native app when the sandbox blocks `open`, a device you don't
have) is never skipped silently. QA every surface you can reach. For that one, the closing summary
lists the exact checks for the user, each with what to look for, and its cases count as BLOCKED,
never passed.

**The one skip.** A small fix the user can check at a glance (a copy change, a one-line config)
skips the batch checks and this step. The closing summary then names the exact check: the page,
request or command, and what to look for. A run no surface can observe (a refactor with no behaviour change, CI, docs) has
nothing to QA; the summary says so.

## Step 10: close the run

- **Only your own builders' worktrees.** A worktree this session did not spawn is never yours to
  clear, unless the user names it.
- If the repo documents a guarded cleanup command, use it (dry run first), and relay every line
  about something it kept.
- Never unlock or remove a locked worktree: the harness holds the lock while a builder runs.
- Run `remove-worktree <path>...`, alone in its Bash call, for each of your builders' worktrees
  still present, and relay every `kept` line with its reason. Removing what it removes needs no
  question.
- For a kept worktree give the user only `remove-worktree <path>` to run once its work is landed,
  never `rm -rf`. Mention that `remove-worktree --landed` sweeps every landed builder worktree,
  clean detached scratch worktree and folder of ignored output, from any session, and that the
  install's `SessionEnd` hook runs that sweep when a session ends.
- Refresh the PR description. When the branch has a PR, or the run's folder already holds a
  `pr.md`, rewrite that `pr.md` draft with `feature-pr-description` over the whole branch,
  including this run's commits. Find the PR with `gh pr view --json number,title`, run as a command
  of its own. Do not edit the PR on GitHub. The closing summary gives the user one ready block of
  exact commands: `git push`, then `gh pr edit <N> --title "<title>" --body-file <path>`, or
  `gh pr create …` when no PR exists. When the user asks to push, push and edit the PR together.
- Never push unprompted.

---

## When the user adds work mid-run

It joins the run as a unit, never a side job in the main session. Read `references/added-work.md`
before you brief it.

## When a builder parks or fails

Read `references/exceptions.md`: a parked unit, a failed one and one whose tooling alone was
blocked take different paths, and you never finish a unit's edits yourself.

## Run folder, for series of 4 or more

Runs of 4 or more units keep their state in a folder outside the repo, so a compaction or a
resume costs one small file read. Read `references/run-folder.md` before the first spawn of such a
run. Shorter runs live in context and need no folder. Phased work keeps one run folder per phase
under an index plan, described in the same file.

## Reporting

One or two lines in the terminal as each unit lands. One closing summary at the end, in the
session's summary convention. It lists every builder's "Calls made", every parked unit with its
question, the QA verdict with each FAIL and BLOCKED case, and the commands only the user can run.
It ends with the path of the walkthrough (of the QA report when the walkthrough is off), or with
the check the user should do when QA was skipped. Never an artifact page, unless asked.

## Anti-patterns

- Writing the code yourself because it is faster.
- Deciding a load-bearing question quietly, or asking mid-run.
- Builders sharing the main working tree, or committing in their worktrees.
- Spawning without an approved split, or without `model` and `effort`.
- Trusting a builder's account of repo state instead of its base and diff.
- Letting a builder measure what you already know.
- Spawning a parallel batch one message at a time.
- Open-ended briefs with no case list and no budget.
- Messaging an over-budget builder instead of stopping it.
- Amend loops: bundle every hand-back finding into one follow-up.
- An opus builder: plan on opus, build on sonnet.

If `local.md` exists next to this file, read it; where it disagrees with this file, it wins.
