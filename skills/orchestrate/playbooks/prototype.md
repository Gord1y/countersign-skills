# prototype

A spike or proof of concept. It ends with what the prototype decides, and it is never merged.

Copy these steps into the todo list. A skipped step stays as `skip: <reason>`.

1. **restate**: the `Goal:` line, with the one question the prototype answers.
2. **research**: read only what the question needs.
3. **grill**: `skip: prototype`.
4. **slice**: `skip: prototype`.
5. **approve**: `skip: prototype`.
6. **build**: on a branch named `prototype/<slug>`. Open a draft PR only if the user asks.
7. **knowledge**: `skip: prototype, never merged`.
8. **prove**: run it with `qa-tester` and save the evidence; report what `gate` says without
   fixing it.
9. **review**: `skip: never merged`. A draft PR the user asked for stays a draft.
10. **pr**: `skip: prototype`, unless the user asked for that draft PR.
11. **decide**: state what the prototype decides, and what a real build would need.
12. **clickup**: `skip: no ClickUp task` until a task id is known.
13. **retro**: `retro` after a correction, a revert or a parked unit, else `skip: clean run`. A
    failing gate is expected here and is no trigger.
