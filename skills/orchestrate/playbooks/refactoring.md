# refactoring

Structure changes and behaviour stays. It ends in a PR where the old tests pass unedited.

Copy these steps into the todo list. A skipped step stays as `skip: <reason>`.

1. **restate**: the `Goal:` line.
2. **research**: `impact-check` for every caller; `codebase-research` for the rest.
3. **grill**: only what changes a contract or a name the user sees.
4. **slice**: expand, migrate callers, delete. No compatibility layer for an internal API.
5. **approve**: `plan-lint check`, the user's yes, `plan-lint approve`.
6. **build**: orchestrator mode at 3 or more units, else one commit per slice.
7. **knowledge**: `repo-knowledge` "Update and lint"; `skip: no docs/knowledge/index.md`.
8. **prove**: `gate` passes with the old tests unedited; QA is `skip: no behaviour change`.
9. **review**: `conformance` per the orchestration rule's routing table; the review
   flags any behaviour change as a defect.
10. **pr**: `feature-pr-description` writes `pr.md`; give the push commands.
11. **clickup**: `skip: no ClickUp task` until a task id is known.
12. **retro**: `retro` after a correction, failed gate, revert or parked unit, else
    `skip: clean run`.
