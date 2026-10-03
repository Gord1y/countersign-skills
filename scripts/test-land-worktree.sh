#!/bin/sh
set -eu

root=$(cd "$(dirname "$0")/.." && pwd)
land="$root/skills/orchestrate/scripts/land-worktree"
work=$(mktemp -d "${TMPDIR:-/tmp}/test-land-worktree.XXXXXX")
trap 'rm -rf "$work"' EXIT
failures=0

unset GIT_DIR GIT_WORK_TREE GIT_INDEX_FILE
export GIT_CONFIG_GLOBAL=/dev/null GIT_CONFIG_NOSYSTEM=1
export GIT_AUTHOR_NAME=Test GIT_AUTHOR_EMAIL=test@example.com
export GIT_COMMITTER_NAME=Test GIT_COMMITTER_EMAIL=test@example.com

fail() {
  echo "test-land-worktree: $1" >&2
  failures=$((failures + 1))
}

repo="$work/repo"
git init -q -b main "$repo"
mkdir -p "$repo/.claude/hooks"
printf 'one\n' >"$repo/a.txt"
printf 'one\n' >"$repo/b.txt"
printf 'one\n' >"$repo/c.txt"
printf 'one\n' >"$repo/.claude/hooks/guard.py"
git -C "$repo" add -A
git -C "$repo" commit -q -m "chore: seed"

cut() {
  git -C "$repo" worktree add -q --detach "$work/$1" HEAD
}

land() {
  (cd "$repo" && "$land" "$work/$1") >"$work/out" 2>&1
}

cut plain
printf 'two\n' >"$work/plain/a.txt"
printf 'new\n' >"$work/plain/new.txt"
if ! land plain; then
  fail "a plain landing failed: $(cat "$work/out")"
elif [ "$(cat "$repo/a.txt")" != two ] || [ "$(cat "$repo/new.txt")" != new ]; then
  fail "a plain landing did not copy the changed and the new file"
elif [ "$(git -C "$repo" diff --cached --name-only | tr '\n' ' ')" != "a.txt new.txt " ]; then
  fail "a plain landing did not stage exactly its files"
fi
git -C "$repo" commit -q -m "feat: plain"

cut guarded
printf 'two\n' >"$work/guarded/b.txt"
printf 'two\n' >"$work/guarded/.claude/hooks/guard.py"
if land guarded; then
  fail "a protected path landed although the sandbox would refuse it"
elif ! grep -q "write-protects" "$work/out" || ! grep -qx ".claude/hooks/guard.py" "$work/out"; then
  fail "a protected path was not named: $(cat "$work/out")"
elif [ "$(cat "$repo/b.txt")" != one ]; then
  fail "a refused landing copied a file"
fi
cp "$work/guarded/.claude/hooks/guard.py" "$repo/.claude/hooks/guard.py"
if ! land guarded; then
  fail "the rerun after porting the protected file failed: $(cat "$work/out")"
elif [ "$(cat "$repo/b.txt")" != two ]; then
  fail "the rerun did not land the rest"
elif ! grep -qx "already here  .claude/hooks/guard.py" "$work/out"; then
  fail "the rerun did not report the ported file: $(cat "$work/out")"
elif [ "$(git -C "$repo" diff --cached --name-only | tr '\n' ' ')" != ".claude/hooks/guard.py b.txt " ]; then
  fail "the rerun did not stage the ported file and the rest"
fi
git -C "$repo" commit -q -m "feat: guarded"

cut overlap
printf 'two\n' >"$repo/c.txt"
git -C "$repo" commit -q -am "feat: c on the branch"
printf 'three\n' >"$work/overlap/c.txt"
if land overlap; then
  fail "a file changed on the branch since the cut landed"
elif ! grep -q "changed on this branch since" "$work/out"; then
  fail "an overlap was not reported: $(cat "$work/out")"
elif [ "$(cat "$repo/c.txt")" != two ]; then
  fail "a refused overlap copied the file"
fi

if [ "$failures" -gt 0 ]; then
  exit 1
fi
echo "test-land-worktree: ok"
