# Release notes

This page is the format every release note must follow: the file name, the frontmatter fields and
their limits, the body's sections and the commit that adds a note. Read it when you write or check
a release note.

Every countersign-skills release is one file here. The release workflow checks that the note for
the tag exists and that its `version` matches the tag. There is no generated index.

## File naming

`releases/release-<x.y.z>.md`, where `<x.y.z>` is the release's semver version and must match the
`version` field inside the file exactly.

## Frontmatter

Between two `---` lines, at the top of the file:

| Field | Type | Limit |
| --- | --- | --- |
| `version` | string | semver `x.y.z`, must match the file name |
| `date` | string | `YYYY-MM-DD`, a valid calendar date |
| `title` | string | at most 90 characters |
| `summary` | string | at most 400 characters |
| `type` | string | one of `major`, `minor`, `patch` |
| `breaking` | boolean | `true` or `false` |
| `highlights` | list of strings | 1 to 3 items |
| `tags` | list of strings | 0 to 5 items |
| `testedWith` | map | `claudeCode` and `codex` required, `antigravity` optional, each a version string |

Keep the frontmatter to a small YAML subset: plain, single-quoted and double-quoted scalar
strings, unquoted `true`/`false`, `- item` lists, and the one-level `testedWith` map. Nothing
checks these fields or limits yet: the release workflow reads only `version` and `title`, so
follow them by hand.

`type` says how big the release is for someone using these skills, not which semver number moved:
`major` for the first release or one that changes how you install or use them, `minor` for new
skills, rules or features, `patch` for fixes only.

Write an empty list as the key with nothing after it and no `- item` lines under it, not as
`tags: []`, which is outside the subset:

```yaml
tags:
```

## Body

`## ` sections, in exactly this order:

1. `## Added`
2. `## Changed`
3. `## Fixed`
4. `## Removed`
5. `## Security`

All five are required, and each must have content: write `- None.` when a section has nothing to
report for this release. No text is allowed before `## Added`.

After `## Security`, two more sections are optional, in this order if present:

6. `## Upgrading`: a manual step the release needs, such as re-running `install.sh` or reviewing a
   changed default in `claude/settings.json`.
7. `## Notes`: anything else worth calling out.

Nothing else goes in the body. The GitHub release body is this note's body, verbatim.

## Committing a note

A commit that adds a release note is `docs(release): add <x.y.z> notes`.
