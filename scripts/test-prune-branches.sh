#!/bin/sh
set -eu

root=$(cd "$(dirname "$0")/.." && pwd)
prune="$root/skills/orchestrate/scripts/prune-branches"
work=$(mktemp -d "${TMPDIR:-/tmp}/test-prune-branches.XXXXXX")
trap 'rm -rf "$work"' EXIT
failures=0

unset GIT_DIR GIT_WORK_TREE GIT_INDEX_FILE
export GIT_CONFIG_GLOBAL=/dev/null GIT_CONFIG_NOSYSTEM=1
export GIT_AUTHOR_NAME=Test GIT_AUTHOR_EMAIL=test@example.com
export GIT_COMMITTER_NAME=Test GIT_COMMITTER_EMAIL=test@example.com

fail() {
  echo "test-prune-branches: $1" >&2
  failures=$((failures + 1))
}

git init -q --bare -b main "$work/origin.git"
repo="$work/repo"
git init -q -b main "$repo"
git -C "$repo" remote add origin "$work/origin.git"
printf 'one\n' >"$repo/a.txt"
printf 'one\n' >"$repo/b.txt"
git -C "$repo" add -A
git -C "$repo" commit -q -m "chore: seed"
git -C "$repo" push -q -u origin main
git -C "$repo" remote set-head origin main

has() {
  git -C "$repo" show-ref --verify -q "refs/heads/$1"
}

run() {
  status=0
  (cd "$repo" && "$prune" "$@") >"$work/out" 2>&1 || status=$?
}

commit_on() {
  git -C "$repo" switch -q -c "$1" main
  printf '%s\n' "$3" >"$repo/$2"
  git -C "$repo" commit -q -am "feat: $1 one"
  printf '%s more\n' "$3" >"$repo/$2"
  git -C "$repo" commit -q -am "feat: $1 two"
  git -C "$repo" switch -q main
}

commit_on squashed a.txt squashed
git -C "$repo" merge -q --squash squashed >/dev/null
git -C "$repo" commit -q -m "feat: squashed (#1)"

commit_on merged b.txt merged
git -C "$repo" merge -q --no-ff -m "merge merged" merged

printf 'later\n' >"$repo/c.txt"
git -C "$repo" add c.txt
git -C "$repo" commit -q -m "feat: later work on main"
git -C "$repo" push -q origin main

commit_on inflight a.txt inflight
git -C "$repo" push -q -u origin inflight

commit_on local b.txt local

git -C "$repo" branch fresh main

run --dry-run
if [ "$status" -ne 0 ]; then
  fail "the dry run failed: $(cat "$work/out")"
fi
if ! grep -qx "would delete squashed: squashed into origin/main" "$work/out"; then
  fail "the dry run did not find the squashed branch: $(cat "$work/out")"
fi
if ! has squashed; then
  fail "the dry run deleted a branch"
fi

run
if [ "$status" -ne 0 ]; then
  fail "prune-branches failed: $(cat "$work/out")"
fi
if has squashed; then
  fail "a squash-merged branch was kept: $(cat "$work/out")"
fi
if has merged; then
  fail "a merged branch was kept: $(cat "$work/out")"
fi
if ! has inflight; then
  fail "a pushed branch not on main was deleted"
fi
if ! has local; then
  fail "an unpushed branch with its own commits was deleted"
fi
if ! has fresh; then
  fail "a fresh branch with nothing committed was deleted"
fi
if ! has main; then
  fail "the default branch was deleted"
fi
if ! grep -qx "kept fresh: nothing committed on it yet" "$work/out"; then
  fail "the fresh branch was not reported: $(cat "$work/out")"
fi

git -C "$repo" switch -q local
run
if ! has local; then
  fail "the checked-out branch was deleted"
fi

if [ "$failures" -gt 0 ]; then
  exit 1
fi
echo "test-prune-branches: ok"
