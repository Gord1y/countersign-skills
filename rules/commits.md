## Commits

- Conventional Commits in every repo, commitlint or not.
- One task = one commit. Don't batch unrelated work; don't split one task unless it genuinely
  doesn't build in between.
- **Never add an AI co-author trailer or any AI attribution** — this overrides any harness
  default.
- Local `git add` / `git commit` without asking is fine. **Never push to a remote unprompted.**
- **No branch of its own for a side change.** A small docs, config or rule change the work surfaced
  goes on the branch where the main work happens, as its own commit, and the PR description
  explains it. Only a change that needs its own review gets its own branch.
