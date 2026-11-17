# release

Cut, prepare or ship a release. It ends in a release PR with its note.

Copy these steps into the todo list. A skipped step stays as `skip: <reason>`.

1. **restate**: the `Goal:` line.
2. **research**: the commits since the last release; `codebase-research` for the rest.
3. **grill**: the version number, with a recommendation from the commit types.
4. **slice**: `skip: release`, unless a fix is needed first; then one slice per fix.
5. **approve**: `plan-lint check`, the user's yes, `plan-lint approve`, when slices exist.
6. **build**: `release-notes` writes or updates the note.
7. **knowledge**: `repo-knowledge` "Update and lint"; `skip: no docs/knowledge/index.md`.
8. **prove**: `gate` passes; a `qa-tester` smoke pass per surface; a customer `walkthrough`
   when the UI changed.
9. **release-brief**: `release-brief` writes the probe's brief into the probe folder;
   `skip: no UX probe` when the Repo fact is unset, `skip: no T3 Code` outside T3 Code.
10. **probe**: launch the probe thread in its T3 project and wait for its last line;
    `references/ux-probe.md`. BLOCKED goes to the summary as 🙋, never a pass.
11. **ux-triage**: each new candidate becomes confirmed, by design, duplicate or not
    reproducible, judged against the code; confirmed ones become slices for approval; verdicts go
    back to the probe folder in user terms only.
12. **review**: `conformance` per the orchestration rule's routing table.
13. **pr**: `promotion-pr-description` writes the body from the note; give the push commands.
14. **clickup**: `skip: no ClickUp task` until a task id is known.
15. **retro**: `retro` after a correction, failed gate, revert or parked unit, else
    `skip: clean run`.
