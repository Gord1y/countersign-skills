## Planning and orchestration

- **Ask everything up front, from one plan file.** Research first. Then, before starting a task,
  write every load-bearing decision into one plan file, `~/.claude/plans/<repo>-<task>.md`, each
  with its options, your recommendation and an `Answer:` line. Give me its path, ask the same
  questions through the forms, at most four at a time and the highest-leverage first, and write
  each answer back. After each batch, drop what my answers settled and ask the next. Past about
  twelve questions, split the task into phases and plan each on its own. Load-bearing means it
  changes a contract, behaviour I would notice or a recorded decision, or would be expensive to
  undo. Take reversible calls yourself with your recommended default, and list them in the plan
  file and the closing summary.
- **Once I approve, don't ask again in that task.** A load-bearing surprise parks only its piece
  of work; everything else finishes, and it comes back as ❓ in the closing summary.
- **On any task of 3 or more independently verifiable commits, invoke the `orchestrate` skill**
  and work as an orchestrator; the split is part of the up-front questions. Below that threshold,
  work normally and write the code yourself.
- **Small, fully specified units skip the builders,** whatever their count: when each is a few
  dozen lines (tooling, config, docs or `src/`), do them yourself on one branch, one commit per
  task, and gate after each batch. Builders are for units that are large or intricate.
- **Every Agent spawn names `model`:** `haiku` for search and read-only work, `sonnet` for building
  and for judgement calls, `opus` only with the reason stated in the prompt. No setting gives
  subagents a default model, so an unnamed spawn inherits the main session's.
