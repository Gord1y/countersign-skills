#!/bin/sh
set -eu

root=$(cd "$(dirname "$0")/.." && pwd -P)
gate=$root/bin/gate
policy=$root/hooks/policy/gate.sh
work=$(mktemp -d "${TMPDIR:-/tmp}/test-gate.XXXXXX")
trap 'rm -rf "$work"' EXIT
work=$(cd "$work" && pwd -P)
failures=0
mkdir "$work/tmp"
export TMPDIR=$work/tmp

unset GIT_DIR GIT_WORK_TREE GIT_INDEX_FILE
export GIT_CONFIG_GLOBAL=/dev/null GIT_CONFIG_NOSYSTEM=1
export GIT_AUTHOR_NAME=Test GIT_AUTHOR_EMAIL=test@example.com
export GIT_COMMITTER_NAME=Test GIT_COMMITTER_EMAIL=test@example.com
export GIT_CEILING_DIRECTORIES=$work

fail() {
  echo "test-gate: $1" >&2
  failures=$((failures + 1))
}

new_repo() {
  git init -q -b main "$work/$1"
  echo one >"$work/$1/a.txt"
}

commit_all() {
  git -C "$1" add -A
  git -C "$1" commit -q -m "$2"
}

write_gates() {
  printf '## Gates\n\ngate: %s\n' "$2" >"$1/CLAUDE.md"
}

run_gate() {
  gate_status=0
  run_dir=$1
  shift
  (cd "$run_dir" && "$gate" "$@" >"$work/out" 2>"$work/err") || gate_status=$?
}

expect_status() {
  [ "$gate_status" -eq "$2" ] || fail "$1: expected exit $2, got $gate_status ($(cat "$work/err"))"
}

expect_in() {
  grep -qF -- "$3" "$2" || fail "$1: '$3' is missing from $(cat "$2")"
}

stamp_names() {
  for stamp_file in "$1/.git/countersign/gate/"*; do
    [ -f "$stamp_file" ] || continue
    stamp_base=$(basename "$stamp_file")
    case $stamp_base in
      *.*) ;;
      *) echo "$stamp_base" ;;
    esac
  done
}

tree_of_head() {
  git -C "$1" rev-parse 'HEAD^{tree}'
}

expect_no_stamp() {
  [ -z "$(stamp_names "$2")" ] || fail "$1: a stamp was written"
}

plain=$work/plain
mkdir "$plain"
run_gate "$plain"
expect_status "outside a repo" 2
expect_in "outside a repo" "$work/err" "gate: not inside a git repository"

new_repo bogus
write_gates "$work/bogus" true
commit_all "$work/bogus" base
run_gate "$work/bogus" --bogus
expect_status "--bogus" 2
run_gate "$work/bogus" --help
expect_status "--help" 0
expect_in "--help" "$work/out" "usage: gate"

new_repo no-file
commit_all "$work/no-file" base
run_gate "$work/no-file"
expect_status "no instruction file" 3
expect_in "no instruction file" "$work/err" "CLAUDE.md has no gate line"

new_repo no-line
printf '## Gates\n\nRun the checks.\n' >"$work/no-line/CLAUDE.md"
commit_all "$work/no-line" base
run_gate "$work/no-line"
expect_status "gates without a line" 3
expect_in "gates without a line" "$work/err" 'Add one line under "## Gates" in CLAUDE.md'

new_repo wrong-section
printf '## Rules\n\ngate: true\n\n## Gates\n\nRun the checks.\n' >"$work/wrong-section/CLAUDE.md"
commit_all "$work/wrong-section" base
run_gate "$work/wrong-section"
expect_status "line under another heading" 3

new_repo shadowed
printf '## Gates\n\nRun the checks.\n' >"$work/shadowed/CLAUDE.md"
printf '## Gates\n\ngate: true\n' >"$work/shadowed/AGENTS.md"
commit_all "$work/shadowed" base
run_gate "$work/shadowed"
expect_status "CLAUDE.md shadows AGENTS.md" 3

new_repo fenced
printf '## Gates\n\n```sh\n# x\ngate: false\n```\n\ngate: true\n' >"$work/fenced/CLAUDE.md"
commit_all "$work/fenced" base
run_gate "$work/fenced"
expect_status "line past a fenced heading" 0

new_repo clean
write_gates "$work/clean" true
commit_all "$work/clean" base
run_gate "$work/clean"
expect_status "clean tree" 0
expect_in "clean tree" "$work/out" "gate: passed, stamped tree"
[ "$(stamp_names "$work/clean")" = "$(tree_of_head "$work/clean")" ] || fail "clean tree: the stamp is not HEAD^{tree}"

new_repo dirty
write_gates "$work/dirty" true
commit_all "$work/dirty" base
echo two >"$work/dirty/a.txt"
echo new >"$work/dirty/b.txt"
git -C "$work/dirty" status --porcelain >"$work/status-before"
index_before=$(cksum <"$work/dirty/.git/index")
run_gate "$work/dirty"
git -C "$work/dirty" status --porcelain >"$work/status-after"
expect_status "dirty tree" 0
cmp -s "$work/status-before" "$work/status-after" || fail "dirty tree: git status changed"
[ "$(cksum <"$work/dirty/.git/index")" = "$index_before" ] || fail "dirty tree: the real index changed"
[ -n "$(stamp_names "$work/dirty")" ] || fail "dirty tree: no stamp"
[ "$(stamp_names "$work/dirty")" != "$(tree_of_head "$work/dirty")" ] || fail "dirty tree: the stamp is HEAD^{tree}"

new_repo failing
write_gates "$work/failing" false
commit_all "$work/failing" base
run_gate "$work/failing"
expect_status "failing gate" 1
expect_in "failing gate" "$work/err" "gate: failed with exit 1. Full output:"
expect_no_stamp "failing gate" "$work/failing"

new_repo writer
write_gates "$work/writer" 'echo x >> touched.txt'
commit_all "$work/writer" base
run_gate "$work/writer"
expect_status "gate that writes files" 4
expect_in "gate that writes files" "$work/err" "so it is not stamped"
expect_no_stamp "gate that writes files" "$work/writer"

new_repo long-output
write_gates "$work/long-output" "awk 'BEGIN { for (i = 1; i <= 100; i++) print \"line\" i }'"
commit_all "$work/long-output" base
run_gate "$work/long-output"
expect_status "long output" 0
grep -qx line100 "$work/out" || fail "long output: line100 is missing from stdout"
! grep -qx line40 "$work/out" || fail "long output: line40 reached stdout"
grep -qx line1 "$work/long-output/.git/countersign/gate.log" || fail "long output: line1 is missing from the log"

new_repo agents-only
printf '## Gates\n\ngate: true\n' >"$work/agents-only/AGENTS.md"
commit_all "$work/agents-only" base
run_gate "$work/agents-only"
expect_status "AGENTS.md only" 0

new_repo subdir
write_gates "$work/subdir" 'test -f CLAUDE.md'
mkdir "$work/subdir/sub"
echo x >"$work/subdir/sub/f.txt"
commit_all "$work/subdir" base
run_gate "$work/subdir/sub"
expect_status "run from a subdirectory" 0

new_repo linked
write_gates "$work/linked" true
commit_all "$work/linked" base
git -C "$work/linked" worktree add -q -b wt "$work/linked-wt"
echo two >"$work/linked-wt/a.txt"
run_gate "$work/linked-wt"
expect_status "linked worktree" 0
[ -n "$(stamp_names "$work/linked")" ] || fail "linked worktree: the stamp is not in the main git dir"

new_repo nested
write_gates "$work/nested" true
commit_all "$work/nested" base
git -C "$work/nested" worktree add -q -b inner .claude/worktrees/inner
run_gate "$work/nested"
expect_status "nested worktree" 0
[ "$(stamp_names "$work/nested")" = "$(tree_of_head "$work/nested")" ] || fail "nested worktree: it changed the hash"

new_repo ignored-worktrees
write_gates "$work/ignored-worktrees" true
printf '.claude/worktrees/\n' >"$work/ignored-worktrees/.gitignore"
commit_all "$work/ignored-worktrees" base
mkdir -p "$work/ignored-worktrees/.claude/worktrees/agent-x"
echo x >"$work/ignored-worktrees/.claude/worktrees/agent-x/f"
run_gate "$work/ignored-worktrees"
expect_status "ignored .claude/worktrees" 0
[ "$(stamp_names "$work/ignored-worktrees")" = "$(tree_of_head "$work/ignored-worktrees")" ] || fail "ignored .claude/worktrees: the stamp is not HEAD^{tree}"

new_repo tracked-worktrees
write_gates "$work/tracked-worktrees" true
commit_all "$work/tracked-worktrees" base
mkdir -p "$work/tracked-worktrees/.claude/worktrees/agent-x"
echo x >"$work/tracked-worktrees/.claude/worktrees/agent-x/f"
run_gate "$work/tracked-worktrees"
expect_status "unignored .claude/worktrees" 0
stamp_before=$(stamp_names "$work/tracked-worktrees")
[ "$stamp_before" = "$(tree_of_head "$work/tracked-worktrees")" ] || fail "unignored .claude/worktrees: the stamp is not HEAD^{tree}"
echo y >"$work/tracked-worktrees/.claude/worktrees/agent-x/f"
run_gate "$work/tracked-worktrees"
expect_status "unignored .claude/worktrees, changed" 0
[ "$(stamp_names "$work/tracked-worktrees")" = "$stamp_before" ] || fail "unignored .claude/worktrees: a change inside it changed the stamped tree"

for ignored in yes no; do
  repo=$work/real-worktree-$ignored
  new_repo "real-worktree-$ignored"
  write_gates "$repo" true
  [ "$ignored" = no ] || printf '.claude/worktrees/\n' >"$repo/.gitignore"
  commit_all "$repo" base
  git -C "$repo" worktree add -q .claude/worktrees/w1 -b w1
  echo more >"$repo/.claude/worktrees/w1/b.txt"
  git -C "$repo/.claude/worktrees/w1" add b.txt
  git -C "$repo/.claude/worktrees/w1" commit -q -m inner
  echo dirty >"$repo/.claude/worktrees/w1/untracked.txt"
  run_gate "$repo"
  expect_status "real linked worktree, ignored=$ignored" 0
  [ "$(stamp_names "$repo")" = "$(tree_of_head "$repo")" ] || fail "real linked worktree, ignored=$ignored: the stamp is not the tree without .claude/worktrees"
done

new_repo sequence
write_gates "$work/sequence" true
commit_all "$work/sequence" base

policy_session=q1
policy_repo=$work/sequence
policy_subagent=false

policy_event() {
  jq -nc --arg kind "$1" --arg cwd "$policy_repo" --arg id "$policy_session" --arg subagent "$policy_subagent" '
    {provider: "claude", event: $kind, tool: (if $kind == "stop" then "none" else "shell" end),
     tool_name: "", command: "", paths: [], cwd: $cwd, session_id: $id, subagent: ($subagent == "true"),
     stop_hook_active: false}'
}

run_policy() {
  policy_status=0
  policy_event "$1" | sh "$policy" >"$work/policy-out" 2>/dev/null || policy_status=$?
}

session_file=$work/sequence/.git/countersign/sessions/q1
run_policy pre_tool
[ "$policy_status" -eq 0 ] || fail "first pre_tool: exit $policy_status"
[ "$(cat "$session_file" 2>/dev/null)" = "$(tree_of_head "$work/sequence")" ] || fail "first pre_tool: the session file is not HEAD^{tree}"
echo two >"$work/sequence/a.txt"
run_policy pre_tool
[ "$(cat "$session_file")" = "$(tree_of_head "$work/sequence")" ] || fail "second pre_tool: the session file changed"
run_policy stop
[ "$policy_status" -eq 10 ] || fail "stop after an edit: expected exit 10, got $policy_status"
expect_in "stop after an edit" "$work/policy-out" "gate"
run_policy stop
[ "$policy_status" -eq 0 ] || fail "repeated stop on the same tree: expected exit 0, got $policy_status"
echo three >"$work/sequence/a.txt"
run_policy stop
[ "$policy_status" -eq 10 ] || fail "stop on a new unstamped tree: expected exit 10, got $policy_status"
(cd "$work/sequence" && "$gate" >/dev/null 2>&1) || fail "sequence: gate did not pass"
run_policy stop
[ "$policy_status" -eq 0 ] || fail "stop after gate: expected exit 0, got $policy_status"

policy_session=../x
echo five >"$work/sequence/a.txt"
run_policy pre_tool
run_policy stop
[ "$policy_status" -eq 0 ] || fail "unsafe session id: expected exit 0, got $policy_status"
[ ! -e "$work/sequence/.git/countersign/x" ] || fail "unsafe session id: a file escaped the sessions folder"

policy_session=q2
policy_repo=$work/ignored-worktrees
run_policy pre_tool
echo two >"$work/ignored-worktrees/a.txt"
run_policy stop
[ "$policy_status" -eq 10 ] || fail "stop with an ignored .claude/worktrees: expected exit 10, got $policy_status"

new_repo no-gate-line
printf '## Rules\n\nnothing\n' >"$work/no-gate-line/CLAUDE.md"
commit_all "$work/no-gate-line" base
git -C "$work/no-gate-line" worktree add -q -b builder "$work/no-gate-line-wt"
echo two >"$work/no-gate-line-wt/a.txt"
policy_session=q3
policy_repo=$work/no-gate-line-wt
policy_subagent=true
run_policy stop
[ "$policy_status" -eq 0 ] || fail "subagent stop with no gate line: expected exit 0, got $policy_status"

policy_session=q4
policy_repo=$work/no-gate-line
policy_subagent=false
run_policy pre_tool
echo two >"$work/no-gate-line/a.txt"
run_policy stop
[ "$policy_status" -eq 10 ] || fail "main stop with no gate line: expected exit 10, got $policy_status"
expect_in "main stop with no gate line" "$work/policy-out" "no gate line"
run_policy stop
[ "$policy_status" -eq 0 ] || fail "second main stop with no gate line: expected exit 0, got $policy_status"

[ -z "$(ls -A "$work/tmp")" ] || fail "temporary files were left in TMPDIR: $(ls -A "$work/tmp")"

if [ "$failures" -ne 0 ]; then
  echo "test-gate: $failures failure(s)" >&2
  exit 1
fi
echo "test-gate: ok"
