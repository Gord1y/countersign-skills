# Run folder, for series of 4 or more

Long runs get interrupted, by quota or by context compaction. A single run file that grows with
every round is re-read in full each time, and such files grow to tens of kilobytes read dozens of
times in one run. So the state is split by who needs it, outside the repo, in the user's own notes
directory:

```
~/.claude/plans/<repo>-<run>/
  plan.md              the approved plan: every question with its answer, and "Waiting for you"
  orchestrator.md      the only file you re-read
  common.md            rules every unit shares (setup, standing rules, gate, hand-back), written once
  units/NN-<slug>.md   one per unit: its brief, then its hand-back
  log.md               append-only history, never re-read during the run
```

**`orchestrator.md`** stays under 6 KB (`wc -c`), checked before every spawn; over it, move
finished units' detail to `log.md` first. It holds:

- the goal, in two lines
- decisions, one line each with the reason
- facts shared by more than one unit, so a fresh session can re-brief without re-deriving
- the unit table:

  | column | holds |
  | --- | --- |
  | unit | the commit message |
  | status | pending / running / handed back / landed / failed |
  | model | the tier and effort, and for the top tier its one-line reason |
  | worktree + base | the worktree path and the commit it was cut from, for landing and recovery |
  | verified | which gates ran green, on what |
  | gate runs | the full-gate count the builder reported; more than 1 is flagged |
  | open | anything the builder flagged |

- parked units with their questions, and the calls made
- the count of units landed this session, against the limit of 10 or about 300K tokens of context

The first line of the file names the session's landed-unit count, so the 10-unit limit is visible
without a re-read.

A finished unit stays one row. When the file nears its cap, move the detail of finished rounds to
`log.md`.

**It stays current after every landing**: update the unit's row and the session's count before
the next spawn. A handoff at the limit, or after an interruption, is then a short write
that points at this file.

**`units/NN-<slug>.md`** holds the whole brief, written once; the spawn prompt only points at it.
A retry edits this file and respawns, so no brief is ever written twice. At hand-back, paste the
builder's report under a `## Hand-back` heading in the same file and update the table row. Each
brief starts by pointing at `common.md`, so the shared rules are written once.

**Reading rules.** After a compaction or a resume, read `orchestrator.md` once. It stays under
about 120 lines, so one read is cheap. Never re-read it whole within one context: keep the table in
mind and read a range only to check a row. Read a unit file or `plan.md` only by the range you
need: `plan.md` to add a question or to settle a decision `orchestrator.md` leaves in doubt, a
unit file to re-brief or recover that unit. Never read `log.md` during a run. Never write any
of these files, or a handoff, inside the repo.

## Phases: one index plan, one run folder per phase

Work bigger than one PR is split into phases, each one PR. The phases live under one folder:

```
~/.claude/plans/<repo>-<programme>/
  index.md             the goal, each phase with its PR's branch and status, and what is next
  <NN>-<phase>/        that phase's run folder, laid out as above
```

`index.md` stays under about 40 lines. A phase's decisions go into its own `plan.md`, asked in the
planning session for that phase. When a phase's PR is merged, mark it done in `index.md`; the next
phase starts in a fresh planning session from `index.md`.
