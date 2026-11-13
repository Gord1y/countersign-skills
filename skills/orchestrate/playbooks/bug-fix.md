# bug-fix

Something fails that should work. It ends in a fix whose test failed first.

Copy these steps into the todo list. A skipped step stays as `skip: <reason>`.

1. **restate**: the `Goal:` line, with the symptom.
2. **reproduce**: a failing test, or `qa-tester` when no test seam exists. Keep the failing line.
3. **research**: `how-it-works` on the failing path, `codebase-research` for the rest.
4. **grill**: only what the user would notice; the rest is a `call` row.
5. **slice**: usually one; the test lands in the fix commit.
6. **approve**: one slice with no load-bearing question skips the plan.
7. **build**: the fix, then run the test to see it pass. After two fixes fail one gate, stop and
   test the premise before a third.
8. **knowledge**: `repo-knowledge` "Update and lint"; `skip: no docs/knowledge/index.md`.
9. **prove**: `gate` passes; quote the failing line before and the passing line after.
10. **review**: `conformance` per the orchestration rule's routing table.
11. **pr**: `feature-pr-description` writes `pr.md`; give the push commands.
12. **clickup**: `skip: no ClickUp task` until a task id is known.
13. **retro**: `retro` after a correction, failed gate, revert or parked unit, else
    `skip: clean run`.
