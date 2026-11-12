---
name: retro
description: Turn a session's mistakes and lessons into structure, not notes. Each lesson goes to the highest rung that works, proven to fail on the real mistake first. Run with /retro.
disable-model-invocation: true
---

# Retro

A note in memory may never load, and a model may read it and still slip. A check runs every time.
This skill turns what went wrong in a session into the strongest fix the repo can hold, proves the
fix catches the real mistake, and never settles for a note.

## Repo facts

This skill needs the facts below. Look each one up in the repo's CLAUDE.md (or AGENTS.md) and
the files it imports or points to (of a repo-facts file, only this skill's section:
`sed -n '/^## retro$/,/^## /p' <file>`), then in `local.md` next to this file. If neither has it, ask
the user once, then suggest the one line to add to CLAUDE.md so the next run finds it.

| Fact | Example |
| --- | --- |
| The gate that must pass | `pnpm check`, which runs lint, typecheck and tests |
| The lint configuration and the test runner | `eslint.config.js`; `vitest` |
| The docs per area, and the repo's knowledge index | `docs/features/<name>.md`, mapped by `docs/knowledge/index.md` |

## Step 1: gather the lessons

Use the session in front of you, or the sessions the user names. Sources, in this order:

- The live context of this session.
- Claude Code transcripts: `~/.claude/projects/<key>/*.jsonl`, or under `$CLAUDE_CONFIG_DIR` when
  it is set. The key is the repo's absolute path with each non-alphanumeric character written as
  `-`.
- Codex transcripts: `$CODEX_HOME/sessions/`, default `~/.codex/sessions/`, files named
  `rollout-*.jsonl`.
- Claude Code's auto memory for the repo, to find what was already written down.

A lesson is a user correction, a failed gate, a revert, a retry repeated, or a fact found late.

With several transcripts, or one over 1 MB, read each in its own reader so the main context stays
small. Each reader gets this brief, with the transcript's absolute path filled in:

```
Read the transcript <absolute path>, a JSONL file, in ranges of 200 lines. Report at most 30
lines of lessons. For each: what went wrong; the evidence, as a transcript line number and at most
two quoted lines; what would have prevented it. Never copy a secret.
```

**Claude Code.** One `Agent` call per transcript, up to four in one message: `subagent_type:
"researcher"` when the `researcher` agent is installed and `"general-purpose"` otherwise,
`model: "haiku"`, `effort: "low"`, `run_in_background: false`.

**Under Codex** there is no `Agent` tool. Under T3 Code, dispatch each transcript as a
`delegate_task` child with `mode: "wait"`, `target: {providerInstanceId: "codex", model:
"gpt-6.1-terra", options: {reasoningEffort: "low"}}` and the same brief, which starts by telling
the child to begin with a fresh context. Without T3 Code, read one transcript at a time yourself,
keeping only its report before the next.

## Step 2: pick the rung

Put each lesson into the highest rung that works. For each lesson, say in one clause why every
higher rung does not work.

| Rung | The fix | Choose it when |
| --- | --- | --- |
| 1. Architecture | Change the structure so the mistake cannot be written. | The code offers two ways to do one thing, or shares state it should not. |
| 2. Types | Make the wrong value fail to compile. | The mistake was a wrong shape, id or unit passed along. |
| 3. Lint | Add or tighten a rule in the lint configuration. | The mistake is a pattern a rule can name. |
| 4. Tests | Add a test that fails on the mistake. | The mistake is behaviour no type or rule sees. |
| 5. Docs | Write it in the area's node, a glossary term, a decision record or a CLAUDE.md line. | Only judgement or context was missing. |

A lesson for another repo or team becomes a brief in `writeups/briefs/`, not a change here. A habit
that crosses projects becomes a proposed global rule, written as text for the user to decide. A note
in memory is never the fix.

## Step 3: one proposal

One table, nothing built yet: the lesson, its evidence, the rung, the fix and the proof plan. List
beside it every memory entry the fixes now cover, proposed for deletion. Ask once: build all, pick
rows, or nothing.

## Step 4: build and prove

For each approved row:

1. Re-create the mistake in a scratch copy: `git worktree add "$TMPDIR/retro-<n>" HEAD`, then
   repeat the slip there. The new check must fail on it. Quote the failing line. When the mistake
   cannot be re-created, quote the earlier failing output instead and say so.
2. Build the fix in the repo. The same check now passes on the fixed code. Quote the passing line.
3. For the docs rung, the proof is that `docs/knowledge/index.md` maps the path to the node, and
   that the repo's knowledge lint passes when it has one.
4. Keep evidence in `writeups/scratch/<date>-retro/`. Remove the scratch copy with
   `git worktree remove --force "$TMPDIR/retro-<n>"`.

Then run the repo's gate once. Make one Conventional Commit per fix, never push, and delete the
memory entries the user approved in Step 3.

## Step 5: report

Per lesson: the rung, the files changed, the failing line and the passing line, or why it was
skipped. Then the briefs written and the memory entries deleted.

If `local.md` exists next to this file, read it; where it disagrees with this file, it wins.
