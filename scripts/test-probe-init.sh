#!/bin/sh
set -eu

scripts=$(cd "$(dirname "$0")" && pwd)
root=$(cd "$scripts/.." && pwd)
probe_init="$root/bin/probe-init"
work=$(mktemp -d "${TMPDIR:-/tmp}/test-probe-init.XXXXXX")
trap 'rm -rf "$work"' EXIT
failures=0

unset GIT_DIR GIT_WORK_TREE GIT_INDEX_FILE
export GIT_CONFIG_GLOBAL=/dev/null GIT_CONFIG_NOSYSTEM=1

fail() {
  echo "test-probe-init: $1" >&2
  failures=$((failures + 1))
}

home=$(cd "$work" && pwd -P)
HOME=$home
export HOME
mkdir -p "$home/code" "$home/repo"
code=$(cd "$home/code" && pwd -P)
git init -q "$home/repo"

run_probe() {
  "$probe_init" "$@" >"$work/out" 2>"$work/err"
}

settings="$home/probe/.claude/settings.json"

if ! run_probe "$home/probe" --deny "$home/code"; then
  fail "first run failed: $(cat "$work/err")"
fi

has_deny() {
  jq -e --arg rule "$1" '.permissions.deny | index($rule) != null' "$settings" >/dev/null
}

for rule in "Read(/$code)" "Read(/$code/**)" "Edit(/$code)" "Edit(/$code/**)" Bash WebFetch WebSearch \
  'mcp__t3-code__t3_thread_*' 'mcp__t3-code__delegate_task'; do
  has_deny "$rule" || fail "settings.json does not deny $rule"
done

for path in "$code" "$home/.t3/worktrees" "$home/.claude/projects" "$home/.claude/plans" "$home/.codex/sessions"; do
  jq -e --arg path "$path" '.sandbox.filesystem.denyRead | index($path) != null' "$settings" >/dev/null ||
    fail "denyRead does not contain $path"
done

jq -e '.sandbox.enabled == true and .sandbox.allowUnsandboxedCommands == false and .sandbox.failIfUnavailable == true' \
  "$settings" >/dev/null || fail "sandbox keys are wrong"

cmp -s "$root/probe/CLAUDE.template.md" "$home/probe/CLAUDE.md" || fail "CLAUDE.md differs from the template"
for file in journal.md candidates.md verdicts.md accounts.md; do
  [ -f "$home/probe/$file" ] || fail "$file was not created"
done
for folder in briefs screenshots; do
  [ -d "$home/probe/$folder" ] || fail "$folder/ was not created"
done
grep -q '^next    create a T3 Code project for ' "$work/out" || fail "no next line"

echo "my note" >>"$home/probe/journal.md"
echo "my edit" >>"$home/probe/CLAUDE.md"
if ! run_probe "$home/probe" --deny "$home/code" --deny "$home/repo" --deny-tool mcp__github; then
  fail "second run failed: $(cat "$work/err")"
fi
grep -q 'my note' "$home/probe/journal.md" || fail "journal.md edit was lost"
grep -q 'my edit' "$home/probe/CLAUDE.md" || fail "CLAUDE.md edit was lost"
grep -q '^kept    ' "$work/out" || fail "no kept line"
has_deny mcp__github || fail "settings.json lacks mcp__github"
has_deny "Read(/$(cd "$home/repo" && pwd -P)/**)" || fail "settings.json lacks the second path"

if ! run_probe "$home/probe" --deny "$home/code" --deny "$home/repo" --deny-tool mcp__github; then
  fail "third run failed"
fi
grep -q "^ok      $settings\$" "$work/out" || fail "unchanged settings.json not reported ok"

if run_probe "$home/repo/probe" --deny "$home/code"; then
  fail "a folder inside a git work tree was accepted"
fi
[ ! -e "$home/repo/probe" ] || fail "a rejected folder was created"

if run_probe "$home/code/probe" --deny "$home/code"; then
  fail "a folder inside a denied path was accepted"
fi
grep -q 'overlaps the denied path' "$work/err" || fail "overlap not reported"

if run_probe "$home/other"; then
  fail "a run without --deny was accepted"
fi
if run_probe "$home/other" --deny "$home/missing"; then
  fail "a missing deny path was accepted"
fi
grep -q 'does not exist' "$work/err" || fail "missing path not reported"

if run_probe "$home/nonexist/../code/probe" --deny "$home/code"; then
  fail "a .. segment in the folder was accepted"
fi
[ ! -e "$home/nonexist" ] || fail "a .. folder created nonexist"
[ ! -e "$home/code/probe" ] || fail "a .. folder created code/probe"
grep -q 'has a .. segment' "$work/err" || fail ".. not reported"
if run_probe "$home/probe-dots" --deny "$home/code/../code"; then
  fail "a .. segment in a deny path was accepted"
fi

mkdir -p "$home/other/code"
(
  cd "$home"
  CDPATH="$home/other:."
  export CDPATH
  "$probe_init" "$home/probe-cdpath" --deny code >"$work/out" 2>"$work/err"
) || fail "CDPATH run failed: $(cat "$work/err")"
jq -e --arg rule "Read(/$code)" '[.permissions.deny[] | select(. == $rule)] | length == 1' \
  "$home/probe-cdpath/.claude/settings.json" >/dev/null || fail "CDPATH changed the resolved deny path"

if run_probe "$home/probe-empty" --deny ""; then
  fail "an empty --deny was accepted"
fi
if run_probe "$home/probe-empty" --deny "$home/code" --deny-tool ""; then
  fail "an empty --deny-tool was accepted"
fi
[ ! -e "$home/probe-empty" ] || fail "a rejected run created a folder"

mkdir -p "$home/app[v2]"
if run_probe "$home/probe-glob" --deny "$home/app[v2]"; then
  fail "a pattern character in a deny path was accepted"
fi
grep -q 'a character a permission rule would read as a pattern' "$work/err" || fail "pattern character not reported"

mkdir -p "$home/real"
ln -s "$home/real" "$home/link"
real=$(cd "$home/real" && pwd -P)
if ! run_probe "$home/probe-link" --deny "$home/link"; then
  fail "a symlink deny failed: $(cat "$work/err")"
fi
jq -e --arg rule "Read(/$real)" '.permissions.deny | index($rule) != null' \
  "$home/probe-link/.claude/settings.json" >/dev/null || fail "a symlink deny did not resolve to its target"
jq -e --arg rule "Read(/$home/link)" '.permissions.deny | index($rule) == null' \
  "$home/probe-link/.claude/settings.json" >/dev/null || fail "a symlink deny kept the link path"

if run_probe "$home/probe-root" --deny /; then
  fail "--deny / was accepted"
fi
[ ! -e "$home/probe-root" ] || fail "--deny / created a folder"

if [ "$failures" -gt 0 ]; then
  echo "test-probe-init: $failures failure(s)" >&2
  exit 1
fi
echo "test-probe-init: ok"
