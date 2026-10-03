---
name: impact-check
description: "Check what a change could break outside its diff, name the premise it is safe because of, and prove that premise by running the real code."
when_to_use: "Use before merging a diff you don't fully trust, or for 'what could this break' and 'is this safe to merge'."
---

# Impact check

## Repo facts

This skill needs the facts below. Look each one up in the repo's CLAUDE.md (or AGENTS.md) and
the files it imports or points to, then in `local.md` next to this file. If neither has it, ask
the user once, then suggest the one line to add to CLAUDE.md so the next run finds it.

| Fact | Example |
| --- | --- |
| Where to run a throwaway proof script | the session scratchpad or `$TMPDIR`, run with the repo's runtime (`node`, `pnpm exec tsx`, `python3`) |

## Purpose

Find what a change could break outside its lines, and back the verdict with code that
ran, not a persuasive writeup. Listing callers is not the deliverable. The value is in breakage a
symbol search cannot see.

## Evidence labels

Label every claim the verdict rests on.

- `run`: a script or test exercised the real code, with the library version the app ships. Its
  output is pasted.
- `read`: a cited `file:line` (or the library's source) and a traced path showing the failure
  cannot be reached.
- `assumed`: neither. Allowed, but labelled, and never presented as settled.

A verdict with an `assumed` premise says so in its first line.

## Steps

1. **Read the change.** Take the diff: staged, a branch, or a PR (`gh pr diff <n>`,
   `gh pr view <n>`). Note what changes implicitly: defaults, ordering, timing, types, formats,
   error paths.
2. **Name the premise.** It is the one or two facts that make the change safe if they hold, for
   example "the removed cache key is never read after startup". Most risky-looking changes reduce
   to one. Spend the effort here, not on a long list.
3. **Look past the symbol search.** It misses:
   - serialized forms: API JSON, DB columns, cache keys, queue messages, files, URLs;
   - other services or languages that read the same data;
   - feature flags, environment and config;
   - lifecycle and timing: async ordering, teardown, retries, render semantics;
   - the library at its lockfile version and any local patch: read its source in `node_modules` or
     the equivalent;
   - generated code, locale, timezone, platform.
4. **Prove the premise.** Write a throwaway script at the Repo facts location, outside the repo.
   It imports the real module or the same library version and fails loudly if the premise is
   false. Run it, paste the command and output, then delete it. If that is costly, label the
   premise `assumed` and say what would prove it.
5. **Weigh each risk.** Give how it breaks, `file:line`, likelihood, cost, and the check that
   would catch it. List what was checked and found fine separately, one line of reason each. Cite
   only code seen in this run, report an empty search as such, never invent a caller or an API.
6. **Second opinions, only on request and for a wide change.** Run 2-3 read-only
   `general-purpose` subagents with `model: "sonnet"` on one question, merge and note where they
   disagree. Agents without subagents (Codex, Antigravity) skip this.

## Output

### Change

What it does, including the implicit part.

### Premise

The fact or facts, each one's label, and the pasted proof.

### Risks

Real ones only, with the step 5 fields.

### Cleared

What was checked, and why it is fine.

### Before merging

The smallest test or repro that fails on the real risk, with the proof script kept to become it.

Strip secrets and private data before posting anything outside the conversation.

If `local.md` exists next to this file, read it; where it disagrees with this file, it wins.
