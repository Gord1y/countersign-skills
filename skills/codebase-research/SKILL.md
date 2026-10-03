---
name: codebase-research
description: "Research code cheaply: skip agents when you know the file, pick researcher or general-purpose, always pass haiku or sonnet, cap reports at 30 lines."
when_to_use: "Use before spawning any agent to read or search code, or when a question needs several exploratory reads."
---

# Codebase research (cheap, not implementation-grade)

## Repo facts

This skill needs the facts below. Look each one up in the repo's CLAUDE.md (or AGENTS.md) and
the files it imports or points to, then in `local.md` next to this file. If neither has it, ask
the user once, then suggest the one line to add to CLAUDE.md so the next run finds it.

| Fact                                                                    | Example                                                                                  |
| ----------------------------------------------------------------------- | ---------------------------------------------------------------------------------------- |
| Sibling repos research may read, with their absolute paths              | `/Users/me/code/acme-api` (the backend), `/Users/me/code/acme-site` (the marketing site) |
| Architecture rules (layers, boundaries) and the tool that enforces them | `app -> features -> entities -> shared`, enforced by `pnpm lint:boundaries`              |
| Docs and skills to read first, per area                                 | forms: `docs/forms.md`; API shapes: the `api-schemas` skill; e2e: `e2e/README.md`        |

## Why this skill exists

Research is "open files, grep, read, report what's there". Implementation needs judgement and
earns the expensive tier; a lookup sent through that tier (the parent's model, high effort,
extended thinking) pays implementation prices for a grep-and-report job.

A sibling repo (a backend, a marketing site) is a full second codebase: "how does the backend
handle X" is a read-only question, and reading it costs context like anything else. Name the exact
file or question, never "look at how that repo does it". The sibling repos in Repo facts are the
ones research may read.

**Agents without subagents (Codex, Antigravity)** have no `Agent` tool and no per-spawn model tier,
so Steps 2 to 6 do not apply. Steps 0 and 1 still do: check the docs and skills first, then do the
research yourself with shell reads (`rg`, `cat`, `head`).

---

## Step 0 - check if it's already written down

Before spawning anything, check whether the answer already exists. Read what the "Docs and skills
to read first, per area" row of Repo facts lists for the area you're researching. A doc or skill
hit is free; a subagent call is not.

## Step 1 - do you need a subagent at all?

**Fewer than ~3 lookups, and you already know which file(s)** -> just `Read`/`Grep`/`Bash` it
yourself, no `Agent` call. Spawning any subagent, at any model tier, for a single known-file lookup
is pure overhead; the dispatch + report round-trip costs more than just reading the file.

Reach for `Agent` only when the question is broad or fuzzy enough that you'd otherwise burn
several exploratory reads finding the right files, or when the exploration would pollute your
own context with a lot of code you don't need to keep around after the answer is extracted.

## Step 2 - pick the subagent type by job shape

| Job shape | Use | Why |
| --- | --- | --- |
| "Where is X defined / which files reference Y / locate the route for Z": a targeted lookup across an unfamiliar area | `researcher` | `agents/researcher.md`: `haiku`, only `Read`/`Grep`/`Glob`, no CLAUDE.md loaded (about 3.6K tokens saved per spawn), and the 30-line report built in. Where it isn't installed, use `Explore` and state breadth in the prompt: `"quick"`, `"medium"` or `"very thorough"`. |
| "Explain how this whole system works end-to-end" / reconcile behavior across many files into one coherent mental model (e.g. "how does the invoices list's filtering actually work") | `general-purpose` | `Explore`'s own contract disclaims this: _"Do NOT use it for code review, design-doc auditing, cross-file consistency checks, or open-ended analysis - it reads excerpts rather than whole files and will miss content past its read window."_ Cross-file synthesis needs an agent that reads whole files, not excerpts. |
| Anything that changes code, or needs a design/architecture judgment call | _(not this skill)_ | That's implementation, not research: use the parent's normal (full-capability) tier, or a specialized review/build agent. |

## Step 3 - always pass an explicit `model` override

Neither `Explore` nor `general-purpose` pins a model, so a spawn without `model` inherits the parent
session's tier: in a session tuned for implementation, the most expensive one, with extended
thinking on. **A research spawn always sets `model`, and only ever `"haiku"` or `"sonnet"`**: the
parent plans and decides, the spawn reads and reports.

- `"haiku"` by default, for fact-finding: locating code, summarizing what a function does, listing
  fields, props or keys, answering "where, what, does X exist". With `researcher` or `Explore`.
- `"sonnet"` only when the research itself needs reasoning: reconciling contradictory or
  undocumented sources, inferring intent from ambiguous code, or synthesizing a large multi-file
  flow into one accurate account. With `general-purpose`.
- Never `"opus"`. A question that genuinely needs the parent's tier is not research, and this skill
  does not apply to it.

`model` is the only lever: the `Agent` tool has no `effort` parameter.

## Step 4 - scope the prompt to the factual question

Ask for facts, not decisions: "what does the invoice form's schema validate, cite file:line", not
"what does it validate and what should we change". Deciding what to do with a finding is a
judgement step: yours, after the report.

**Cap the report in every prompt.** End it with: "Report at most 30 lines: paths with line ranges
and facts, never file contents. Count the lines before you reply; past 30, cut." `researcher`
carries the cap itself, but `Explore` and `general-purpose` know only what the prompt says, and
uncapped reports have reached 75,000 characters, all of it landing in your context. When a report
still runs long, take what you need from it; never ask it to elaborate.

For a repo outside this one (a sibling from Repo facts), give the target's **absolute path**: the
subagent starts in this repo, not the sibling.

## Step 5 - background vs. foreground

`run_in_background: false` when you need the answer before you can proceed this turn (the
common case: you're gating an edit on understanding existing behavior first).
`run_in_background: true` only when you can usefully keep doing other work while it runs.

## Step 6 - read the report, don't re-derive it

Once the subagent returns, treat its findings as the source of truth: cite file:line from
its report. Don't re-read the same files yourself to double-check a plain factual lookup;
that duplicates the work you just paid for.

---

## Example calls

Targeted lookup, cheap model:

```
Agent({
  description: "Locate invoices list query",
  subagent_type: "researcher",
  model: "haiku",
  prompt: "Find where the invoices list's query and its cache keys are defined."
})
```

Cross-file synthesis, still not implementation-tier:

```
Agent({
  description: "Trace sign-up form submit flow",
  subagent_type: "general-purpose",
  model: "sonnet",
  run_in_background: false,
  prompt: "Read the sign-up form, its schema and its submit mutation. Explain exactly how "
    + "validation errors from the server reach the form fields, and what happens on success. "
    + "Cite file:line for each claim. Do not propose any changes, just report current behavior. "
    + "Report at most 30 lines: paths with line ranges and facts, never file contents. "
    + "Count the lines before you reply; past 30, cut."
})
```

---

If `local.md` exists next to this file, read it; where it disagrees with this file, it wins.
