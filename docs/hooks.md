# Hook walls

`bin/harness-hook` is the one entry point for every wall that Claude Code and Codex enforce through
hooks. A wall is a small `sh` policy in `hooks/policy/`. Both providers run the same policies, and
one fixture table per policy runs every case through both providers' adapters.

`install.sh` links the entry point into `~/.local/bin` and merges the Claude hook entries from
`claude/settings.json`. When `~/.codex` exists it also merges `codex/hooks.json` into
`~/.codex/hooks.json`, after any entries already there. Codex skips those entries until you trust
them: start `codex` and pick "Review hooks" or "Trust all and continue". See
[docs/install.md](install.md#codex-settings).

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

### push

`hooks/policy/push.sh` replaces the blanket `git push` deny rules that `claude/settings.json` used
to carry. Pushing the current feature branch is free. The policy acts on `shell` calls only.

It first joins a backslash before a newline, cuts each line at an unquoted ` #` (a shell comment)
and drops the body of a `cat <<'EOF'` heredoc with a quoted delimiter, which is data (a commit
message that mentions `git push` stays allowed). It then splits the command into simple commands on
newlines, `;`, `&&`, `||`, `|`, `&` and parentheses, except the `(` of `$(`, so a command
substitution stays inside its segment. Each segment loses every quote and backslash and is split on
whitespace, so `feat-x:"main"`, `"ma"in` and `m\ain` all read as `main`.

Leading `VAR=value`, `env` (with no options), `command` and `exec` are skipped. A `GIT_DIR=` or
`GIT_WORK_TREE=` prefix, or an `env` with options (`-u`, `-C`, `-S`), makes the segment hidden (see
below). Then the first word decides:

- `git` or a path ending in `/git`: the precise parse. Git's global options (`-C`, `-c`,
  `--git-dir`, `--work-tree`, `--no-pager`, `-P`) come first, then `push`. `-C` directories and a
  preceding `cd` resolve against `cwd`. A `-c` whose key is `remote.*.push`, `push.*` or `alias.*`
  makes the segment hidden.
- `gh` or a path ending in `/gh`: the precise `gh` parse, below.
- Anything else: the hidden rule, below.

It denies a push when any of these holds:

- A flag rewrites or removes remote branches: `--force`, `-f` (also inside a cluster such as
  `-uf`), `--force-with-lease`, `--force-if-includes`, `--delete`, `-d`, `--mirror`, `--all`,
  `--prune`.
- A refspec starts with `+` or `:`.
- A refspec destination matches a protected pattern. The destination is the part after `:`, or the
  whole refspec, without `refs/heads/`. A destination with a `*` is treated as protected.
- There is no refspec, or the refspec is `HEAD`, `@`, or holds a `$(` or a backtick (the branch is
  computed), and the current branch of the target repository
  (`git symbolic-ref --short -q HEAD`) matches a protected pattern, or HEAD is detached.
- A refspec holds a shell variable such as `$BRANCH`. Its value is unknown, so the policy denies it.

The protected patterns are `main`, `staging`, `release-*` and `release-hotfix*`. They sit in one
variable at the top of the policy.

One hidden rule covers every push the parse cannot see. A segment whose first word is not `git` or
`gh` is denied when it holds the word `git` and the word `push` anywhere, or the word `gh` with
`merge`, `api`, `auth` or `alias`. The reason names the segment's first word, and the agent is told
to run the command directly. This one rule covers `sh`, `bash`, `zsh`, `dash` or `ksh` with `-c` in
any flag order, `echo '...' | sh`, a heredoc into a shell, `xargs`, `find -exec`, `sudo`, `nice`,
`timeout 10`, `python3 -c`, `node -e`, `perl -e` and `eval`. A `git` segment with a `$(` or a
backtick keeps the precise parse, so
`git commit -m "$(cat msg.txt)" && git push` and `echo $(git rev-parse HEAD) && git push` pass.

`gh` runs outside the sandbox and is auto-allowed, so the hook is its only wall. The policy denies:

- `gh pr merge`, and `gh alias set` or `gh alias import` (an alias can rename `pr merge`).
- `gh auth token`, and `gh auth status` with `--show-token` or a short-flag cluster that holds `t`
  (`-t`, `-at`, `-ta`).
- A `gh api` call that writes and whose endpoint matches `rulesets` or `branches/*/protection`, or
  `git/refs`, `contents/`, `/merges` or `pulls/*/merge`. A call writes when `-X` or `--method` is
  anything but `GET`, or when it has `-f`, `-F`, `--field`, `--raw-field` or `--input` and no
  explicit `GET`. A read such as `gh api repos/o/r/rulesets -X GET -f per_page=1` passes.
- `gh api graphql` whose text holds `mergePullRequest`, `enablePullRequestAutoMerge`,
  `BranchProtectionRule`, `Ruleset`, `updateRef`, `deleteRef`, `createRef` or `updateRefs`, with any
  method.

Tags pass. A push of `v*` tags, or `git push --tags`, is not a branch push, and the release flow
pushes a tag after the release branch merges. A tag name equal to a protected pattern is the one
case that still denies.

Limits. The policy is a parse of one command string, not a shell. Git aliases defined in config
files, a script file that pushes, and text built from variables are not seen. The hidden rule
denies a harmless command that only names a push, such as `grep 'git push' docs`, and a `;` or `|`
inside a quoted string still splits the command. The sandbox and the repository rulesets stay the
floor: a force push or a push to a protected branch is still rejected by the rulesets on the
remote.

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

### pr-walkthrough

`hooks/policy/pr-walkthrough.sh` denies `gh pr create` when the PR changes a UI file and its body
has no walkthrough. UI files are those ending in `.tsx`, `.jsx`, `.vue`, `.svelte`, `.css`, `.scss`
or `.html`, under any path, found with `git diff --name-only <base>...<head>`. The base and head
resolve as in `pr-size`, and a command that cannot be resolved to a diff is allowed. Unlike
`pr-size`, a promotion head is not exempt.

A walkthrough is a section: a line containing `walkthrough` (any case) opens it, a line starting
with `#` closes it, and an open line with an `http://` or `https://` URL passes. So
`Walkthrough: <url>` passes, and so does a `## Walkthrough` heading over screenshot lines, which is
the record of every changed state in light and dark. The test reads the whole command text, then
the body file named by `-F`, `--body-file` or `--body-file=` (relative to `cwd`, `-` skipped).
`--fill` alone never passes on a UI change.

When denied, add a `## Walkthrough` section with the screenshots, or a link to a walkthrough that
shows them (the `walkthrough` skill builds one), then create the PR again.

### gate

`bin/gate` runs the repo's own gates and stamps the exact working tree it checked.
`hooks/policy/gate.sh` blocks a stop (`Stop` and `SubagentStop`) while the work differs from its
base and the current tree has no stamp.

The gate line is the first line of the form `gate: <command>` under `## Gates` in `CLAUDE.md` at the
repo root, or in `AGENTS.md` when there is no `CLAUDE.md`. Fenced code blocks are skipped, and a
`gate:` line under another heading does not count. `bin/gate` runs the command from the repo root
through `sh -c`, prints the last 60 lines of its output, and keeps the full output in
`<git-dir>/countersign/gate.log`.

| Exit | Meaning |
| --- | --- |
| 0 | The gate passed and the tree is stamped |
| 1 | The gate command failed; no stamp |
| 2 | Not a git repository, a wrong argument, an unhashable tree or an unwritable folder |
| 3 | No gate line; the message names the exact line to add |
| 4 | The gate passed but changed the tree while it ran; no stamp |

An exit 4 means the gate writes files that are neither ignored nor committed. Ignore or commit them,
then run `gate` again.

#### The tree hash

The hash is `git write-tree` over a temporary copy of the real index (`cp -p`, so git's racy-stat
check still sees the original timestamp) after `git add -A`. It covers committed, uncommitted and
untracked files that are not ignored, and never touches the real index. Because the copy carries
the stat data, only changed and untracked files are rehashed: about the cost of one `git status`
(inferred, not measured on a large repo). Untracked blobs land in `.git/objects` as loose objects,
which `git gc` prunes. The temporary index is removed on exit, `INT` and `TERM`.

`.claude/worktrees` is excluded from the hash, because builders' worktrees live there and are
nested repositories. Any other untracked nested repository counts as a change: adding one makes the
tree differ. A dirty submodule is not held, since only its `HEAD` commit is hashed.

A stamp is the file `<common-git-dir>/countersign/gate/<tree-hash>`, shared by all worktrees of a
repo. A commit keeps the tree, so a stamp survives it, and a builder's stamp is valid in the main
checkout once the orchestrator lands the same changes.

#### Who is held

The base is the tree a stop must differ from.

- A builder (a `SubagentStop` in a linked worktree) is held against `HEAD`'s tree, so any
  uncommitted change needs a stamp. A subagent in the main checkout (the read-only ones) passes.
- The main session is held against the tree recorded at its first tool call, in
  `<git-dir>/countersign/sessions/<session_id>`. A session that changed nothing, or only answered,
  never blocks. A stop before any tool call records the base and passes. A session id with other
  characters than letters, digits, `.`, `_` and `-`, or starting with `.`, is not held. Files older
  than 30 days are removed from the sessions folder. Parallel first tool calls publish the base
  with a hard link, so the first one wins.
- A `cwd` outside a git repository, and any failure to hash, pass.

The base is the tree at the session's first tool call, so any later change to the tree counts as the
session's own, including another session's edit or a pull. The wall cannot tell them apart. It caps
the cost at one block per session, provider and tree, by writing
`<git-dir>/countersign/sessions/<session_id>.<provider>.<tree-hash>.blocked`: the next stop on the
same unstamped tree passes, and a new tree blocks again. The same marker applies to a builder, so a
subagent whose worktree tree is unstamped gets one block per tree. A block also happens once per
stop chain, as for every wall (see The stop loop). When a turn reports nothing as done, ending it
again passes.

A repo with no gate line is not blocked for good: the main session gets one block per session and
provider that names the line to add, then passes. The marker is
`<git-dir>/countersign/sessions/<session_id>.<provider>.told`. A builder gets the message once per
tree, like any block.

#### Unverified

Whether a builder's `SubagentStop` payload carries the worktree as `cwd`. If it carries the main
checkout, builders pass unheld (the wall fails open). Check it once live after install.

### scope

`hooks/policy/scope.sh` fences the edit tools of a builder's worktree to the slices of the approved
plan that its batch carries. The orchestrator runs `plan-lint fence <plan> <slice>...` from the
checkout that lands the work, before it spawns the batch, and `plan-lint unfence` at the end of the
run (`skills/orchestrate/references/plan-contract.md`).

`fence` verifies the plan's approval first, then writes one scope file per fencing checkout:
`<git-common-dir>/countersign/scope.d/<cksum of the checkout's physical path>`. Its tab separated
lines are `plan` (the plan's physical path), `approved` (the plan's hash), `home` (the fencing
checkout), one `allow <ERE>` per `Scope:` glob of the fenced slices and one `named <ERE>` per
`Sensitive:` glob. `unfence` removes only its own checkout's file, and the folders when they end
up empty, so two runs from two checkouts do not disturb each other.

The wall reads `paths`, like `write`, and fences by target, not by the session's `cwd`. A path that
resolves (symbolic links followed) to `<home>/.claude/worktrees/agent-*/...` is judged by the
`scope.d/` file whose `home` is that `<home>`, relative to that worktree. A fence therefore reaches
the builders of the checkout that fenced, which the harness names `agent-*`, and no other linked
worktree of the repo, not even one under the same `.claude/worktrees/`, which may be a parallel
session.

The reason is Codex. It has no `builder` agent, so each unit of an orchestrated run is built in a
worktree named `agent-codex-<NN>` (`skills/orchestrate/SKILL.md`), and its session runs in the main
checkout. A wall that judged only paths inside the session's top level would never see those
writes. Fencing by target holds them to the slice, whatever the `cwd`, while a path outside every
agent worktree, such as work going on in the main checkout, is never judged by this policy. A path
inside an agent worktree is denied in two cases, both with exit 10:

- No `allow` or `named` pattern matches its path relative to the top level:
  `scope denied: <path> is outside the approved plan's scope for this batch (<plan>). Return to
  planning: stop, and report the file and why the unit needs it.`
- It is a sensitive surface that no `named` pattern matches: `scope denied: <path> is a sensitive
  surface (<kind>) that the approved plan names no line for (<plan>). Return to planning: stop, and
  report the file and why the unit needs it.` A `Scope:` glob alone never opens a sensitive
  surface; the slice needs a `Sensitive:` line for it.

The last three kinds match the file's basename. Every kind matches without regard to case, so
`src/Package.json` and `src/.ENV` are sensitive on a case-insensitive file system too.

| Kind | Matches |
| --- | --- |
| `migrations` | `migrations/*`, `*/migrations/*` |
| `CI workflow` | `.github/workflows/*` |
| `ruleset` | `.github/rulesets/*` |
| `i18n source keys` | `messages/en.json`, `locales/en/*`, at any depth |
| `dependencies` | Manifests and lockfiles, such as `package.json` and `go.mod`; see `scope.sh` |
| `env and config` | `.env`, `.env.*`, `*.config.*`, `settings.json`, `settings.local.json` |
| `API contract` | `openapi.*`, `*.openapi.*`, `swagger.*`, `*.graphql`, `*.gql`, `*.prisma` |

A path outside every agent worktree is `write`'s to judge. The wall allows, and fails open, when
`paths` is empty, the path is not inside an `agent-*` worktree of a checkout that fenced, the
folder is not a worktree's top level, no scope file applies, the plan file is gone, or the plan's
last `Approved:` hash differs from the `approved` line. A plan
that is approved again after the fence therefore opens it, since the new stamp is no longer the one
that was fenced. An edit without a new approval keeps the stamp, so the fenced globs still hold.

A target that is a symbolic link is followed (up to 8 links) and its destination is judged, so a
link inside `src/` that points at `lib/a.ts` is denied as `lib/a.ts`. A link that points outside
every agent worktree is left to `write`.

#### Limits

- The fence reads edit tools only. A builder can still write through the shell, and can write the
  scope file itself; the sandbox is the floor.
- The main checkout is never fenced, so a path there is judged by `write` alone, from any session.
- Route-handler types are not globbable. The conformance review covers them.
