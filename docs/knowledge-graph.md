# Knowledge graph

`repo-knowledge` sets up a Markdown graph inside a repo: nodes in `docs/features/`, a generated
`docs/knowledge/index.md` that maps paths to nodes, a glossary and decision records. This page
records why its lint, `skills/repo-knowledge/scripts/knowledge-lint.sh`, is built the way it is.

- **Copied, not called.** The repo gets its own copy in `scripts/`, so its CI keeps working for a
  developer who never installed this skill set, and after the skill set is gone. The skill offers
  a `cmp` against the shipped copy on every update, and the repo decides whether to take it.
- **`git ls-files`.** The lint reads the file list from git (tracked and not ignored), so a glob
  is checked against the same files in CI and on a laptop, and ignored build output never counts.
- **`source-roots.txt` and `!`.** A source area is a first-level folder under a source root, and
  `src` is the default. A repo with `apps` and `packages` lists them in
  `docs/knowledge/source-roots.txt`. A line `!<area>` exempts an area that no feature owns, such as
  generated code.
- **`skills` and `api` are not checked.** A global skill is absent in CI, and an endpoint has no
  file to point to, so a check on them would fail on a clean checkout or check nothing.
- **Exit codes.** 0 is clean. 1 is a problem in the graph: every problem is printed, then the
  count. 2 is a misuse: an unknown argument, or a folder that is not a git work tree.
- **`--write`.** Writes the index and only the index, and only when the nodes parse. A plain run
  never writes, and fails when the committed index differs from the nodes.
