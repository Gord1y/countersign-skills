## Planning and orchestration

- Research first, then write every load-bearing decision into one plan file,
  `~/.claude/plans/<repo>-<task>.md`, each with options, your recommendation and an `Answer:` line.
  Ask them through the forms, at most four at a time, highest leverage first, and write each answer
  back. Load-bearing means it changes a contract, behaviour I would notice or a recorded decision,
  or is expensive to undo. Take reversible calls yourself and list them.
- Once I approve, don't ask again in that task: a surprise parks only its piece and comes back as ❓.
- 3 or more independently verifiable commits: invoke `orchestrate`. Units of a few dozen lines skip
  the builders: write them yourself, one commit each.
- Every Agent spawn names `model`: `haiku` to search and read, `sonnet` to build and judge, `opus`
  only with the reason in the prompt.
- Handoffs go through the `context-transfer` skill only. If it isn't offered, the install is
  broken: say so and ask me to re-run `install.sh`.
