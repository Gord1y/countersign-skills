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
9. **review**: `conformance` per the routing table in `rules/orchestration.md`.
10. **pr**: `promotion-pr-description` writes the body from the note; give the push commands.
11. **clickup**: `skip: no ClickUp task` until a task id is known.
12. **retro**: `retro` after a correction, failed gate, revert or parked unit, else
    `skip: clean run`.
