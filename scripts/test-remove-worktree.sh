#!/bin/sh
set -eu

root=$(cd "$(dirname "$0")/.." && pwd)
remove="$root/skills/orchestrate/scripts/remove-worktree"
work=$(mktemp -d "${TMPDIR:-/tmp}/test-remove-worktree.XXXXXX")
trap 'rm -rf "$work"' EXIT
failures=0

unset GIT_DIR GIT_WORK_TREE GIT_INDEX_FILE
export GIT_CONFIG_GLOBAL=/dev/null GIT_CONFIG_NOSYSTEM=1
export GIT_AUTHOR_NAME=Test GIT_AUTHOR_EMAIL=test@example.com
export GIT_COMMITTER_NAME=Test GIT_COMMITTER_EMAIL=test@example.com

fail() {
  echo "test-remove-worktree: $1" >&2
  failures=$((failures + 1))
}

repo="$work/repo"
git init -q -b main "$repo"
printf 'node_modules/\n' >"$repo/.gitignore"
printf 'one\n' >"$repo/a.txt"
printf 'one\n' >"$repo/b.txt"
git -C "$repo" add -A
git -C "$repo" commit -q -m "chore: seed"
repo=$(cd "$repo" && pwd -P)

cut() {
  git -C "$repo" worktree add -q -b "worktree-agent-$1" "$repo/.claude/worktrees/agent-$1" HEAD
}

wt() {
  echo "$repo/.claude/worktrees/agent-$1"
}

run() {
  status=0
  (cd "$repo" && "$remove" "$@") >"$work/out" 2>&1 || status=$?
}

listed() {
  git -C "$repo" worktree list --porcelain | grep -qx "worktree $(wt "$1")"
}

has_branch() {
  git -C "$repo" show-ref --verify -q "refs/heads/worktree-agent-$1"
}

cut landed
printf 'two\n' >"$(wt landed)/a.txt"
printf 'two\n' >"$repo/a.txt"
git -C "$repo" commit -q -am "feat: a to two"
run "$(wt landed)"
if [ "$status" -ne 0 ] || ! grep -qx "removed $(wt landed)" "$work/out"; then
  fail "a landed worktree was not removed: $status $(cat "$work/out")"
elif [ -e "$(wt landed)" ]; then
  fail "the removed worktree is still on disk"
elif listed landed; then
  fail "git still lists the removed worktree"
elif has_branch landed; then
  fail "the removed worktree's branch is still there"
fi

cut later
printf 'later\n' >"$(wt later)/b.txt"
printf 'later\n' >"$repo/b.txt"
git -C "$repo" commit -q -am "feat: b to later"
printf 'one\n' >"$repo/b.txt"
git -C "$repo" commit -q -am "feat: b back to one"
run "$(wt later)"
if [ "$status" -ne 0 ] || [ -e "$(wt later)" ]; then
  fail "a worktree landed and then changed on the branch was not removed: $status $(cat "$work/out")"
fi

cut unlanded
printf 'three\n' >"$(wt unlanded)/b.txt"
run "$(wt unlanded)"
if [ "$status" -ne 1 ] || ! grep -q "^kept $(wt unlanded): not committed" "$work/out"; then
  fail "an unlanded change was not kept with exit 1: $status $(cat "$work/out")"
elif [ "$(cat "$(wt unlanded)/b.txt")" != three ]; then
  fail "the kept worktree lost its file"
fi

cut untracked
printf 'new\n' >"$(wt untracked)/new.txt"
run "$(wt untracked)"
if [ "$status" -ne 1 ] || ! grep -q "^kept $(wt untracked): " "$work/out" || [ ! -e "$(wt untracked)/new.txt" ]; then
  fail "an untracked file absent from main did not keep the worktree: $status $(cat "$work/out")"
fi

cut ignored
mkdir -p "$(wt ignored)/node_modules/.idea"
printf 'x\n' >"$(wt ignored)/node_modules/.idea/x"
printf 'four\n' >"$(wt ignored)/b.txt"
printf 'four\n' >"$repo/b.txt"
git -C "$repo" commit -q -am "feat: b to four"
run "$(wt ignored)"
if [ "$status" -ne 0 ] || ! grep -qx "removed $(wt ignored)" "$work/out" || [ -e "$(wt ignored)" ]; then
  fail "ignored files blocked the removal: $status $(cat "$work/out")"
fi

cut locked
git -C "$repo" worktree lock "$(wt locked)"
run "$(wt locked)"
if [ "$status" -ne 1 ] || ! grep -q "^kept $(wt locked): locked" "$work/out" || [ ! -d "$(wt locked)" ]; then
  fail "a locked worktree was not kept: $status $(cat "$work/out")"
fi

git -C "$repo" worktree add -q -b outside-branch "$work/outside" HEAD
run "$work/outside"
outside_real=$(cd "$work/outside" && pwd -P)
if [ "$status" -ne 1 ] || ! grep -q "^kept $outside_real: outside" "$work/out" || [ ! -d "$work/outside" ]; then
  fail "a worktree outside .claude/worktrees was not kept: $status $(cat "$work/out")"
fi

cut ahead
printf 'ahead\n' >"$(wt ahead)/ahead.txt"
git -C "$(wt ahead)" add ahead.txt
git -C "$(wt ahead)" commit -q -m "feat: ahead"
run "$(wt ahead)"
if [ "$status" -ne 1 ] || ! grep -q "^kept $(wt ahead): its HEAD" "$work/out" || [ ! -d "$(wt ahead)" ]; then
  fail "a worktree with its own commit was not kept: $status $(cat "$work/out")"
fi

cut dry
printf 'five\n' >"$(wt dry)/a.txt"
printf 'five\n' >"$repo/a.txt"
git -C "$repo" commit -q -am "feat: a to five"
run --dry-run "$(wt dry)"
if [ "$status" -ne 0 ] || ! grep -qx "would remove $(wt dry)" "$work/out"; then
  fail "the dry run did not say would remove: $status $(cat "$work/out")"
elif [ ! -d "$(wt dry)" ] || ! listed dry || ! has_branch dry; then
  fail "the dry run changed something"
fi

cut sweepgood
printf 'six\n' >"$(wt sweepgood)/b.txt"
printf 'six\n' >"$repo/b.txt"
git -C "$repo" commit -q -am "feat: b to six"
cut sweepbad
printf 'seven\n' >"$(wt sweepbad)/a.txt"
run --landed
if [ "$status" -ne 0 ]; then
  fail "--landed exited $status: $(cat "$work/out")"
elif ! grep -qx "removed $(wt sweepgood)" "$work/out" || [ -e "$(wt sweepgood)" ]; then
  fail "--landed did not remove the landed worktree: $(cat "$work/out")"
elif ! grep -q "^kept $(wt sweepbad): " "$work/out" || [ ! -d "$(wt sweepbad)" ]; then
  fail "--landed did not keep the unlanded worktree: $(cat "$work/out")"
fi

run
if [ "$status" -ne 2 ]; then
  fail "no arguments exited $status, not 2"
fi

if [ "$failures" -gt 0 ]; then
  exit 1
fi
echo "test-remove-worktree: ok"
