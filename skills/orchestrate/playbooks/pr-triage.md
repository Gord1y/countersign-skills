# pr-triage

A PR link, its review findings or its failing checks. It ends in verified fixes, pushed by command.

Copy these steps into the todo list. A skipped step stays as `skip: <reason>`.

1. **restate**: the `Goal:` line, with the PR number.
2. **research**: `pr-review-triage` collects and verifies every finding at the PR head.
3. **grill**: every finding that needs a decision, at once, with a recommendation.
4. **slice**: one slice per verified fix, taken from the fix plan.
5. **approve**: the fix plan is the plan: `plan-lint check`, the user's yes, `plan-lint approve`.
6. **build**: test first, then the fix, one commit each.
7. **knowledge**: `repo-knowledge` "Update and lint"; `skip: no docs/knowledge/index.md`.
8. **prove**: `gate` passes; `qa-tester` on the surfaces the fixes touched.
9. **review**: `conformance` per the routing table in `rules/orchestration.md`.
10. **pr**: `feature-pr-description` over the whole branch; give the push commands.
11. **clickup**: `skip: no ClickUp task` until a task id is known.
12. **retro**: `retro` after a correction, failed gate, revert or parked unit, else
    `skip: clean run`.
