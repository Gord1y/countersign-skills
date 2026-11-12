# autonomous-run

A task started unattended. It ends in a draft PR and a decision log, with every question parked.

Copy these steps into the todo list. A skipped step stays as `skip: <reason>`.

1. **restate**: the `Goal:` line, with the playbook the task would use if attended.
2. **research**: as that playbook; read `docs/knowledge/index.md` first.
3. **grill**: never ask. Write each open question as a `parked` row with a recommendation.
4. **slice**: as that playbook; a slice that depends on a parked answer is parked too.
5. **approve**: never ask. A plan the user already approved (`plan-lint verify` exits 0) goes
   on to build, skipping its parked slices. Without one, write the plan, run `plan-lint check`
   and stop here: the plan and its parked rows are the result.
6. **build**: every wall on: the fence, `land-worktree --files`, the push guard, PR size, the
   gate stamp, the walkthrough. A deviation parks its slice only.
7. **knowledge**: `repo-knowledge` "Update and lint"; `skip: no docs/knowledge/index.md`.
8. **prove**: `gate` passes; `qa-tester` per surface; `walkthrough` on a UI diff.
9. **review**: `conformance` per the routing table in `rules/orchestration.md`.
10. **pr**: a draft PR body from `feature-pr-description`; pushed only if pre-authorized.
11. **clickup**: `skip: no ClickUp task` until a task id is known.
12. **retro**: `retro` after a failed gate, revert or parked unit, else `skip: clean run`.
