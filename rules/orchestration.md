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
- Under T3 Code, mechanical work goes to Codex through `delegate_task`, so my Claude quota pays
  only for judgement. A `delegate_task` brief points at the role's `agents/<role>.md` and says
  "start with a fresh context". Route by the table below.

| Work | Under T3 | Outside T3, or on fallback |
| --- | --- | --- |
| One translator per locale (`i18n-translate`) | `delegate_task` to `codex`, `gpt-6.1-terra`, `reasoningEffort: low` | `haiku`, `low` |
| A mechanical build unit (the brief names every change) | `delegate_task` to `codex`, `gpt-6.1-terra`, `reasoningEffort: medium`, `agents/builder.md` as the role | `builder`, `sonnet`, `medium` |
| Conformance review of Claude-written code | `delegate_task` to `codex`, `gpt-6-sol`, `reasoningEffort: high`, `agents/conformance.md` as the role | `conformance`, `sonnet`, `high`; the report says the review was same-family |
| Conformance review of Codex-written code | `delegate_task` to `claudeAgent`, `claude-sonnet-5-5`, `effort: high`, `agents/conformance.md` as the role | From Claude: `conformance`, `sonnet`, `high`. From Codex: I run it in Claude Code |
| Everything else: research, judgement builds, standards review, QA, planning | Claude, as above | Claude, as above |

- When one provider's quota or model is unavailable, the same role runs on the other provider and
  the report says so. Outside T3, where the other provider can't be reached, that work waits and
  the report names it as an action for me.

- Handoffs go through the `context-transfer` skill only. If it isn't offered, the install is
  broken: say so and ask me to re-run `install.sh`.
