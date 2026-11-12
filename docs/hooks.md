# Hook walls

`bin/harness-hook` is the one entry point for every wall that Claude Code and Codex enforce through
hooks. A wall is a small `sh` policy in `hooks/policy/`. Both providers run the same policies, and
one fixture table per policy runs every case through both providers' adapters.

`install.sh` links the entry point into `~/.local/bin` and merges the Claude hook entries from
`claude/settings.json`. The Codex side (`~/.codex/hooks.json`) is installed separately.

## The flow

```
provider JSON on stdin
  -> hooks/adapters/<provider>.sh   (provider JSON to the neutral event)
  -> bin/harness-hook               (resolves paths, then runs hooks/policy/*.sh in name order)
  -> first policy that exits 10     (deny or block, printed in the provider's JSON)
```

1. The entry point finds the repo through its own resolved symlink path, so a link in
   `~/.local/bin` works.
2. The adapter turns the provider payload into the neutral event below.
3. The entry point makes every path absolute against `cwd`, normalises it lexically (`.`, empty
   segments and `..`, no symlinks) and sorts and de-duplicates the list.
4. Each `hooks/policy/*.sh` reads the event on stdin. The first one that exits 10 wins: its stdout
   becomes the reason the model sees.
5. Both providers accept the same deny JSON for a tool call
   (`hookSpecificOutput.permissionDecision: "deny"`) and the same block JSON for a stop
   (`decision: "block"`), so the entry point prints them and the adapters only read.

## The neutral event

One JSON object. Every key is always present, as `""`, `[]` or `false` when it has no value.

| Key | Type | Meaning |
| --- | --- | --- |
| `provider` | `claude` or `codex` | Who sent it |
| `event` | `pre_tool` or `stop` | `SubagentStop` is a `stop` with `subagent` true |
| `tool` | `shell`, `edit`, `other`, `none` | `none` for a stop |
| `tool_name` | string | The provider's raw tool name |
| `command` | string | The shell command, `""` for other tools |
| `paths` | array of absolute strings | Files an edit writes |
| `cwd` | absolute string | The session's directory. An event without one is ignored |
| `session_id` | string | The provider's session id |
| `subagent` | boolean | The stop comes from a subagent |
| `stop_hook_active` | boolean | A stop hook already blocked this stop chain |

Claude: `Bash` is `shell` (`tool_input.command`). `Edit`, `Write`, `MultiEdit` and `NotebookEdit` are
`edit` (`tool_input.file_path`, or `notebook_path`). Any other tool is `other`.

Codex: `Bash` is `shell` (`tool_input.command`, joined with spaces when it is an array).
`apply_patch` is `edit`, and `tool_input.command` holds the patch: the paths come from its
`*** Add File:`, `*** Update File:`, `*** Delete File:` and `*** Move to:` lines. A patch sent
through the shell (`apply_patch <<'EOF'` or `apply_patch '*** Begin Patch ...'`) arrives as `Bash`,
so a command with `*** Begin Patch` anywhere in a line gets the same paths. Markers may be
indented, and leading whitespace is trimmed from each path. A write fence therefore reads `paths`
for every tool.

Sources: the Claude Code hooks reference (code.claude.com/docs/en/hooks) and the Codex source at
`rust-v0.159.3` (`codex-rs/hooks/schema/generated/`, `hooks/src/events/`,
`core/src/tools/handlers/`). Unconfirmed: the `notebook_path` and `MultiEdit` field names on
Claude, and whether Codex caps repeated Stop blocks (Claude caps them at 8).

## Adding a policy

1. Write `hooks/policy/<name>.sh` with `#!/bin/sh`. It reads the event on stdin.
2. To deny or block, print the reason on stdout and `exit 10`. Any other exit allows.
3. Write `hooks/fixtures/<name>.tsv`. `scripts/test-hooks.sh` fails for a fixture without a policy.
4. If a row needs a state, write `hooks/fixtures/<name>.sh` (see below).
5. Run `scripts/test-hooks.sh`. It sends every row through `bin/harness-hook claude` and
   `bin/harness-hook codex`, in a fresh git repository named after the case.

Fixture columns, tab separated, with a header line. A row has exactly six fields and none is empty:
use `-` for none. The test fails a row with any other shape, an unknown `event`, `tool` or `expect`,
a stop whose `input` is not `active` or `-`, an edit without a path, or a case name used twice.

| Column | Values |
| --- | --- |
| `case` | A unique name; the row's directory |
| `event` | `pre_tool`, `stop` or `subagent_stop` |
| `tool` | `shell`, `edit` or `-` |
| `input` | The command; or space-separated paths (relative to the row's cwd, absolute, or `~/` for the row's home); or for a stop, `active` or `-` |
| `setup` | A state name for the setup script, `-` for none |
| `expect` | `allow` or `deny` (a deny of a stop means a block) |

A Claude edit with several paths becomes several `Edit` calls, a Codex one becomes one
`apply_patch`; any deny denies.

Every row gets its own home, `<work>/homes/<case>`, created empty. The hook runs with `HOME` set to
it and `XDG_CONFIG_HOME` set to `<home>/.config`, for both providers. A path in `input` that starts
with `~/` expands to that home. A shell command is passed as it is.

The setup script is `hooks/fixtures/<name>.sh`, optional. For a row whose `setup` is not `-`,
`scripts/test-hooks.sh` runs `sh hooks/fixtures/<name>.sh <state> <row-dir> <row-home>` from the
row's directory, a fresh git repository. The script builds the state: it may commit, branch and add
worktrees. A non-zero exit, or no script, fails the row as an unknown or broken state. The script
may print one line on stdout, the cwd for that row, absolute or relative to the row directory; an
empty line means the row directory. The test's own state `block-stop` (a file `block-stop` in the
row directory) is for the frame rows and needs no script.

`HARNESS_HOOK_POLICIES` points the entry point at another policy folder. The tests use it to run a
policy of their own, so no test-only policy ships in `hooks/policy/`.

## Fail open

A broken wall must never block work. The entry point allows, silently or with one line on stderr,
when:

- `jq` is missing (one stderr line, `harness-hook: jq not found, walls off`), the provider argument
  is wrong, or the adapter or policy folder is missing.
- The payload is not JSON, is not an event it knows, or has a `cwd` that is not absolute.
- A policy exits with anything but 0 or 10 (it writes `harness-hook: <file> exited <n>, allowed`).
- The hook entry in `claude/settings.json` finds no executable `~/.local/bin/harness-hook`.
- The entry point itself fails after its early checks: an exit trap turns any failure, such as a
  `jq` error while it prints a deny, into exit 0. Claude Code blocks on exit 2, which `jq` returns.
- A hook times out (a non-blocking error, inferred from the Claude docs).

There is no per-policy timeout. The provider's hook timeout bounds the whole run (15 s for
`PreToolUse`, 30 s for `Stop` and `SubagentStop`), and a timeout allows. A policy that can run long
must stay inside that bound by itself.

Exit 10 is the only deny code. It avoids 1, which `set -e` produces by accident, and 2 and 5, which
`jq` produces. The sandbox and the repository rulesets stay the floor; a wall only adds to them.

## The stop loop

A stop that is already inside a block (`stop_hook_active` true) is always allowed, before any policy
runs. A policy that blocks a stop therefore blocks it once per stop chain and can never loop.

## Codex limits

Codex does not pass a tool call's `workdir` to the hook, so `cwd` is the session's directory. A
command that runs elsewhere with `cd` or `workdir` is judged against the session's directory.

## Walls

### pr-size

`hooks/policy/pr-size.sh` denies `gh pr create` when the PR changes more than 400 lines against its
base. It counts added plus deleted lines from `git diff --numstat <base>...<head>`. The base is
`--base`, else the remote default branch, else `main`, and `origin/<base>` is preferred when it
exists. The head is `--head`, else the current branch. A command that cannot be resolved to a diff
is allowed.

Excluded from the count, because they are produced or translated, not reviewed line by line:
lockfiles (any file name containing `lock`), paths with a `generated`, `dist` or `__generated__`
segment, `.snap` files, binary files, and translated catalogs (`messages/*.json` and
`locales/*/*.json`). The source locale (`en.json`, `locales/en/`) counts, since a person writes it.

A head named `main`, `staging` or `release-*` is a promotion PR and is never capped.

When denied, split the work into stacked PRs of 400 lines or fewer, each reviewable and green on its
own, and open the first one.

### write

`hooks/policy/write.sh` fences the edit tools (Claude `Edit`, `Write`, `MultiEdit`, `NotebookEdit`,
Codex `apply_patch` and a patch sent through Codex `Bash`) to the session's own git checkout. It
reads `paths`, so every tool is judged the same way. It acts only when `paths` is not empty, and it
allows when `cwd` is not inside a git repository.

Every path is resolved physically before it is compared: the deepest existing ancestor goes through
`pwd -P` and the missing rest is appended, so `/tmp` and `/private/tmp` (and `/var` and
`/private/var`) match on macOS. A path is allowed under:

| Place | Why |
| --- | --- |
| The checkout's top level (`git rev-parse --show-toplevel` of `cwd`) | The work itself. A builder's worktree is its own top level. |
| `writeups/` of the main checkout, when `cwd` is in a linked worktree | Evidence files belong in the main checkout, not in a throwaway worktree. |
| `~/.claude/plans/` and `~/.claude/projects/` | Plans, handoffs and Claude's auto memory. |
| `/private/tmp/claude-<uid>/` and `/tmp/claude-<uid>/` | Claude's session scratchpad. |
| `$TMPDIR`, when set | Throwaway files from tools that honour it. |

A place that contains the checkout's top level is not honoured. A session whose repo lives inside
the scratchpad or `$TMPDIR` (the hook tests do) is fenced to its repo, not to its siblings.

Anything else is denied with `write denied: <path> is outside this repo (<top>). Write inside the
repo, ~/.claude/plans, the scratchpad or writeups/.`

#### The worktree-only list

A repo can be edited only from a worktree when its main checkout is listed in
`${XDG_CONFIG_HOME:-$HOME/.config}/countersign/profile/worktree-only.tsv`. The file holds one
absolute path per line, the repo's main checkout; a leading `~/` is the home directory. Blank lines
and lines starting with `#` are skipped, and a missing file lists no repo.

When the session's top level is a listed main checkout, every path under it is denied with
`write denied: <top> is worktree-only. Work in a worktree under .claude/worktrees/.` A linked
worktree of that repo is not the main checkout, so it is fenced like any other repo. The other
allowed places stay open.

`countersign-profile` stays off the list: its release branch is the live profile, so its main
checkout is where its edits take effect.

#### Limits

- The fence reads edit tools only. Shell writes are the sandbox's job, and the wall does not parse
  shell commands, apart from a patch in a Codex `Bash` command, which the adapter already turns
  into `paths`.
- A symbolic link as the last path segment is not followed. A link inside the repo that points out
  of it is allowed.
