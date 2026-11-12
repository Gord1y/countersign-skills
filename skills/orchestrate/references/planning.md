# Planning: Steps 1 and 2

Read this at a playbook's plan step.

## Step 1: gather facts, cheaply

Fewer than about 3 lookups in files you know: read them yourself. Otherwise spawn `researcher`
(`agents/researcher.md`, `haiku`, effort `low`) for search, and do judgement across many files
yourself, by range. Always pass `model` and `effort`, and ask for at most 30 lines back: paths
with line ranges and the facts, never file contents. Where no `researcher` agent is installed,
use `Explore` with `haiku` and `low`.

## Step 2: one plan file, every question in it, then one approval

**Nothing spawns before every question in the plan file has an answer, and after that you never
ask the user again during the run.**

Research (Step 1) finishes before the first question. Then do a **decision sweep**: walk every
decision the task and each unit's implementation will hit. Sort each as **load-bearing** (changes
a contract, behaviour the user would notice or a recorded decision, or is expensive to undo) or
**reversible** (naming, placement, wording, a cheap edge case).

Write one plan file, `~/.claude/plans/<repo>-<run>.md`, holding:

- the goal, in two lines
- each unit as a slice block (`references/plan-contract.md`)
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

Give the user the file's path, then ask the same questions through the forms (AskUserQuestion), at
most four at a time and the highest-leverage first, and write each answer back to its `Answer:`
line. A change the user did not ask for that alters behaviour they would notice, or reverts or
rewrites earlier work, is load-bearing however cheap it is to undo, and gets its own question.
Fixes for defects found along the way stay automatic. The last batch ends with one question that
lists every reversible call with its default: "OK with these?". After each batch, drop what the
answers settled and ask the next. A run with a run folder
(4 or more units) keeps this file as the folder's `plan.md`.

Run `plan-lint check <plan>` (`scripts/plan-lint`) before the first question and fix every
problem it prints. The last question asks the user to approve the plan as written. Write the
user's answers into each `Answer:` line first. On a yes, run `plan-lint approve <plan>`, which
stamps the plan with a hash. A later edit voids the approval: show the user the change and
approve again.

During the run, a load-bearing question that turns up becomes a `parked` row in the decision log
(`references/plan-contract.md`), with its options and recommendation; only the units it touches
park (see "When a builder parks or fails").

Resuming an approved plan or a handoff needs no re-approval. Splitting new work does. A plan
approved before `plan-lint` existed carries no stamp: on the user's yes, run `plan-lint approve`
again, and `plan-lint verify` passes from then on.

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
