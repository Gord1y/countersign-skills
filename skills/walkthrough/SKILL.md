---
name: walkthrough
description: "Show what a finished change did and prove it works with its evidence: a short markdown note after any change, or a customer-facing HTML walkthrough of a release."
when_to_use: "Use when asked to walk through, recap or show what changed and the evidence it works ('walk me through the change', 'show me what changed', 'prove it works'), or for a customer release walkthrough."
---

# Walkthrough

One skill, two audiences. Pick by what was asked:

- **You:** "walk me through the change", "show me what changed", or the end of an orchestrated run.
  A short markdown note for the developer who made or reviews the change, for any kind of change
  (section 2).
- **Customers:** "release walkthrough", "what's new for customers", or a release version. A
  self-contained HTML page showing what a release changed for the people who use the product, for
  releases they see in the UI (section 3).

When it is unclear, take **you**, the smaller deliverable, and say so in one line.

Neither audience gets a PR description or a test report: a walkthrough does not argue for merging and
does not list every check that ran.

## Repo facts

This skill needs the facts below. Look each one up in the repo's CLAUDE.md (or AGENTS.md) and
the files it imports or points to, then in `local.md` next to this file. If neither has it, ask
the user once, then suggest the one line to add to CLAUDE.md so the next run finds it.

| Fact | Example |
| --- | --- |
| Where drafts and walkthroughs go | A gitignored `writeups/` folder in the main checkout, resolved from the main checkout |
| How to reach the product, and how to sign in | The `qa-tester` Repo facts: its surfaces, test account and sign-in steps |
| Where release notes live, and who reads them | `releases/release-<version>.md`, written for the people who use the product (see `release-notes`) |
| The brand look to copy | The site's own fonts as a system stack, its accent colours, both light and dark |
| Words banned from customer-facing text | The "Jargon banned from reader-facing text" row of `release-notes`, plus the internal terms in section 3 |

## 1. Evidence first

Both audiences need evidence from the running product, never invented.

- If a `qa-tester` run for this change exists, reuse its folder,
  `writeups/changes/<date>-<run>/qa/`: its `results.md` and the evidence files it lists.
- Otherwise invoke `qa-tester` on the change first; it saves the evidence this skill reads. Never
  start, stop or restart a server: the product is reached the way `qa-tester`'s Repo facts say, and
  reported as down if it is not there.
- Never invent a screenshot, a transcript or a step nobody ran.

## 2. For you

### When

After a change has been QA'd, at the end of an orchestrated run, or when the user asks for one.

The input is the diff plus the `qa-tester` folder: the cases that ran, their verdicts and their
evidence. If no evidence exists, get it first (section 1).

### Format

Write `walkthrough.md`, about 40 lines, in plain words (see `human-voice-writing`). Four sections:

- `## What changed`: 3 to 5 lines, described by behaviour, not by file.
- `## Try it`: numbered steps, written as the surface's user performs them: a click, a request, a
  command, a call. Each step has one "look for" line saying what should be visible, and its
  evidence.
- `## Files worth reading`: at most 5 paths, one line each on why that file matters.
- `## Not covered`: what was not exercised, so the reader knows where to look themselves.

### Evidence per surface

Each step shows the evidence of the surface it exercises, from `qa/`:

| Surface | What a step shows |
| --- | --- |
| Web, native or mobile app, game | the screenshot, as `![Step 2](qa/02-settings-saved.png)` |
| HTTP API | the request line and the response's decisive lines in an `http` block, then a link to the full `qa/NN-<case>.http` |
| CLI and scripts | the command and its decisive output lines in a `console` block, then a link to the full transcript |
| Library | the few lines of the call and their output, before and after when the behaviour changed, from `qa/NN-<case>-before.txt` and `-after.txt` |

Inline only the lines a reader needs to see the point; the full file is one link away. Link into
`qa/` relatively: `qa-tester` keeps that folder. A screenshot you take yourself for the note goes in
`shots/NN-<step>.png`, next to it.

### Where it goes

The note goes in the run's folder, next to `qa/`, resolved from the **main checkout**, never from a
worktree, so a worktree cleanup cannot delete it. For a `writeups/` folder in the main checkout,
this resolves to the right folder from the main checkout and from any worktree alike:

```bash
WRITEUPS="$(dirname "$(git rev-parse --path-format=absolute --git-common-dir)")/writeups"
NOTE="$WRITEUPS/changes/<date>-<run>/walkthrough.md"
```

The note is never committed and never pasted into a PR, unless the user asks. It is never an HTML
page or an artifact unless the user asks. Report its path when done.

## 3. For customers

The goal is one HTML file the user can send on, showing only what a customer will notice, with every
claim verified and no internal or personal data in it. It goes in the same drafts folder as above,
as `releases/<version>/walkthrough.html` with its screenshots in `releases/<version>/shots/`, and is
never committed or published unless the user asks.

It is for releases a customer sees in the product's UI: web, native or mobile. A release with no
visible change (an API, a CLI, a library) gets no page: say so, and point to its release notes.

Confirm the release and its scope with the user before building anything. A release note is a
starting point, not the scope. If a state needs staging you cannot do (a second account, a plan
change, a backend lever), name it and ask once, with the exact commands. When staging is refused,
say what the page will not cover; do not quietly reshape it around the states you could reach.

Read `references/customer-release.md` before building anything: what to show, capturing, the
evidence each sentence needs, the page, the scripts that capture, inline and verify it, and the
hand-off.

If `local.md` exists next to this file, read it; where it disagrees with this file, it wins.
