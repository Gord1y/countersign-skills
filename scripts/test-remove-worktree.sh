#!/bin/sh
set -eu

root=$(cd "$(dirname "$0")/.." && pwd)
remove="$root/skills/orchestrate/scripts/remove-worktree"
land="$root/skills/orchestrate/scripts/land-worktree"
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

cut hooked
printf 'eight\n' >"$(wt hooked)/a.txt"
(cd "$repo" && "$land" "$(wt hooked)") >/dev/null
printf 'EIGHT\n' >"$repo/a.txt"
git -C "$repo" commit -q -am "feat: a to eight, rewritten by a commit hook"
run "$(wt hooked)"
if [ "$status" -ne 0 ] || [ -e "$(wt hooked)" ]; then
  fail "a landed worktree whose file a commit hook rewrote was not removed: $status $(cat "$work/out")"
fi

cut touched
printf 'nine\n' >"$(wt touched)/b.txt"
(cd "$repo" && "$land" "$(wt touched)") >/dev/null
printf 'NINE\n' >"$repo/b.txt"
git -C "$repo" commit -q -am "feat: b to nine"
printf 'nine, changed after landing\n' >"$(wt touched)/b.txt"
run "$(wt touched)"
if [ "$status" -ne 1 ] || [ "$(cat "$(wt touched)/b.txt")" != "nine, changed after landing" ]; then
  fail "a worktree changed after its landing was not kept: $status $(cat "$work/out")"
fi

cut uncommitted
printf 'ten\n' >"$(wt uncommitted)/a.txt"
(cd "$repo" && "$land" "$(wt uncommitted)") >/dev/null
printf 'TEN\n' >"$repo/a.txt"
run "$(wt uncommitted)"
if [ "$status" -ne 1 ] || [ ! -d "$(wt uncommitted)" ]; then
  fail "a landed worktree whose landing is not committed was not kept: $status $(cat "$work/out")"
fi
git -C "$repo" checkout -q -- a.txt
git -C "$repo" reset -q

git -C "$repo" worktree add -q -b feature "$work/feature" HEAD
git -C "$repo" worktree add -q -b worktree-agent-onfeature "$(wt onfeature)" feature
printf 'feature\n' >"$work/feature/feature.txt"
git -C "$work/feature" add feature.txt
git -C "$work/feature" commit -q -m "feat: feature file"
printf 'eleven\n' >"$(wt onfeature)/b.txt"
printf 'eleven\n' >"$work/feature/b.txt"
git -C "$work/feature" commit -q -am "feat: b to eleven"
run "$(wt onfeature)"
if [ "$status" -ne 0 ] || [ -e "$(wt onfeature)" ]; then
  fail "a worktree landed in a linked checkout was not removed from the main one: $status $(cat "$work/out")"
elif has_branch onfeature; then
  fail "the branch of a worktree landed in a linked checkout is still there"
fi

scratch() {
  git -C "$repo" worktree add -q --detach "$repo/.claude/worktrees/$1" HEAD
}

scratch perf
run --dry-run --landed
if [ "$status" -ne 0 ] || ! grep -qx "would remove $repo/.claude/worktrees/perf" "$work/out"; then
  fail "the dry run did not say would remove for a scratch worktree: $status $(cat "$work/out")"
elif [ ! -d "$repo/.claude/worktrees/perf" ]; then
  fail "the dry run removed a scratch worktree"
fi
run --landed
if [ "$status" -ne 0 ] || [ -e "$repo/.claude/worktrees/perf" ]; then
  fail "--landed kept a clean detached scratch worktree: $status $(cat "$work/out")"
elif git -C "$repo" worktree list --porcelain | grep -qx "worktree $repo/.claude/worktrees/perf"; then
  fail "git still lists the removed scratch worktree"
fi

scratch dirty
printf 'x\n' >"$repo/.claude/worktrees/dirty/loose.txt"
run --landed
if [ ! -f "$repo/.claude/worktrees/dirty/loose.txt" ] || ! grep -q "^kept .*/dirty: it has uncommitted changes" "$work/out"; then
  fail "--landed did not keep a scratch worktree with an untracked file: $(cat "$work/out")"
fi

scratch stray
printf 'stray\n' >"$repo/.claude/worktrees/stray/stray.txt"
git -C "$repo/.claude/worktrees/stray" add stray.txt
git -C "$repo/.claude/worktrees/stray" commit -q -m "feat: stray"
run --landed
if [ ! -d "$repo/.claude/worktrees/stray" ] || ! grep -q "^kept .*/stray: its HEAD .* is on no branch" "$work/out"; then
  fail "--landed did not keep a scratch worktree whose HEAD is on no branch: $(cat "$work/out")"
fi

git -C "$repo" worktree add -q -b session-feature "$repo/.claude/worktrees/session-feature" HEAD
run --landed
if [ ! -d "$repo/.claude/worktrees/session-feature" ]; then
  fail "--landed removed a clean worktree on its own branch: $(cat "$work/out")"
fi

mkdir -p "$repo/.claude/worktrees/cache/node_modules"
printf 'x\n' >"$repo/.claude/worktrees/cache/node_modules/x"
run --landed
if [ "$status" -ne 0 ] || [ -e "$repo/.claude/worktrees/cache" ]; then
  fail "--landed kept an orphan folder of ignored output: $status $(cat "$work/out")"
fi

mkdir -p "$repo/.claude/worktrees/notes"
printf 'x\n' >"$repo/.claude/worktrees/notes/notes.txt"
run --landed
if [ ! -f "$repo/.claude/worktrees/notes/notes.txt" ] || ! grep -q "^kept .*/notes: holds notes.txt, which the repository does not ignore" "$work/out"; then
  fail "--landed did not keep an orphan folder with a file the repository does not ignore: $(cat "$work/out")"
fi

if command -v lsof >/dev/null 2>&1; then
  scratch served
  (cd "$repo/.claude/worktrees/served" && exec sleep 30) &
  served_pid=$!
  sleep 1
  run --landed
  {
    kill "$served_pid"
    wait "$served_pid" || :
  } 2>/dev/null
  if [ ! -d "$repo/.claude/worktrees/served" ] || ! grep -q "^kept .*/served: process [0-9]* runs in it" "$work/out"; then
    fail "--landed did not keep a scratch worktree with a running process: $(cat "$work/out")"
  fi
else
  echo "test-remove-worktree: lsof is missing, skipped the running-process case"
fi

mkdir -p "$work/stub"
printf '#!/bin/sh\nexit 1\n' >"$work/stub/lsof"
chmod +x "$work/stub/lsof"
scratch blind
(cd "$repo" && PATH="$work/stub:$PATH" "$remove" --landed) >"$work/out" 2>&1 || :
if [ ! -d "$repo/.claude/worktrees/blind" ] || ! grep -q "^kept .*/blind: cannot check for running processes" "$work/out"; then
  fail "--landed removed a scratch worktree although lsof failed: $(cat "$work/out")"
fi
git -C "$repo" worktree remove --force "$repo/.claude/worktrees/blind"

mkdir -p "$repo/.claude/worktrees/gitfile/node_modules"
printf 'gitdir: elsewhere\n' >"$repo/.claude/worktrees/gitfile/.git"
run --landed
if [ ! -d "$repo/.claude/worktrees/gitfile" ] || ! grep -q "^kept .*/gitfile: it has a .git entry" "$work/out"; then
  fail "--landed removed an orphan folder with a .git entry: $(cat "$work/out")"
fi

mkdir -p "$repo/.claude/worktrees/cache2/node_modules"
printf 'x\n' >"$repo/.claude/worktrees/cache2/node_modules/x"
run --dry-run --landed
if ! grep -qx "would remove $repo/.claude/worktrees/cache2" "$work/out" || [ ! -f "$repo/.claude/worktrees/cache2/node_modules/x" ]; then
  fail "the dry run on an orphan folder did not only report: $(cat "$work/out")"
fi

run "$repo/.claude/worktrees/cache2"
if [ "$status" -ne 0 ] || [ -e "$repo/.claude/worktrees/cache2" ]; then
  fail "a named orphan folder of ignored output was not removed: $status $(cat "$work/out")"
fi

mkdir -p "$repo/node_modules" "$repo/.claude/worktrees/filevsdir"
printf 'x\n' >"$repo/.claude/worktrees/filevsdir/node_modules"
run --landed
rmdir "$repo/node_modules"
if [ ! -f "$repo/.claude/worktrees/filevsdir/node_modules" ] || ! grep -q "^kept .*/filevsdir: holds node_modules, which the repository does not ignore" "$work/out"; then
  fail "--landed removed an orphan holding a file named like an ignored directory: $(cat "$work/out")"
fi

mkdir -p "$repo/.claude/worktrees/hollow"
touch -t 202001010000 "$repo/.claude/worktrees/hollow"
run --landed
if [ -e "$repo/.claude/worktrees/hollow" ]; then
  fail "--landed kept an old empty orphan folder: $(cat "$work/out")"
fi

run
if [ "$status" -ne 2 ]; then
  fail "no arguments exited $status, not 2"
fi

if [ "$failures" -gt 0 ]; then
  exit 1
fi
echo "test-remove-worktree: ok"
