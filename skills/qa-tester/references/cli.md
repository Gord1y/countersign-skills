# CLI and scripts

Commands run the way a user runs them, saved as terminal transcripts.

## Repo facts for this surface

| Fact | Example |
| --- | --- |
| How each command is invoked from a checkout | `pnpm cli <command>`, `./install.sh`, `bin/<tool> <args>` |
| What it reads or writes outside the repo, and how to point it elsewhere | `~/.claude/settings.json`, through `HOME` |

## Tools

Bash. These commands are yours to run: they exit on their own. A command that writes outside the
repo runs against scratch copies, never the user's real files: a scratch `HOME` under `$SCRATCH`,
or the command's own flag for its config path. When nothing isolates it, run
only its read-only and dry-run paths, and mark the rest BLOCKED with the reason.

## The loop for a command

Run each case that writes files in a fresh scratch folder. Assert the exit code, stdout, stderr and
the files it wrote or left alone. Running the same command a second time shows whether it is
idempotent.

## Evidence

One `NN-<case>.txt` per case: the command as typed, its stdout and stderr interleaved (`2>&1`), and
the exit code last.

```
$ HOME=<scratch> ./install.sh --no-settings
linked  <scratch>/.claude/skills/qa-tester
ok      <scratch>/.claude/CLAUDE.md
exit=0
```

- Shorten scratch paths to a placeholder such as `<scratch>`, and replace anything secret with
  `<redacted>`.
- When files are the outcome, append `ls -la` or a `diff` of them to the same transcript.

## Cases worth covering

- **Usage:** `--help` exits 0; an unknown flag or a missing argument exits non-zero with a readable
  line on stderr.
- **Happy path, then again:** the second run is idempotent or says plainly that it has nothing to
  do.
- **Every changed flag and subcommand**, and the dry-run path if there is one.
- **Failure paths:** a missing input file, an unreadable path, a missing dependency, a run that was
  interrupted halfway.
- **What it must not touch:** files outside its scope are unchanged afterwards.

## Teardown

Nothing of its own: the scratch homes go with `$SCRATCH`.
