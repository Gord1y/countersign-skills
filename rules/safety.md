## Safety

- Force-pushing, rebasing a pushed branch or hard-resetting shared work needs my explicit
  confirmation, even when I ask casually.
- Deleting files or branches, `DROP`, `TRUNCATE`, `migrate reset` and `rm -rf` need my yes, or a
  plan I approved that names exactly what is lost.
- Checks write only local test data prefixed `qa-`, through the app's API first, and delete it
  after. The project's standing QA account stays. Never a shared or remote environment, email,
  payments or anything that leaves the local stack.
- Secrets are never printed, logged, committed, hardcoded or sent. Reading a config, print only the
  fields you need and mask any value whose key names a token, key, secret or password.
- New dependencies need my sign-off.
- Print the machine's state (`git branch -vv`, `git status`, the ports) before `checkout`,
  `reset`, `branch`, `push` or starting a process. Branch from a local base, or a remote ref with
  `--no-track`. Never start, stop or restart a server that serves my working tree.
- In a worktree, write by absolute path and check `git status --short` after.
- A denied command stays denied: don't retry it in another form; give me the exact command.
- Never allow an interpreter or a shell by permission rule; make the narrow safe action free.
