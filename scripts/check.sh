#!/bin/sh
set -eu

scripts=$(cd "$(dirname "$0")" && pwd)
root=$(cd "$scripts/.." && pwd)

"$root/test.sh"
for test_script in "$scripts"/test-*.sh; do
  "$test_script"
done
"$scripts/lint.sh"

echo "check.sh: ok"
