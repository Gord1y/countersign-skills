# knowledge-update

Refresh or bootstrap the knowledge graph, a glossary entry or an ADR. It ends in a reviewed PR.

Copy these steps into the todo list. A skipped step stays as `skip: <reason>`.

1. **restate**: the `Goal:` line.
2. **research**: `repo-knowledge` Readers, then the touched paths from `git ls-files`.
3. **grill**: only a choice the user would notice, such as an ADR's decision.
4. **slice**: a bootstrap is one slice with `Sensitive: .github/workflows/*`, since it adds a CI
   job; an update is one slice per area.
5. **approve**: `plan-lint check`, the user's yes, `plan-lint approve`.
6. **build**: `repo-knowledge` Bootstrap or "Update and lint".
7. **knowledge**: `skip: done in build`.
8. **prove**: `gate` passes, including the knowledge lint.
9. **review**: `reviewer` checks the nodes against the code.
10. **pr**: `feature-pr-description` writes `pr.md`; give the push commands.
11. **clickup**: `skip: no ClickUp task` until a task id is known.
12. **retro**: `retro` after a correction, failed gate, revert or parked unit, else
    `skip: clean run`.
