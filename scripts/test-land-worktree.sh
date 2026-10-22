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

remove="$root/skills/orchestrate/scripts/remove-worktree"
builder() {
  git -C "$repo" worktree add -q -b "worktree-agent-$1" "$repo/.claude/worktrees/agent-$1" HEAD
}
ported() {
  (cd "$repo" && "$land" --ported "$repo/.claude/worktrees/agent-$1") >"$work/out" 2>&1
}
dropped() {
  (cd "$repo" && "$remove" "$repo/.claude/worktrees/agent-$1") >"$work/out" 2>&1
}
record_of() {
  echo "$(git -C "$repo/.claude/worktrees/agent-$1" rev-parse --absolute-git-dir)/countersign-landed"
}

builder hand
printf 'branch\n' >"$repo/a.txt"
git -C "$repo" commit -q -am "feat: a on the branch"
printf 'three\n' >"$repo/.claude/worktrees/agent-hand/a.txt"
if (cd "$repo" && "$land" "$repo/.claude/worktrees/agent-hand") >"$work/out" 2>&1; then
  fail "an overlapped unit landed"
fi
printf 'merged\n' >"$repo/a.txt"
git -C "$repo" commit -q -am "feat: a ported by hand"
if ! ported hand; then
  fail "--ported refused a committed hand-port: $(cat "$work/out")"
elif ! grep -qx "recorded  a.txt" "$work/out"; then
  fail "--ported did not report the file: $(cat "$work/out")"
elif ! dropped hand || ! grep -q "^removed .*/agent-hand$" "$work/out" || [ -e "$repo/.claude/worktrees/agent-hand" ]; then
  fail "a recorded hand-port was not removed: $(cat "$work/out")"
fi

builder open
printf 'four\n' >"$repo/.claude/worktrees/agent-open/b.txt"
if ported open; then
  fail "--ported accepted a file that is not committed here"
elif ! grep -q "not committed here since" "$work/out"; then
  fail "--ported did not name the file: $(cat "$work/out")"
elif [ -e "$(record_of open)" ]; then
  fail "--ported wrote a record although it refused"
elif dropped open && grep -q "^removed .*/agent-open$" "$work/out"; then
  fail "remove-worktree removed a worktree that was never landed"
fi

printf 'four\n' >"$repo/b.txt"
if ported open; then
  fail "--ported accepted a file with an uncommitted change here"
fi

mkdir -p "$repo/tools"
cp -p "$land" "$repo/tools/land-worktree"
git -C "$repo" add tools/land-worktree
git -C "$repo" commit -q -m "chore: vendor land-worktree"
builder selfupdate
updated="$repo/.claude/worktrees/agent-selfupdate/tools/land-worktree"
{
  sed -n '1,2p' "$repo/tools/land-worktree"
  printf 'true\ntrue\ntrue\ntrue\n'
  sed -n '3,$p' "$repo/tools/land-worktree"
} >"$work/updated"
cp "$work/updated" "$updated"
if ! (cd "$repo" && sh tools/land-worktree "$repo/.claude/worktrees/agent-selfupdate") >"$work/out" 2>&1; then
  fail "a checkout's own land-worktree could not land a new version of itself: $(cat "$work/out")"
elif ! cmp -s "$updated" "$repo/tools/land-worktree"; then
  fail "the self-update was not copied"
elif [ ! -f "$(record_of selfupdate)" ]; then
  fail "the self-update wrote no landing record"
fi

if [ "$failures" -gt 0 ]; then
  exit 1
fi
echo "test-land-worktree: ok"
