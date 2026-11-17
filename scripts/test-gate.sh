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
export XDG_CACHE_HOME=$work/cache
unset COUNTERSIGN_GATE_SLOTS

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

new_repo policy-real-worktree
write_gates "$work/policy-real-worktree" true
commit_all "$work/policy-real-worktree" base
git -C "$work/policy-real-worktree" worktree add -q .claude/worktrees/w1 -b w1
echo dirty >"$work/policy-real-worktree/.claude/worktrees/w1/untracked.txt"
policy_session=q5
policy_repo=$work/policy-real-worktree
run_policy pre_tool
echo two >"$work/policy-real-worktree/a.txt"
run_policy stop
[ "$policy_status" -eq 10 ] || fail "stop with a real linked worktree under .claude/worktrees: expected exit 10, got $policy_status"

wait_for_text() {
  waited=0
  until grep -qF -- "$2" "$1" 2>/dev/null; do
    waited=$((waited + 1))
    [ "$waited" -le 150 ] || return 1
    sleep 0.1
  done
}

wait_for_file() {
  waited=0
  until [ -f "$1" ]; do
    waited=$((waited + 1))
    [ "$waited" -le 150 ] || return 1
    sleep 0.1
  done
}

hold_command() {
  printf 'echo run >>%s; : >%s; while [ ! -f %s ]; do sleep 0.1; done' "$1/runs" "$1/started" "$1/release"
}

new_repo lock-sees-itself
write_gates "$work/lock-sees-itself" 'test -f .git/countersign/gate.lock/pid'
commit_all "$work/lock-sees-itself" base
run_gate "$work/lock-sees-itself"
expect_status "the gate holds the tree lock while it runs" 0
[ ! -e "$work/lock-sees-itself/.git/countersign/gate.lock" ] || fail "tree lock: not released after a pass"

new_repo lock-failing
write_gates "$work/lock-failing" false
commit_all "$work/lock-failing" base
run_gate "$work/lock-failing"
expect_status "failing gate with a lock" 1
[ ! -e "$work/lock-failing/.git/countersign/gate.lock" ] || fail "tree lock: not released after a failure"

new_repo lock-wait
mkdir "$work/lock-wait-ctl"
write_gates "$work/lock-wait" "$(hold_command "$work/lock-wait-ctl")"
commit_all "$work/lock-wait" base
(cd "$work/lock-wait" && "$gate" >"$work/lock-first.out" 2>&1) &
first_pid=$!
wait_for_file "$work/lock-wait-ctl/started" || fail "tree lock: the first gate never started"
holder_pid=$(cat "$work/lock-wait/.git/countersign/gate.lock/pid")
(cd "$work/lock-wait" && "$gate" >"$work/lock-second.out" 2>&1) &
second_pid=$!
wait_for_text "$work/lock-second.out" "waiting for it. Do not start another gate." || fail "tree lock: the second gate did not wait"
expect_in "tree lock wait line" "$work/lock-second.out" "gate: another gate is running in this tree (pid $holder_pid); waiting for it."
: >"$work/lock-wait-ctl/release"
first_status=0
wait "$first_pid" || first_status=$?
second_status=0
wait "$second_pid" || second_status=$?
[ "$first_status" -eq 0 ] || fail "tree lock: the first gate exited $first_status"
[ "$second_status" -eq 0 ] || fail "tree lock: the second gate exited $second_status"
expect_in "tree lock, second gate" "$work/lock-second.out" "already passed"
[ "$(wc -l <"$work/lock-wait-ctl/runs" | tr -d ' ')" = 1 ] || fail "tree lock: the gate command ran more than once"
[ ! -e "$work/lock-wait/.git/countersign/gate.lock" ] || fail "tree lock: not released after the wait"

new_repo lock-stale
write_gates "$work/lock-stale" true
commit_all "$work/lock-stale" base
sh -c 'exit 0' &
dead_pid=$!
wait "$dead_pid" || true
mkdir -p "$work/lock-stale/.git/countersign/gate.lock"
printf '%s\n' "$dead_pid" >"$work/lock-stale/.git/countersign/gate.lock/pid"
run_gate "$work/lock-stale"
expect_status "a lock held by a dead process" 0
[ ! -e "$work/lock-stale/.git/countersign/gate.lock" ] || fail "tree lock: a dead holder's lock was not cleared"

new_repo lock-unprovable
write_gates "$work/lock-unprovable" true
commit_all "$work/lock-unprovable" base
mkdir -p "$work/lock-unprovable/.git/countersign/gate.lock"
printf '1\n' >"$work/lock-unprovable/.git/countersign/gate.lock/pid"
(cd "$work/lock-unprovable" && "$gate" >"$work/lock-unprovable.out" 2>&1) &
unprovable_pid=$!
wait_for_text "$work/lock-unprovable.out" "waiting for it" || fail "tree lock: a holder whose kill -0 is refused was treated as dead"
kill "$unprovable_pid" 2>/dev/null || true
wait "$unprovable_pid" 2>/dev/null || true
[ -f "$work/lock-unprovable/.git/countersign/gate.lock/pid" ] || fail "tree lock: a gate that never held the lock removed it"

new_repo lock-term
mkdir "$work/lock-term-ctl"
write_gates "$work/lock-term" "$(hold_command "$work/lock-term-ctl")"
commit_all "$work/lock-term" base
(cd "$work/lock-term" && "$gate" >"$work/lock-term.out" 2>&1) &
term_pid=$!
wait_for_file "$work/lock-term-ctl/started" || fail "tree lock: the gate to terminate never started"
kill -TERM "$(cat "$work/lock-term/.git/countersign/gate.lock/pid")"
: >"$work/lock-term-ctl/release"
term_status=0
wait "$term_pid" || term_status=$?
[ "$term_status" -ne 0 ] || fail "tree lock: a terminated gate exited 0"
[ ! -e "$work/lock-term/.git/countersign/gate.lock" ] || fail "tree lock: not released after TERM"
[ ! -e "$work/cache/countersign/gate-slots/slot-1" ] || fail "slots: not released after TERM"

new_repo lock-garbage-pid
write_gates "$work/lock-garbage-pid" true
commit_all "$work/lock-garbage-pid" base
mkdir -p "$work/lock-garbage-pid/.git/countersign/gate.lock"
printf 'not-a-pid\n' >"$work/lock-garbage-pid/.git/countersign/gate.lock/pid"
(cd "$work/lock-garbage-pid" && "$gate" >"$work/lock-garbage-pid.out" 2>&1) &
garbage_pid=$!
wait_for_text "$work/lock-garbage-pid.out" "waiting for it" || fail "tree lock: a fresh lock with a malformed pid was treated as dead"
kill "$garbage_pid" 2>/dev/null || true
wait "$garbage_pid" 2>/dev/null || true

new_repo slot-invalid
write_gates "$work/slot-invalid" true
commit_all "$work/slot-invalid" base
for bad_slots in 0 abc -1 1.5 ''; do
  COUNTERSIGN_GATE_SLOTS=$bad_slots
  export COUNTERSIGN_GATE_SLOTS
  run_gate "$work/slot-invalid"
  unset COUNTERSIGN_GATE_SLOTS
  expect_status "COUNTERSIGN_GATE_SLOTS='$bad_slots'" 2
  expect_in "COUNTERSIGN_GATE_SLOTS='$bad_slots'" "$work/err" "COUNTERSIGN_GATE_SLOTS must be a positive integer"
done

new_repo slot-holds
write_gates "$work/slot-holds" "test -f $work/cache/countersign/gate-slots/slot-1/pid"
commit_all "$work/slot-holds" base
run_gate "$work/slot-holds"
expect_status "the gate holds a machine slot while it runs" 0
[ ! -e "$work/cache/countersign/gate-slots/slot-1" ] || fail "slots: not released after a pass"

new_repo slot-a
new_repo slot-b
mkdir "$work/slot-ctl"
write_gates "$work/slot-a" "$(hold_command "$work/slot-ctl")"
write_gates "$work/slot-b" 'echo b >>'"$work/slot-ctl/b-ran"
commit_all "$work/slot-a" base
commit_all "$work/slot-b" base
(cd "$work/slot-a" && COUNTERSIGN_GATE_SLOTS=1 "$gate" >"$work/slot-a.out" 2>&1) &
slot_a_pid=$!
wait_for_file "$work/slot-ctl/started" || fail "slots: the first gate never started"
(cd "$work/slot-b" && COUNTERSIGN_GATE_SLOTS=1 "$gate" >"$work/slot-b.out" 2>&1) &
slot_b_pid=$!
wait_for_text "$work/slot-b.out" "gate: 1 gates are running on this machine; waiting for a slot." || fail "slots: the second gate did not wait"
[ ! -f "$work/slot-ctl/b-ran" ] || fail "slots: the second gate ran while the only slot was taken"
: >"$work/slot-ctl/release"
slot_a_status=0
wait "$slot_a_pid" || slot_a_status=$?
slot_b_status=0
wait "$slot_b_pid" || slot_b_status=$?
[ "$slot_a_status" -eq 0 ] || fail "slots: the first gate exited $slot_a_status"
[ "$slot_b_status" -eq 0 ] || fail "slots: the second gate exited $slot_b_status"
[ -f "$work/slot-ctl/b-ran" ] || fail "slots: the second gate never ran after the slot freed"

new_repo slot-stale
write_gates "$work/slot-stale" true
commit_all "$work/slot-stale" base
mkdir -p "$work/cache/countersign/gate-slots/slot-1"
printf '%s\n' "$dead_pid" >"$work/cache/countersign/gate-slots/slot-1/pid"
COUNTERSIGN_GATE_SLOTS=1
export COUNTERSIGN_GATE_SLOTS
run_gate "$work/slot-stale"
unset COUNTERSIGN_GATE_SLOTS
expect_status "a slot held by a dead process" 0

new_repo slot-unwritable
write_gates "$work/slot-unwritable" true
commit_all "$work/slot-unwritable" base
XDG_CACHE_HOME=/dev/null/none
export XDG_CACHE_HOME
run_gate "$work/slot-unwritable"
XDG_CACHE_HOME=$work/cache
export XDG_CACHE_HOME
expect_status "an unwritable slot folder" 0
expect_in "an unwritable slot folder" "$work/err" "running without the machine-wide cap"
[ -n "$(stamp_names "$work/slot-unwritable")" ] || fail "an unwritable slot folder: no stamp"

[ -z "$(ls -A "$work/tmp")" ] || fail "temporary files were left in TMPDIR: $(ls -A "$work/tmp")"

if [ "$failures" -ne 0 ]; then
  echo "test-gate: $failures failure(s)" >&2
  exit 1
fi
echo "test-gate: ok"
