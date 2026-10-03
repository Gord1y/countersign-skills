#!/bin/sh
set -eu

root=$(cd "$(dirname "$0")/.." && pwd)

command -v claude >/dev/null 2>&1 || {
  echo "claude is not on PATH; install Claude Code to run the trigger evals" >&2
  exit 2
}

cd "$root"
exec claude plugin eval . --ablation none --runs 1 --no-publish --max-cost-usd 6 --scaffold "$@"
