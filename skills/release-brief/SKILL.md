---
name: release-brief
description: "Write the UX probe's release brief: what changed for users since the last probed ref, in user terms only, with no paths, code names, selectors or click paths."
when_to_use: "Use when a release asks for the UX probe's brief, or when asked to brief the probe on what changed. Not for release notes, changelogs or PR descriptions."
effort: medium
---

# Release brief

The UX probe is a separate session that works in its own folder, outside every repo, and sees the
product only through a browser. The brief tells it what changed so it knows where to look. One
rule is hard: user terms only. No file paths, component or code names, selectors, URLs below the
product's base URL, or click paths. The probe finds its own way.

## Repo facts

Look each fact up in the repo's CLAUDE.md (or AGENTS.md) and the files it points to, then in
`local.md` next to this file. If neither has it, ask the user once and suggest the CLAUDE.md line
that records it.

| Fact | Example |
| --- | --- |
| UX probe folder (absolute path) | `~/qa-probe/<product>` |
| Product base URL on the local stack | `http://localhost:3000` |
| Product name as users know it | `Shop` |
| Where release notes live | `releases/release-<semver>.md` |
| Brand and product words that look like code, passed to the lint with `--allow` | `QuickBooks`, `iPhone`, `PayPal` |

## 1. Find the range

Read `last-ref` in the probe folder: one line, the full SHA the last probe run was briefed from.
The range is `<last-ref>..HEAD`.

With no `last-ref`, start from the last `v*` tag, else from the merge base with the default
branch. Say which in the report.

## 2. Read what changed

- `git log --format='%h %s%n%b' <range>`.
- `git diff --stat <range>`, and the diff of a file, only where the log leaves a change unclear.
- Each PR number named in a subject, such as `(#123)`, through
  `gh pr view <n> --json title,body --jq '.title, .body'`. Run `gh` as a command of its own.
- The release note for this version, when one exists.

Skip changes no user can see: tests, CI, docs, tooling, refactors. Count them for the report.

## 3. Past candidates

Read `verdicts.md` and `candidates.md` in the probe folder. A `confirmed` candidate whose id
appears in a commit message, PR body or release note in the range is fixed. List it. Candidate
ids look like `C-20261117-01`; the lint passes them.

## 4. Write the brief

Write `briefs/<YYYY-MM-DD>-<short sha>.md` in the probe folder with the Write tool, since the
folder is outside the repo. Then copy it to `brief.md`. Use these headings verbatim:

```
# Release brief: <product> <version or date>

Base URL: <base URL>

## What changed
- <who can now do what, or what now behaves differently, in the words a user would use>

## Fixed since the last run
- <candidate id>: <what a user should now see>

## Look harder at
- <a broad or risky change, in user terms>
```

An empty section says `- Nothing this time.` Each bullet is one sentence.

Right register: "Members can no longer archive themselves; only an owner can." Wrong register:
"`ArchiveButton` is hidden for members in `settings/members.tsx`".

## 5. Self-check

Run `${CLAUDE_SKILL_DIR}/scripts/brief-lint <brief> --base-url <base URL>`, adding one
`--allow <word>` for each word in the Repo facts row of allowed words.

**Under Codex**: the script is `~/.agents/skills/release-brief/scripts/brief-lint`.

`--allow` takes a value of several words and allows each word, in any letter case. It clears a
flagged identifier, code word, path or selector token only when that token is a real product term.

Rewrite or delete every flagged line, then run it again until it exits 0. Then read the brief once
more for what no pattern catches: a screen or control named the way the code names it, a
step-by-step route, internal team or ticket names. Strip those too. Copy the clean file to
`brief.md` again.

## 6. Report

- The brief's path.
- The range and its commit count.
- Changes listed, and changes skipped as invisible.
- Fixed candidates.
- The lint result.

If `local.md` exists next to this file, read it; where it disagrees with this file, it wins.
