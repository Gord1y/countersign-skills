# ui-change

The point is what a user sees. It ends in a PR that links a walkthrough.

Copy these steps into the todo list. A skipped step stays as `skip: <reason>`.

1. **restate**: the `Goal:` line.
2. **research**: `codebase-research` for the component and its tokens; `how-it-works` if unknown.
3. **grill**: render each visual option in the real classes and tokens, in light and dark, with
   loading, empty, error and success states, before asking the user to choose.
4. **slice**: vertical, at most 400 lines each, stacked PRs past one.
5. **approve**: `plan-lint check`, the user's yes, `plan-lint approve`.
6. **build**: orchestrator mode at 3 or more units, else one commit per slice. `i18n-translate`
   for every new string.
7. **knowledge**: `repo-knowledge` "Update and lint"; `skip: no docs/knowledge/index.md`.
8. **prove**: `gate` passes; `qa-tester` runs the state matrix; `walkthrough` per the repo fact.
9. **review**: `conformance` per the orchestration rule's routing table.
10. **pr**: `feature-pr-description` writes `pr.md` and links the walkthrough.
11. **clickup**: `skip: no ClickUp task` until a task id is known.
12. **retro**: `retro` after a correction, failed gate, revert or parked unit, else
    `skip: clean run`.
