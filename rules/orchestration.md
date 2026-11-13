## Planning and orchestration

- Research first, then write every load-bearing decision into one plan file,
  `~/.claude/plans/<repo>-<task>.md`, each with options, your recommendation (worded so that
  answering "yes" accepts it) and an `Answer:` line. Ask them through the forms, at most four at a
  time, highest leverage first, and write each answer back. Load-bearing means it changes a
  contract, behaviour I would notice or a recorded decision, or is expensive to undo. Take
  reversible calls yourself and list them in one "OK with these?" question before building. A
  change I did not ask for that alters behaviour I would notice, or reverts earlier work, is never
  a reversible call.
- Once I approve, don't ask again in that task: a surprise parks only its piece and comes back as ❓.
- Every task that changes, investigates or ships code: invoke `orchestrate`. Builders start at 3 or
  more independently verifiable commits.
- Every Agent spawn names `model` and `effort`: `haiku` with `low` to search and read, `sonnet`
  with `medium` to build and QA and `high` to review, `opus` with `high` for the planner, or
  anything else only with the reason in the prompt.
- Under T3 Code, Codex does one job: the conformance review of Claude-written code, through
  `delegate_task`, so every review comes from the other model family. Everything else runs on
  Claude, mechanical builds and translators included. A `delegate_task` brief points at the role's
  `agents/<role>.md` and says "start with a fresh context". Route by the table below.

| Work | Under T3 | Outside T3, or on fallback |
| --- | --- | --- |
| One translator per locale (`i18n-translate`) | `haiku`, `low` | `haiku`, `low` |
| A mechanical build unit (the brief names every change) | `builder`, `sonnet`, `medium` | `builder`, `sonnet`, `medium` |
| Conformance review of Claude-written code | `delegate_task` to `codex`, `gpt-6-sol`, `reasoningEffort: high`, `agents/conformance.md` as the role | `conformance`, `sonnet`, `high`; the report says the review was same-family |
| Conformance review of Codex-written code | `delegate_task` to `claudeAgent`, `claude-sonnet-5-5`, `effort: high`, `agents/conformance.md` as the role | From Claude: `conformance`, `sonnet`, `high`. From Codex: I run it in Claude Code |
| Everything else: research, judgement builds, standards review, QA, planning | Claude, as above | Claude, as above |

- When Codex's quota or model is unavailable, the review of Claude-written code runs on Claude and
  the report says it was same-family. Outside T3, where Codex can't be reached, the review of
  Codex-written code waits for me to run it in Claude Code, and the report names it as an action
  for me.
- Work in another repo I develop runs in a new T3 thread in that repo's project, started without
  asking me: `t3_thread_launch` with its `projectId`, on its main checkout or a worktree, on
  Claude, with a builder brief. `delegate_task` runs only in the current thread's project, and the
  write hook refuses paths outside the current repo, so neither reaches the other repo. The
  launching session reviews the result and commits it there. Another team's repo still gets only a
  note for that team.

- Handoffs go through the `context-transfer` skill only. If it isn't offered, the install is
  broken: say so and ask me to re-run `install.sh`.
