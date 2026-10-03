---
name: thorough-diff-review
description: "Thorough local review of a diff: bugs, architecture boundaries, security, translations, conventions, reuse. Staged changes by default, or a branch, range or PR."
when_to_use: "Use before pushing, or when asked to review local changes, a branch or a PR."
---

# Thorough diff review

Run the same checklist the CI reviewer uses, locally, before pushing. This is the local analogue of
the repo's automated review workflow, with one source of truth: the review checklist file.

## Repo facts

This skill needs the facts below. Look each one up in the repo's CLAUDE.md (or AGENTS.md) and
the files it imports or points to, then in `local.md` next to this file. If neither has it, ask
the user once, then suggest the one line to add to CLAUDE.md so the next run finds it.

| Fact | Example |
| --- | --- |
| Review checklist file | `docs/review-checklist.md` |
| Convention docs or skills to read for each touched area | a forms skill, a schemas skill |
| Architecture rules and the tool that enforces them | layers import only downward, boundary linter |
| Shared utilities to reuse before writing new ones | `src/lib` (logger, validators) |
| The full check command | `pnpm check` |
| Unit test command | `pnpm test` |
| e2e command and when it's required | `pnpm e2e`, only on release PRs |
| Translation check and generate commands, if the repo has translations | `pnpm i18n:check`, `pnpm i18n:gen` |

## 1. Resolve the diff scope (from args)

- no args / "staged" → `git diff --staged`. If nothing is staged, say so and stop; do not guess.
- a branch name → `git diff <branch>...HEAD`
- "last commit" → `git show HEAD`
- a commit range `a..b` → `git diff a..b`
- a PR number or URL → `gh pr diff <n>`

## 2. Read the real code, not just the diff

The diff is the entry point, not the boundary. For each change, read the surrounding full files and
the related code that could DISPROVE a finding: callers, the definitions of the functions and types
it uses, validators, existing patterns. Judging from changed hunks alone is the #1 source of false
positives. Ground every finding before asserting it; if you cannot verify it, raise it as a
question, not a defect.

## 3. Run the checklist

Walk every section of the review checklist and evaluate every changed file against it. When the
change touches an area with convention docs or skills (a schema, a form, a mutation, a query key, a
message catalog, a file's name or location), read the matching one and flag any violation.

Reuse before re-implementing: before flagging duplicated logic, check whether a shared utility from
Repo facts already exists that the change should have reused.

A UI change is reviewed in its loading, empty, error and success states; a data-driven screen
without that state matrix, or tests that skip it, is a finding.

## 4. Architecture boundary violations

Check that imports respect the layer rules from Repo facts. Flag any upward or cross-slice import
and propose the fix the repo's rules prescribe.

## 5. Impact check

For a diff you can't prove safe by reading alone (shared code, a data or wire format, timing and
teardown, a library upgrade), run `impact-check` and bring back its premise and the evidence label
that premise reached: `run`, `read` or `assumed`. Skip it for a diff that is safe on its face.

## 6. Output

Report findings directly in the conversation (no report file unless asked). Group by severity:
Blocker, Major, Minor, Nit. These four names are the whole set; never write Critical, High, Medium,
Low or Warning. Cite `file:line` and give a concrete fix. Do not invent issues to fill space; if
the diff is clean, say so briefly.

For a risky diff, a **Safe because** line: the fact and the ladder step it reached, or `unproven`.

## 7. Verify gate (before calling the change done)

- Run the full check command. Every stage must pass; a single red stage is a red gate.
- Run the unit test command. A changed component whose spec no longer covers its states is not done.
- If the diff touches translation catalogs, run the translation check too; it may be a separate
  gate outside the full check. Authors translate new or changed strings before pushing; CI only
  verifies. Flag hand-mirrored source-language text in another language's file: an identical-text
  check treats it as untranslated. A new namespace or validation key needs the generate command, so
  generated types, loaders and fallbacks are regenerated.
- Run the e2e command only when Repo facts says this diff requires it.

If `local.md` exists next to this file, read it; where it disagrees with this file, it wins.
