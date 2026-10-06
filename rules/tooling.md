## Tooling

- pnpm, always, for JS/TS.
- Done means the project's own gates passed (lint, typecheck, tests); with none, a typecheck or
  build. Verify it yourself: never hand me a check you can run.
- Keep output small: run a gate as `set -o pipefail; <cmd> 2>&1 | tail -n 60`, and read big files
  by range.
- Run `gh` as a command of its own and filter with `--jq`: piped or chained, it runs sandboxed and
  looks logged out.
