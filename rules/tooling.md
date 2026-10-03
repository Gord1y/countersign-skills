## Tooling

- **pnpm, always,** for JS/TS installs and scripts.
- **Definition of done:** the project's own gates (lint, typecheck, tests) run and pass before
  reporting a change as complete. A repo with no gates gets at least a typecheck or build.
- **Keep tool output small.** Filter long output or pipe it through `head`/`tail`; read big files
  with `offset`/`limit`, never `cat` a whole file to see part of it. Run a gate as
  `log="$(mktemp "${TMPDIR:-/tmp}/gate.XXXXXX")"; <cmd> > "$log" 2>&1; echo "exit=$?"; tail -n 60 "$log"`:
  a failing command's result keeps only the start of its output, so the errors at the end are lost
  otherwise. Every session running at once shares `$TMPDIR`, so each gate gets its own log.
- **Run `gh` as a command of its own.** The sandbox lets `gh` out only when nothing else shares the
  line: piped or chained, it runs inside, can't read its token or verify TLS, and looks logged out.
  Filter with `--jq` or `-q`, never a pipe.
