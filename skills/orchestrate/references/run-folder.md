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

**`orchestrator.md`** stays under about 120 lines:

- the goal, in two lines
- decisions, one line each with the reason
- facts shared by more than one unit, so a fresh session can re-brief without re-deriving
- the unit table:

  | column | holds |
  | --- | --- |
  | unit | the commit message |
  | status | pending / running / handed back / landed / failed |
  | model | the tier, and for the top tier its one-line reason |
  | worktree + base | the worktree path and the commit it was cut from, for landing and recovery |
  | verified | which gates ran green, on what |
  | gate runs | the full-gate count the builder reported; more than 1 is flagged |
  | open | anything the builder flagged |

- parked units with their questions, and the calls made

A finished unit stays one row. When the file nears its cap, move the detail of finished rounds to
`log.md`.

**`units/NN-<slug>.md`** holds the whole brief, written once; the spawn prompt only points at it.
A retry edits this file and respawns, so no brief is ever written twice. At hand-back, paste the
builder's report under a `## Hand-back` heading in the same file and update the table row. Each
brief starts by pointing at `common.md`, so the shared rules are written once.

**Reading rules.** After a compaction or a resume, read `orchestrator.md` and nothing else. Open
`plan.md` only to add a question or to settle a decision `orchestrator.md` leaves in doubt, and a
unit file only to re-brief or recover that unit. Never read `log.md` during a run. Never write any
of these files, or a handoff, inside the repo.
