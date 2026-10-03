# Library

Scratch scripts against the public API, the way a consumer uses it.

## Repo facts for this surface

| Fact | Example |
| --- | --- |
| The package's public entry points | `import { parse } from "@acme/core"` |
| How to build it, and what the build produces | `pnpm build`, into `dist/` with type declarations |

## Tools

The language runtime and the repo's build. Write each script in `$SCRATCH` and import the package
through its public entry, as a consumer would (its built output or package name), never
through an internal file a consumer can't reach.

## Before and after

When the change alters behaviour, run the same script against the base as well, from a detached
worktree:

```bash
git worktree add --detach "$SCRATCH/base" <base>
```

`git worktree` runs outside the sandbox. Install and build there exactly as in the checkout, run the
script against each, and keep both outputs.

## The loop for a library

One script per case. It prints exactly what the case asserts on, asserts it too, and exits non-zero
on a mismatch.

## Evidence

- `NN-<case>.<ext>`, the script itself, copied into `$QA`.
- `NN-<case>.txt`, its transcript: the command, the output, `exit=<code>` last.
- `NN-<case>-before.txt` and `NN-<case>-after.txt`, for a before-and-after case.

## Cases worth covering

- **Each changed export:** typical input, its boundaries, and invalid input with the error type and
  message a consumer catches.
- **Types:** when the package ships types, a consumer's type check of the script passes against
  them.
- **Compatibility:** code written against the base still runs, unless the change is declared
  breaking.
- **The public surface:** nothing internal became reachable from the entry points.

## Teardown

Remove the base worktree with `git worktree remove --force "$SCRATCH/base"` before `$SCRATCH` is
deleted: deleting the folder alone leaves git a stale worktree entry.
