#!/bin/sh
set -eu

root=$(cd "$(dirname "$0")/.." && pwd)
cd "$root"

for tool in shellcheck actionlint; do
  if ! command -v "$tool" >/dev/null 2>&1; then
    echo "lint.sh: $tool is not on PATH, install it first" >&2
    exit 2
  fi
done

failed=0

check_script() {
  shellcheck -s sh -S warning "$@" || failed=1
}

check_script -e SC2034 lib.sh
check_script -x install.sh update.sh uninstall.sh test.sh

for script in bin/* skills/*/scripts/* scripts/*.sh scripts/git-hooks/* evals/*/*.sh; do
  [ -f "$script" ] || continue
  [ "$(head -n 1 "$script")" = "#!/bin/sh" ] || continue
  check_script "$script"
done

actionlint || failed=1

if [ "$failed" -ne 0 ]; then
  echo "lint.sh: failed" >&2
  exit 1
fi
echo "lint.sh: ok"
