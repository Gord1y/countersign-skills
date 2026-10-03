---
name: memory-review
description: Sort Claude Code's auto memory by the memory rule - preferences into rules, project knowledge into repo docs, progress deleted. Read-only until approved. Run with /memory-review.
disable-model-invocation: true
---

# Memory review

Memories are loaded into sessions and steer the work. A stale one is worse than none: it states
something that stopped being true with the confidence of a fact. A misplaced one hides knowledge
from the team: the memory rule (`rules/memory.md` in countersign-skills, imported by the global
instructions) says memory holds only how the user wants the agent to work. Cross-project
preferences belong in the rules, project knowledge in that repo's docs, and progress nowhere. This
skill sorts every memory by that rule and changes nothing without the user's approval.

## Where memories live

Each project's memory is `~/.claude/projects/<key>/memory/` (or under `$CLAUDE_CONFIG_DIR`), where
`<key>` is the project's absolute path with every character that is not a letter or digit turned
into `-`. It holds `MEMORY.md`, an index of one line per memory, and one file per memory with
`name`, `description` and `metadata.type` frontmatter. When the folder is a link into your memory
repo, review and commit there.

Scope: every project folder that has memory files, or only the projects the user names.

## Step 1: mechanical checks, no agents

For each project, read only the frontmatter and `MEMORY.md`, and list:

- an index line whose file is missing, and a memory file with no index line
- a file with missing or malformed frontmatter
- a `[[name]]` link to a memory that does not exist in that project
- a `project` memory whose content states a date, release or deadline that has passed
- a memory about progress: a plan, in-flight work, "waiting for X", or a feature that shipped
- the same preference in two projects' memories (a candidate for a rule)
- a memory that repeats the global instructions (`~/.claude/CLAUDE.md` and what it imports) or a
  skill almost word for word
- a project memory folder that is a plain folder while others are links into a memory repo (not
  adopted yet)

## Step 2: one read-only agent per project

Spawn one `Explore` agent per project with a memory folder, `model: "sonnet"`, at most four at a
time, in one message. Brief each with the project's repo path and its memory folder, and ask for:

- every memory, one verdict:
  - **rule:** a preference true in every project. Name the rule file (a rule module, or the
    profile's `CLAUDE.md`) and give the exact lines to add, without the story.
  - **docs:** project knowledge (a decision, a domain term, a gotcha, an infra quirk). Name the
    repo doc for its area, or `docs/decisions.md` when none fits, and give the exact text. When
    the repo is public and the fact is private, the verdict is keep instead.
  - **delete:** progress, a shipped feature, something stale, or something already written in
    the repo, a rule or a skill (name where).
  - **keep:** personal feedback about this project that can't go in its repo, or a pointer to a
    system outside the repo.
  - **update:** a keep whose text is wrong, with the exact replacement.
- the evidence for each verdict: the file, line, command output or git state that shows it,
  checked now, never recalled
- concrete claims checked against the repo: files, functions, flags, scripts and settings still
  exist; rules still match `CLAUDE.md`, `CONTRIBUTING` or the rules folder; branches, releases and
  pull requests are in the state the memory says
- at most 30 lines back, no file contents, and never anything from `.env` files or other secrets

## Step 3: one report, then only what the user approves

Show one table per project: memory, verdict, evidence, and for rule, docs or update the proposed
text and where it goes. Ask once, for the whole table, which lines to apply. Apply exactly those:

- **rule:** add the lines to the named rule file and commit them in the repo that holds it, then
  delete the memory.
- **docs:** write the text into the named doc and commit it in that repo on the branch the user
  names (else the checked-out branch, as its own commit), then delete the memory.
- **delete:** remove the file and its index line, and remove `[[name]]` links to it from the
  others.
- **update:** rewrite the file, keep its frontmatter, and refresh its index line if the
  description changed.

Deleting a memory means removing its file and index line and the `[[name]]` links to it. In a
memory repo, commit once per review, for example `chore: review memories for <projects>`, with
the reviewed memory folders as the pathspec: `git commit -m "<message>" -- <folder> ...`.
Sessions in other projects share the repo and may have staged their own changes, and a bare
`git commit` takes those too. Never push unless asked.

If `local.md` exists next to this file, read it; where it disagrees with this file, it wins.
