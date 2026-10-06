---
name: release-notes
description: "Write or update a release note: entry format, required sections, the Fixed rule, and regenerating the release index."
when_to_use: "Use when asked to write or update a release note or changelog entry, and before reporting work on a release branch as done, so its open note covers every commit."
effort: medium
---

# Release notes

**A repo's own copy wins.** If the repo ships its own `release-notes` skill (for example
`.claude/skills/release-notes/SKILL.md`), follow that file instead of this one.

## Repo facts

Look each fact up in the repo's CLAUDE.md (or AGENTS.md) and the files it points to, then in
`local.md` next to this file. If neither has it, ask the user once and suggest the CLAUDE.md line
that records it.

| Fact | Example |
| --- | --- |
| Where release notes live (folder and contract doc) | `releases/release-<semver>.md`, with the contract in `releases/README.md` |
| Where uncommitted drafts go | a gitignored `writeups/` folder in the main checkout |
| Branch flow | feature → `release-<semver>` → `staging` → `main` |
| Validator and index commands | `scripts/release-index.sh` regenerates the index, `scripts/release-index.sh --check` verifies it |
| What CI generates from release notes | the index check on every PR; a change-management record when a PR merges to `main` |
| Who reads the notes | customers through a public changelog, auditors, the internal team |
| Entry format and field limits | frontmatter fields, their limits and the required body sections, from the validator or the releases README |
| Paths whose changes never get an entry | `test/**`, `e2e/**`, `.storybook/**`, test runner configs |
| Where the notes are rendered and which fields readers see | a marketing site that shows title, summary, highlights and tags, never the body |
| Jargon banned from reader-facing text | library names, internal query languages, rendering terms |
| Commit type for release notes | `docs(release): …`, with `release:` reserved for promotion merges |
| Version bump convention | the `package.json` bump as its own `chore:` commit |
| Does the repo tag releases? | no: the version lives in `package.json`, the filename and the branch name |

What CI generates on its own is not written into the note. If this skill, the releases README and
the validator disagree, the validator wins.

## Steps

1. Copy the newest note to keep the frontmatter shape, as `release-<semver>.md` (valid semver).
2. Edit the frontmatter and the body (rules below).
3. Run the index command, then commit **both** the note and the index.
4. The index check must pass.

## An open note keeps up with its branch

Nothing fails when an open note falls behind, and a later reader cannot tell a deliberate omission
from a forgotten one. So **a commit that changes behaviour, tooling, configuration or a shipped
document updates the note, in the same commit or the next one.** Reconstructing entries from a
diff later is how invented ones get in.

**Before reporting work on a release branch as done,** list every commit since the note was last
touched, and give each one an entry or a reason it has none. Check the list, don't recall it:

```bash
NOTE=<notes folder>/release-<semver>.md
git log --oneline "$(git log -1 --format=%H -- $NOTE)..HEAD"
```

A new file or capability is `Added`, a change to something shipped is `Changed`, and `Fixed` only
if it was broken in the previous released version. Only two kinds of commit need no entry: test
infrastructure, stories and CI-only changes (the "never get an entry" row; specs that pin what the
release is about still earn an `Added` entry), and commits that only edit the note or its index.

## Entry format

The validator rejects a note missing a required field; the body is not indexed.

- **`type`** judges significance, not the digit that moved: a patch-numbered release with a
  capability people will notice is `minor`, a minor-numbered one that opens a new area is `major`.
  `breaking` is independent: a `major` release that removes nothing is `breaking: false`.
- **A visibility flag**, if the contract has one (for example `hidden`): set it for tooling, CI,
  dependency and audit work, and leave it off for releases readers would notice. Keep it accurate
  even if no public surface reads it yet. A hidden note shows no fields, so the wording rules below
  don't apply to it.

```yaml
---
version: 1.4.0
date: 2026-07-20
title: Short human-readable title
summary: One or two sentences describing the release for readers.
type: minor
breaking: false
highlights: [Export invoices as CSV]
tags: [invoices, export]
---
```

## Reader-facing fields

Write every field as if a customer could read it. For a note readers can see, `title`, `summary`,
`highlights` and `tags` are plain customer language:

- No library, package or tool names, internal query languages, rendering jargon, or anything in the
  "Jargon banned" row.
- No code identifiers, API, schema or type names (`GET schema`, `nullable`, `enum`, `PATCH`), and no
  UI-component jargon (`entity`, `data-table`, `combobox`, `modal`).
- No developer abbreviations (`auth`, `UX`, `localization`): say "sign-in", "experience",
  "translations". No CI, tooling or dependency-patch detail; that goes in the body.

## Body sections

`## Added`, `## Changed`, `## Fixed`, `## Removed` and `## Security` are all required, in any order,
with `- None.` when empty. Every change goes in one of them by category, CI, tooling and workflow
fixes included. An optional `## Notes` may follow, only for what fits none of them: upgrade or
migration steps, a caveat about something left undone, why a breaking change breaks, context about
the commit history. No other sections: no commit or SHA listing, no generated records, no "lint
passes".

## What an entry says

**A bold lead that names the change, then at most one plain sentence on its effect.** A list of
changes, not the story of the work.

```markdown
- **Table headers announce their sort order to screen readers.**
- **Links to app pages in the invoices list open in the same tab.** A link to a page that does not exist shows as plain text.
- **The invoices page can export its rows as CSV.** Set `EXPORT_BUCKET` in the hosting settings to turn it on.
```

A `Fixed` entry names the defect as people met it and what happens now. Name a file, command, flag
or setting only when the reader must act on it. A change to agent skills, hooks, lint rules or CI
gets one line.

**Never in an entry:** how, when or by whom a problem was found, how often it happened or what it
cost; incidents, near misses, anything that happened only on one machine or in one session; branch
names, PR numbers, SHAs, dates of work; investigation, rejected alternatives, measurements of the
work itself; verification (tests, gates, "checked in the browser"); mechanism (function and file
names, call order); drafts and working notes, which go to the drafts folder, as
`releases/<version>/`.

A measurement stays when it compares this release with the previous one and a reader would care
(`sign-in page JavaScript 2.50 → 0.86 MB`). Before committing, reread every entry you touched and
cut each sentence a reader would not miss.

### `Fixed` means broken in the previous released version

Something broken and repaired inside this release never reached a reader: its `Added` entry already
states what ships. The question is never "did I fix something" but **"was it broken in the last
release"**. The last release is the tip of the last promoted branch (`main`, or `staging` when it is
ahead and promoted), from the remote. **Check, don't recall:**

```bash
git fetch origin
git cat-file -e origin/main:<path> && echo "existed before"   # was the feature even live?
git grep -i "<old wording>" origin/main -- '<source folder>'  # for copy, was the old text live?
```

If the file doesn't exist there, the feature is new and nothing about it belongs in `Fixed`. The
same test covers the words: `shipped`, `in production`, `used to`, `was returning`, `readers saw`,
`regression` and every before/after pairing are claims about the last release, and need the check.
Inventing a defect misrepresents a release as much as hiding one. `Removed` likewise means removed
from the last release, and a size comparison is measured against the last release, never against
the value before your own edit.

## Commits

- Commit the note and the regenerated index with the release-note commit type: writing a note and
  promoting a release are different acts.
- Bump the version and tag (or not) as the repo facts say; add no tags of your own.
- Never add an AI co-author, to a note's commit or anything else.

If `local.md` exists next to this file, read it; where it disagrees with this file, it wins.
