## Safety

- **Never force-push, rebase pushed branches, or hard-reset shared work** — even if asked
  casually. Confirm the intent explicitly first.
- **Destructive operations** — deleting files or branches, `DROP`/`TRUNCATE`, `migrate reset`,
  `rm -rf` — ask first, or list them in a plan I approve, stating exactly what will be lost.
- **Checks write only local test data.** Browser, e2e and database checks may create data in a
  local dev environment when every record is prefixed `qa-` and deleted afterwards. Create it
  through the app's own API first, and SQL only for states the API can't produce. Never write to a
  shared or remote environment, and never trigger email, payments or anything that leaves the
  local stack. The exception to deleting is each project's standing local QA account, which the
  checks create once and keep.
- **Hands off secrets.** `.env` values, tokens, and credentials are never printed, logged,
  committed, hardcoded, or sent anywhere. A project's committed local QA password is not one of
  them: it opens only an account created on the local stack, and that account must never exist
  on a shared or production environment.
- **New dependencies need my sign-off,** in a plan I approve or by asking. Never add a package
  without it.
- **Mask config by key name.** When reading a settings or MCP config, print only the fields you
  need, and mask any value whose key names a token, key, secret or password, including inside
  argument lists, not only in URLs.
- **Act on the machine's current state.** Before `checkout`, `reset`, `branch`, `push` or
  starting a process, print the state first (`git branch -vv`, `git status`, the ports) and act on
  what it shows. Branch from a local base, never from a remote-tracking ref without `--no-track`.
  Never start, stop or restart a server that serves my working tree.
- **Worktrees.** Use the worktree's absolute path in every file write, and run
  `git status --short` afterwards to confirm only the intended file changed.
- **A denied command stays denied.** Never retry it in another form: finish the rest and hand me
  the exact commands in the closing summary.
- **Claude Code permission rules.** For files, only `Edit(path)` and `Read(path)` rules are
  consulted: `Edit` also covers Write, NotebookEdit and shell redirects, and a `Write(path)` rule
  is silently ignored. Never allow an interpreter or a shell by rule (`python3`, `node`, `sh -c`,
  `pnpm exec`), or "anything not denied"; make the narrow safe action free instead. Precedence is
  deny, then ask, then allow, so an `ask` rule carves an exception out of a broad `allow`.
