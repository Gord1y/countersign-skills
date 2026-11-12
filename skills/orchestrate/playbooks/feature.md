# feature

New or extended behaviour. It ends in a reviewed PR with proof.

Copy these steps into the todo list. A skipped step stays as `skip: <reason>`.

1. **restate**: the `Goal:` line.
2. **research**: `codebase-research` picks the cheapest way; `how-it-works` for unfamiliar code.
3. **grill**: every open question at once, each with options and a recommendation.
4. **slice**: vertical, prefactor first, at most 400 lines each, stacked PRs past one.
5. **approve**: `plan-lint check`, the user's yes, `plan-lint approve`; one slice with no
   load-bearing question skips the plan.
6. **build**: orchestrator mode at 3 or more units, else one commit per slice. `i18n-translate`
   for new strings; `impact-check` on a contract change.
7. **knowledge**: `repo-knowledge` "Update and lint"; `skip: no docs/knowledge/index.md`.
8. **prove**: `gate` passes; `qa-tester` per surface; `walkthrough` on a UI diff.
9. **review**: `conformance` per the orchestration rule's routing table.
10. **pr**: `feature-pr-description` writes `pr.md`; give the push commands.
11. **clickup**: `skip: no ClickUp task` until a task id is known.
12. **retro**: `retro` after a correction, failed gate, revert or parked unit, else
    `skip: clean run`.
