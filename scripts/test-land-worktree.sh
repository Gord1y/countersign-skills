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

files_brief() {
  printf '## The task\n\nFiles: %s\n\nThe rest of the brief.\n' "$2" >"$work/$1"
}
land_files() {
  (cd "$repo" && "$land" --files "$work/$1" "$work/$2") >"$work/out" 2>&1
}

files_brief brief-listed.md '`d.txt`, `docs/`'
cut listed
printf 'd\n' >"$work/listed/d.txt"
mkdir -p "$work/listed/docs"
printf 'x\n' >"$work/listed/docs/x.md"
if ! land_files brief-listed.md listed; then
  fail "--files refused files the brief lists: $(cat "$work/out")"
elif [ "$(cat "$repo/d.txt")" != d ] || [ "$(cat "$repo/docs/x.md")" != x ]; then
  fail "--files did not copy the listed file and the listed folder's file"
fi
git -C "$repo" commit -q -m "feat: listed"

files_brief brief-narrow.md '`f.txt`, `docs/`'
cut unlisted
printf 'f\n' >"$work/unlisted/f.txt"
printf 'e\n' >"$work/unlisted/e.txt"
if land_files brief-narrow.md unlisted; then
  fail "--files landed a file outside the brief's Files: list"
elif ! grep -qx "e.txt" "$work/out" || ! grep -q "outside the brief's Files: list" "$work/out"; then
  fail "--files did not name the file outside the list: $(cat "$work/out")"
elif [ -e "$repo/f.txt" ] || [ -e "$repo/e.txt" ]; then
  fail "a refused --files landing copied a file"
fi

printf '## The task\n\nNo list here.\n' >"$work/brief-none.md"
cut unnamed
printf 'g\n' >"$work/unnamed/g.txt"
if land_files brief-none.md unnamed; then
  fail "--files accepted a brief without a Files: list"
elif ! grep -q "has no Files: list" "$work/out"; then
  fail "--files did not report the missing list: $(cat "$work/out")"
fi

printf 'r\n' >"$repo/ren.txt"
git -C "$repo" add ren.txt
git -C "$repo" commit -q -m "chore: seed a file to rename"
cut renamed
mv "$work/renamed/ren.txt" "$work/renamed/moved.txt"
files_brief brief-new-only.md '`moved.txt`'
if land_files brief-new-only.md renamed; then
  fail "--files landed a rename although only the new path is listed"
elif ! grep -qx "ren.txt" "$work/out"; then
  fail "--files did not name the old path of a rename: $(cat "$work/out")"
elif [ -e "$repo/moved.txt" ] || [ ! -e "$repo/ren.txt" ]; then
  fail "a refused rename changed this checkout"
fi
files_brief brief-both.md '`ren.txt`, `moved.txt`'
if ! land_files brief-both.md renamed; then
  fail "--files refused a rename with both paths listed: $(cat "$work/out")"
elif [ -e "$repo/ren.txt" ] || [ "$(cat "$repo/moved.txt")" != r ]; then
  fail "a listed rename did not land"
fi
git -C "$repo" commit -q -m "feat: renamed"

cut sibling
printf 's\n' >"$work/sibling/docs.bak"
files_brief brief-docs.md '`docs/`'
if land_files brief-docs.md sibling; then
  fail "--files let docs.bak through although only docs/ is listed"
elif ! grep -qx "docs.bak" "$work/out"; then
  fail "--files did not name the sibling-prefix file: $(cat "$work/out")"
elif [ -e "$repo/docs.bak" ]; then
  fail "a refused sibling-prefix landing copied the file"
fi

codex_worktree="$repo/.claude/worktrees/agent-codex-01"
git -C "$repo" worktree add -q -b worktree-agent-codex-01 "$codex_worktree" HEAD
printf 'c\n' >"$codex_worktree/codex-listed.txt"
printf 'c\n' >"$codex_worktree/codex-unlisted.txt"
files_brief brief-codex.md '`codex-listed.txt`'
if (cd "$repo" && "$land" --files "$work/brief-codex.md" "$codex_worktree") >"$work/out" 2>&1; then
  fail "--files landed an unlisted file from an agent-codex worktree"
elif ! grep -qx "codex-unlisted.txt" "$work/out"; then
  fail "--files did not name the unlisted file of an agent-codex worktree: $(cat "$work/out")"
elif [ -e "$repo/codex-listed.txt" ] || [ -e "$repo/codex-unlisted.txt" ]; then
  fail "a refused agent-codex landing copied a file"
fi
rm "$codex_worktree/codex-unlisted.txt"
if ! (cd "$repo" && "$land" --files "$work/brief-codex.md" "$codex_worktree") >"$work/out" 2>&1; then
  fail "--files refused the listed file of an agent-codex worktree: $(cat "$work/out")"
elif [ "$(cat "$repo/codex-listed.txt")" != c ]; then
  fail "the listed file of an agent-codex worktree did not land"
fi
git -C "$repo" commit -q -m "feat: codex listed"

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
