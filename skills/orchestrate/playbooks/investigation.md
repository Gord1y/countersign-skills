# investigation

A question about how or why code works, or what a change breaks. It ends in a report and no PR.

Copy these steps into the todo list. A skipped step stays as `skip: <reason>`.

1. **restate**: the `Goal:` line, as the question to answer.
2. **research**: `codebase-research` to find the code, `how-it-works` to explain it,
   `impact-check` for what a change could break.
3. **confirm**: run something for each claim and mark it measured, inferred or guessed.
4. **report**: the answer first, then `file:line` evidence and the unknowns. File it in
   `writeups/scratch/<date>-<topic>/`.
5. **grill**: `skip: investigation`.
6. **slice**: `skip: investigation`.
7. **approve**: `skip: investigation`.
8. **build**: `skip: investigation`.
9. **knowledge**: `repo-knowledge` when the report corrects a node; else
   `skip: no docs/knowledge/index.md` or `skip: no node is wrong`.
10. **prove**: every claim in the report has its run; `gate` is `skip: no code changed`.
11. **review**: `skip: investigation`.
12. **pr**: `skip: investigation`. A fix is a new task and starts at Step 0.
13. **clickup**: `skip: no ClickUp task` until a task id is known.
14. **retro**: `retro` after a correction or a wrong claim found later, else `skip: clean run`.
