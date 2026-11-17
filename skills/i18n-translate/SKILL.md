---
name: i18n-translate
description: "Translate added or changed source-locale message keys into every target locale with batched cheap subagents, then run the repo's translation check."
when_to_use: "Use before pushing a change that adds or edits user-facing strings."
effort: medium
context: fork
---

# i18n Translate

You are the translation orchestrator. English is the source of truth and every target locale is
filled from it. Your job: make the translation check pass by translating what is missing or stale.
This runs on the developer's machine before pushing; CI only verifies.

Under Claude Code this skill runs forked: you see this file and its arguments, not the
conversation that called you. The arguments name the base branch; without one, use the branch's
upstream (`git rev-parse --abbrev-ref @{upstream}`) and say so. You never wait on an answer: report
what is missing and stop.

## Repo facts

This skill needs the facts below. Look each one up in the repo's CLAUDE.md (or AGENTS.md) and
the files it imports or points to (of a repo-facts file, only this skill's section:
`sed -n '/^## i18n-translate$/,/^## /p' <file>`), then in `local.md` next to this file. If neither has it, report
it as missing, with the one line to add to CLAUDE.md so the next run finds it.

| Fact | Example |
| --- | --- |
| Source locale and its message folder | `en`, `locales/en/` |
| Target locales | `de`, `fr`, `ja`, `no` |
| Product register (tone, formality, who the reader is) | signed-in app, short literal UI text |
| Glossary file (never-translate terms and per-language rules) | `locales/GLOSSARY.md` |
| Command that lists changed keys | `pnpm i18n:diff origin/<base-branch>` |
| Translation check command | `pnpm i18n:check` |

Where a language code is ambiguous (`no` is Norwegian Bokmål or Nynorsk), name the variant in that
locale's translator prompt. Nothing in CI can detect that drift.

## 1. Build the worklist

Run the changed-keys command from Repo facts against the base branch, for example
`origin/release-1.4.0`. It should print `{"added": [...], "changed": [...]}`, each entry
`<file>:<dotted.key>` relative to a locale directory, resolve the merge base itself, and read the
**working tree**, so uncommitted English edits count. Save the output. If the command has no such
mode, build the same two lists from `git diff` on the source folder.

**Changed keys matter as much as added ones.** A key-presence check compares which keys exist, so
editing an English value leaves every locale holding the previous copy with everything green.

Then run the translation check command from Repo facts. An empty worklist with failing checks means
you are repairing pre-existing drift rather than translating new work: fix exactly what the check
output names.

## 2. Dispatch translators in batches, for the locales THAT HAVE WORK

Dispatch ONLY the locales that actually need work. A key added or changed in English needs every
target locale. But when the worklist is empty you are repairing drift the checks found, and the
check output names the locales it is unhappy with: dispatching the others spends a context to
confirm there is nothing to do. Never include a locale you cannot name a reason for.

Every translator pays a fresh context plus the glossary, so cost scales with the translator count.
Batch by string count:

- Count the strings: the keys in the worklist (`added` plus `changed`), or, when repairing drift
  with an empty worklist, the failing keys the check names.
- Under 20 strings: ONE translator takes every locale that has work.
- 20 strings or more: one translator per group of up to 5 locales. Make the groups as even as
  possible (12 locales: 3 translators of 4, not 5+5+2).
- Say how many translators you dispatched, the string count and the locale groups.

**Claude Code.** Spawn one subagent per translator with the `Agent` tool, all in one message, with
the same `subagent_type: "general-purpose"`, `model: "haiku"` and `effort: "low"`. Every `Agent`
call MUST pass `run_in_background: false`. Subagents run in the background by default, and a
backgrounded subagent reports back only on a later turn.

**Under Codex** there is no `Agent` tool and no Haiku tier. Use Codex's own subagent tool if it
has one, with the same per-batch brief. Without one, translate the locales yourself one at a
time: for each locale, read its current file before writing and apply section 3 and
`references/subagent-rules.md` as if you were that locale's translator. Sections 4 and 5 are
unchanged.

## 3. What each subagent may touch

**Give every path as an ABSOLUTE path.** Run `pwd` first and interpolate that root into each
subagent prompt. A subagent does not reliably inherit your working directory, and a repo is often
checked out more than once at a time: the main tree, git worktrees, a sibling checkout with a
message tree of the same shape. A relative path resolved against the wrong root sends a translator
into another checkout, where it edits a branch nobody asked it to touch and the checks you then run
report green against a tree that was never fixed. Measured once: 4 of 13 subagents wrote into the
wrong checkout from a relative path, and every one of them reported success.

Tell each subagent it may read exactly these, each named absolutely:

- the translation and JSON rules, read first: on the Claude Code route the file
  `${CLAUDE_SKILL_DIR}/references/subagent-rules.md`
- `<root>/<source-folder>/<file>`: the English source
- `<root>/<messages-folder>/<locale>/<file>`: the current translations, for each of its locales
- `<root>/<glossary-file>`: terminology, never-translate list, typography

and may edit ONLY files under `<root>/<messages-folder>/<locale>/` for the locales in its batch.
It must read each of its locale files before writing: a translator that cannot see the existing
file re-coins terminology that is already consistent, and nothing in CI can detect terminology
drift; only a native reader can.

After the subagents return, confirm where the edits actually landed before trusting any of it:

```bash
git status --short -- <messages-folder>
```

Exactly the locales you dispatched, plus the source locale, and nothing outside this tree.

Name the exact FILES each subagent needs, from the worklist, never "the message tree". Only files
carrying an added or changed key are in scope; a subagent that opens `invoices.json` to translate
one key in `settings.json` has spent tokens for nothing, in a fresh context that shares no cache
with yours.

Every subagent you dispatch reads the glossary, so its size is multiplied by the number of translators.
Quote the parts that bear on THIS batch directly in the subagent prompt (the terms actually
appearing in the changed strings, the never-translate list, and the dash rule) and tell the
subagent to open the file only if it needs something you did not quote.

## 4. Verify the work yourself

Do NOT trust a subagent's report that it finished. After the subagents return, run the translation
check command from Repo facts.

Iterate (re-dispatch or fix directly) until it exits 0, for AT MOST THREE rounds after the first
dispatch. Re-dispatch only the locales still failing, batched by the same rule, never the whole set. A loop that has not
converged in three rounds is usually hitting something a subagent cannot fix, not something one
more try will solve.

If a check reports a legitimate loanword or proper noun as English, do not force a bad translation:
leave the value, and say so. The check scripts' allowlists and the glossary are the correct fix, and
that is a human's call: the glossary and the script are edited together, never one alone.

## 5. Report

Say how many translators you dispatched, the string count and the locale groups, and why those locales. Then say what the translation check finally reported, and every remaining failure you
chose not to force. A locale nobody can read is only as trustworthy as the account you give of it.

If `local.md` exists next to this file, read it; where it disagrees with this file, it wins.
