---
name: context-transfer
description: "Package this conversation into one self-contained block for a new chat: goal, decisions with reasons, verified progress, next steps."
when_to_use: "Use for a handoff, a context transfer, or a next-session prompt, and when a Countersign context note asks for a handoff or tells the session to stop."
---

# Context Transfer

Your one job: package this conversation so a new chat, holding nothing but your block, continues
the work without missing anything and without asking what was already settled.

Earlier handoffs failed in the same few ways, and every rule below exists to prevent one of them:

- **A chain of documents.** "Read these four files in this order" before the reader knows what the
  work is. The reader burns its context on the chain and still misses what mattered.
- **Recalled progress.** "Tests pass", "pushed", "merged" written from memory, then wrong by the
  time the next chat reads it.
- **Decisions without reasons.** The next chat sees a choice, not why it was made, and reopens it.
- **Names without meaning.** "B13", "Phase 2", "the parity fix" carry nothing across a context
  switch.
- **Story instead of state.** A chronology of the session where the reader needed the current
  position.

---

## Output contract

- **The reply is exactly one fenced block, and nothing else.** No preamble, no audience line, no
  summary markers, no TL;DR, no question afterwards. Open it with a four-backtick ` ````text `
  fence so code fences inside it survive the paste.
- **Save the same text to `~/.claude/plans/context-transfer-<repo>-<yyyy-mm-dd>-<topic>.md`** before
  replying, and put that path in the block's header, so the next chat can re-read the brief after
  its own context is compacted. Never write it inside a repo or a project folder.
- **Written to the next model, in the second person.** "You are continuing…", not "we did…".
- **Delta only.** The next chat is as capable as you and loads CLAUDE.md, rules, memory, skills
  and repo facts on its own. Write only what it cannot read anywhere: decisions and their reasons,
  verified state, traps hit in this session, next steps. Never restate a rule, a skill's procedure,
  a repo fact or a command list the repo documents.
- **Point, don't copy.** When a plan or run file under `~/.claude/plans/` holds the state, name it
  and say which part is current; never copy it into the block. Copy only what the next chat
  cannot open (a claude.ai chat, another machine).
- **Arguments narrow it.** `/context-transfer <focus>` limits the block to that thread of the
  conversation. When the user says the next chat is not Claude Code in the same repo (claude.ai,
  another tool, another machine), nothing loads there on its own: include the project and user
  rules the work depends on.

---

## When Countersign asks for the handoff

A message that opens "Context note from Countersign, the user's approval app" and asks for a
handoff, or tells the session to stop, is served by this skill. Finish the step in hand, start
nothing new, and save the block to the `~/.claude/plans/` path above, even when the note names a
file such as `notes/handoff.md`: a handoff never goes inside a repo. Leave worktrees, branches,
uncommitted work and run folders as they are, and record where each stands under Working state, so
the next session picks them up instead of rebuilding them.

---

## Collect before you write: check, don't recall

At the moment of writing, run and read:

```bash
git rev-parse --show-toplevel
git branch -vv | grep '^\*'
git rev-parse --short HEAD
git status --short
git log --oneline -15
git worktree list
git stash list
git log --oneline @{u}..HEAD
```

The last one lists unpushed commits and fails on a branch with no upstream, which is itself worth
stating. Outside a git repo, skip this and say so in the header.

Then:

- **Processes the work depends on** — dev servers, watchers, background jobs. Use the project's
  own way of listing them when it has one.
- **Re-read the files the work touched**, so every path and line number in the block is current.
- **Read the whole conversation, first turn to last**, for the user's decisions, corrections and
  constraints. The ones from early turns are the ones that get lost.
- **Gates:** report the last run you actually saw and its result. Never write "green" for a gate
  that was not run after the last change.

---

## What the block contains

Use these headings inside the block, in this order. Leave a section out only when it would be
empty.

1. **Header.** One line each: project and absolute path, branch and HEAD short SHA, today's date,
   the saved copy's path, and what the next chat is (default: Claude Code in the same repo, where
   `CLAUDE.md`, memory and skills load on their own).
2. **Goal.** The end state the user wants, in their terms, and the scope boundary: what is
   explicitly not this work.
3. **Decisions.** Each one: what was decided, who decided (the user, or a default you took), and
   why. Quote the user's words when the call was theirs. Include rejected options with the reason,
   so they are not proposed again.
4. **Progress.** Three lists. *Done*, each item with its evidence: a commit SHA, the command that
   passed. *In progress*, with its exact state: which files are edited and uncommitted, what is
   half-written inside them. *Not started.*
5. **Working state.** The `git status` summary, worktrees, stashes, unpushed commits, running
   processes, and anything temporary this session created, with whether to keep or remove it.
6. **References.** Exact values the next chat needs and cannot find in the repo or the run file:
   IDs, URLs, figures, errors verbatim. Not paths it finds with one search.
7. **Gotchas.** Only traps hit in this session that no repo doc records yet. One line each:
   tried X, it fails because Y. A trap worth keeping goes into the repo's docs, not here.
8. **Preferences from this conversation.** Only what the user asked for here that is written
   nowhere else.
9. **Open questions.** Decisions waiting on the user, each with its options and your
   recommendation.
10. **Where we left off.** The last exchange, quoting the user's last message when it is still
    live, then numbered next steps. Step 1 re-checks the working state, because it may have moved.
    Step 2 is executable with no further reading.

---

## Writing rules

- **State, not story.** The current position, not how the session got there.
- **Define every name at first use**, with one plain clause: "B13 (the CSP nonce change)".
- **Exact over approximate.** A paraphrased command, path or error is a wrong one.
- **Mark what you did not verify** as `(unverified)`, with what would verify it.
- **No parked defects.** A bug found in this session is fixed before the transfer, or it is a next
  step with the fix spelled out. Never "known issue, for later".
- **No secrets.** Never a token, key or `.env` value: name the variable and where it lives.
- **Granular, not padded.** Length follows the content. Every line must be something the next
  chat would otherwise rediscover or get wrong; cut anything it learns from one command.
- **Budget: about 3 KB.** The block is re-sent with every request of the next session, and
  handoffs of 7 to 10 KB were mostly restated rules and copied run files. Over budget, cut story
  first, then anything the next chat can see in
  the repo in one command. Long verbatim material (logs, diffs, whole files) becomes a path or a
  command in References, never inline. Decisions, their reasons and the next steps are never cut.
- **Plain markdown only inside the block** — headings and lists, none of the summary markers.

If `local.md` exists next to this file, read it; where it disagrees with this file, it wins.
