---
name: how-it-works
description: "Explain how a part of the codebase works for the person about to change it: what it is, its moving parts, the flow with file:line refs and a diagram, where to start, traps."
when_to_use: "Use for 'how does X work', 'explain this subsystem or flow', or getting oriented in unfamiliar code before changing it."
---

# How it works

## Repo facts

This skill needs the facts below. Look each one up in the repo's CLAUDE.md (or AGENTS.md) and
the files it imports or points to, then in `local.md` next to this file. If neither has it, ask
the user once, then suggest the one line to add to CLAUDE.md so the next run finds it.

| Fact | Example |
| --- | --- |
| Docs and skills to read first, per area | forms: `docs/forms.md`; API shapes: the `api-schemas` skill; e2e: `e2e/README.md` |

## Purpose

Give an experienced engineer new to this area a working mental model before they change it: its
purpose, parts, how a request or event moves through it, where to start, what bites. Not an
annotated source listing.

## Scope

Restate the question as one line naming the subsystem and its boundary. When it is ambiguous,
take the narrowest reading that still answers it, say which in the answer's first line, and go
on. Do not ask.

## Read the docs first

Read what the Repo facts row lists for the area. A doc may answer the question or name the entry
points.

## Size the job

Narrow: one module or one flow, and the files are known or one search finds them. Read the code
yourself, no subagents. This is the default when unsure.

Wide: several directories, services or layers, or the entry point is unknown. Split into 2-4
slices that do not overlap, for example trigger and entry; core processing; storage and outbound
effects; failure and retry. Spawn one `researcher` per slice, all in one message, with
`model: "haiku"`, or `Explore` with `model: "haiku"` where `researcher` is not installed. Give
each `references/slice-brief.md` filled in. Agents without subagents (Codex, Antigravity) read
the slices themselves, one after another.

## Confirm before writing

Open the 2-3 files the flow hinges on yourself. Settle conflicts between slice reports by
reading the code. Never write from slice reports alone.

## Write the explanation

Write it yourself, no writer subagent. Use these `###` sections in order. Drop empty ones.

- `What it is`: 2-4 sentences: purpose, why it exists, what is in and out of scope.
- `Moving parts`: each type, module, service or table needed, one line and path each.
- `The flow`: numbered steps from trigger to result. Each names the function and its `file:line`,
  and the data handed on. Add a mermaid diagram when three or more parts exchange messages or
  data passes through stages; skip it otherwise. Prose, not pseudocode. Quote code only when a
  point depends on exact syntax, about 10 lines at most.
- `Where to start`: the 3-6 files to open first, each with why.
- `Traps`: what surprises a newcomer, such as ordering, implicit defaults, caching, legacy paths,
  or a misleading name. Only traps found in the code.
- `Not traced`: what this run could not confirm. Never guess to fill a gap.

## Rules

- Cite only paths and lines seen in this run.
- Prefer concrete names: "`JobQueue.retry()` re-enqueues with a delay", not "the queue handles
  retries".
- Length follows complexity: a narrow question gets a short answer.

If `local.md` exists next to this file, read it; where it disagrees with this file, it wins.
