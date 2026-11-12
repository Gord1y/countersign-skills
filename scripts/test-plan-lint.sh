#!/bin/sh
set -eu

root=$(cd "$(dirname "$0")/.." && pwd)
lint="$root/skills/orchestrate/scripts/plan-lint"
work=$(mktemp -d "${TMPDIR:-/tmp}/test-plan-lint.XXXXXX")
trap 'rm -rf "$work"' EXIT
failures=0

unset GIT_DIR GIT_WORK_TREE GIT_INDEX_FILE
export GIT_CONFIG_GLOBAL=/dev/null GIT_CONFIG_NOSYSTEM=1

fail() {
  echo "test-plan-lint: $1" >&2
  failures=$((failures + 1))
}

run() {
  status=0
  "$lint" "$@" >"$work/out" 2>&1 || status=$?
}

sample() {
  cat >"$1" <<'EOF'
# Plan

### Slice 01: feat(auth): add the login form
- Scope: `src/auth/**`, `**/*.test.ts`
- Sensitive: `package.json`: adds zod, Q1
- Acceptance: a wrong password shows the error under the field
- Evidence: `pnpm test auth` passes
- Out of scope: password reset
EOF
}

sample "$work/valid.md"
run check "$work/valid.md"
if [ "$status" -ne 0 ] || ! grep -qx "plan-lint: ok, 1 slices" "$work/out"; then
  fail "the sample plan did not pass: $status $(cat "$work/out")"
fi

grep -v '^- Evidence:' "$work/valid.md" >"$work/no-evidence.md"
run check "$work/no-evidence.md"
if [ "$status" -ne 1 ] || ! grep -q "slice 01 has no Evidence: line" "$work/out"; then
  fail "a slice without Evidence: was not refused: $status $(cat "$work/out")"
fi

printf '# Plan\n\nNo slices here.\n' >"$work/empty.md"
run check "$work/empty.md"
if [ "$status" -ne 1 ] || ! grep -q ":1: no slices:" "$work/out"; then
  fail "a plan without slices was not refused: $status $(cat "$work/out")"
fi

sed 's|`src/auth/\*\*`|`../x`, `src/[ab].ts`|' "$work/valid.md" >"$work/bad-glob.md"
run check "$work/bad-glob.md"
if [ "$status" -ne 1 ] || ! grep -q "bad glob ../x:" "$work/out" || ! grep -q "bad glob src/\[ab\].ts:" "$work/out"; then
  fail "bad globs were not refused: $status $(cat "$work/out")"
fi

run check "$work/missing.md"
if [ "$status" -ne 2 ] || ! grep -qx "plan-lint: $work/missing.md not found" "$work/out"; then
  fail "a missing plan was not reported: $status $(cat "$work/out")"
fi

sample "$work/open.md"
printf '\n- Answer:\n' >>"$work/open.md"
cp "$work/open.md" "$work/open.before"
run approve "$work/open.md"
if [ "$status" -ne 1 ] || ! grep -q "unanswered question" "$work/out"; then
  fail "approve accepted an unanswered question: $status $(cat "$work/out")"
elif ! cmp -s "$work/open.md" "$work/open.before"; then
  fail "approve touched a plan it refused"
fi

sample "$work/stamp.md"
run approve "$work/stamp.md"
if [ "$status" -ne 0 ]; then
  fail "approve failed on a valid plan: $status $(cat "$work/out")"
elif ! tail -n 1 "$work/stamp.md" | grep -Eq '^Approved: [0-9a-f]{64} [0-9-]{10}$'; then
  fail "the stamp is not the last line: $(tail -n 1 "$work/stamp.md")"
fi
run verify "$work/stamp.md"
if [ "$status" -ne 0 ] || ! grep -q "is approved at" "$work/out"; then
  fail "verify refused a fresh approval: $status $(cat "$work/out")"
fi

run approve "$work/stamp.md"
if [ "$(grep -c '^Approved: ' "$work/stamp.md")" -ne 1 ]; then
  fail "approving twice left more than one stamp"
fi
run verify "$work/stamp.md"
if [ "$status" -ne 0 ]; then
  fail "verify refused a re-approved plan: $status $(cat "$work/out")"
fi

printf -- '- Acceptance: one more thing\n' >>"$work/stamp.md"
run verify "$work/stamp.md"
if [ "$status" -ne 1 ] || ! grep -q "approval is void" "$work/out"; then
  fail "an edit after approval did not void it: $status $(cat "$work/out")"
fi

sample "$work/fresh.md"
run verify "$work/fresh.md"
if [ "$status" -ne 1 ] || ! grep -q "is not approved" "$work/out"; then
  fail "an unstamped plan verified: $status $(cat "$work/out")"
fi

for heading in '### Slice 2: b' '### Slice 001: b' '### Slice 02:  x' '### Slice 03 - x'; do
  sample "$work/heading.md"
  printf '\n%s\n- Scope: `a`\n' "$heading" >>"$work/heading.md"
  run check "$work/heading.md"
  if [ "$status" -ne 1 ] || ! grep -q ":[0-9]*: bad slice heading" "$work/out"; then
    fail "the heading '$heading' was not reported: $status $(cat "$work/out")"
  fi
done

crlf() {
  awk '{ printf "%s\r\n", $0 }' "$1" >"$1.crlf"
  cp "$1.crlf" "$1"
  rm -f "$1.crlf"
}

sample "$work/crlf-empty.md"
crlf "$work/crlf-empty.md"
run check "$work/crlf-empty.md"
if [ "$status" -ne 0 ]; then
  fail "a valid plan with CRLF line ends was refused: $status $(cat "$work/out")"
fi
grep -v '^- Acceptance:' "$work/valid.md" >"$work/crlf-field.md"
printf -- '- Acceptance:\n' >>"$work/crlf-field.md"
crlf "$work/crlf-field.md"
run check "$work/crlf-field.md"
if [ "$status" -ne 1 ] || ! grep -q "slice 01 has no Acceptance: line" "$work/out"; then
  fail "an empty Acceptance: with CRLF passed: $status $(cat "$work/out")"
fi

sample "$work/crlf-answer.md"
printf '\n- Answer:\n' >>"$work/crlf-answer.md"
crlf "$work/crlf-answer.md"
run approve "$work/crlf-answer.md"
if [ "$status" -ne 1 ] || ! grep -q "unanswered question" "$work/out"; then
  fail "an empty Answer: with CRLF was approved: $status $(cat "$work/out")"
fi

for form in '**Answer:**' 'Answer:' '> Answer:' '**Answer:** (pending the user)' '- Answer: (Pending, ask first)'; do
  sample "$work/forms.md"
  printf '\n%s\n' "$form" >>"$work/forms.md"
  run approve "$work/forms.md"
  if [ "$status" -ne 1 ] || ! grep -q "unanswered question" "$work/out"; then
    fail "the answer form '$form' was approved: $status $(cat "$work/out")"
  fi
done

sample "$work/answered.md"
printf '\n**Answer:** yes, use zod\n- Answer: backoff\n' >>"$work/answered.md"
run approve "$work/answered.md"
if [ "$status" -ne 0 ]; then
  fail "answered questions were refused: $status $(cat "$work/out")"
fi

sample "$work/middle.md"
run approve "$work/middle.md"
sed 's/password reset/profile edit/' "$work/middle.md" >"$work/middle.edited"
cp "$work/middle.edited" "$work/middle.md"
run verify "$work/middle.md"
if [ "$status" -ne 1 ] || ! grep -q "approval is void" "$work/out"; then
  fail "an edit in the middle of an approved plan did not void it: $status $(cat "$work/out")"
fi

sample "$work/prose.md"
printf '\nApproved: by the team\n' >>"$work/prose.md"
run approve "$work/prose.md"
if [ "$status" -ne 0 ] || ! grep -qx "Approved: by the team" "$work/prose.md"; then
  fail "a prose Approved: line was dropped or refused: $status $(cat "$work/out")"
fi
run verify "$work/prose.md"
if [ "$status" -ne 0 ]; then
  fail "verify refused a plan with a prose Approved: line: $status $(cat "$work/out")"
fi
sed 's/by the team/by nobody/' "$work/prose.md" >"$work/prose.edited"
cp "$work/prose.edited" "$work/prose.md"
run verify "$work/prose.md"
if [ "$status" -ne 1 ] || ! grep -q "approval is void" "$work/out"; then
  fail "an edit to a prose Approved: line did not void the approval: $status $(cat "$work/out")"
fi

run_in() {
  dir=$1
  shift
  status=0
  (cd "$dir" && "$lint" "$@") >"$work/out" 2>&1 || status=$?
}

scope_files() {
  ls "$1/.git/countersign/scope.d" 2>/dev/null || true
}

git init -q "$work/repo"
git -C "$work/repo" -c user.name=t -c user.email=t@example.invalid commit -q --allow-empty -m base
repo_home=$(cd "$work/repo" && pwd -P)
repo_sum=$(printf '%s' "$repo_home" | cksum | cut -d' ' -f1)

sample "$work/fence.md"
printf '\n### Slice 02: feat(auth): add the logout button\n- Scope: `src/logout/**`\n' >>"$work/fence.md"
printf -- '- Acceptance: a\n- Evidence: b\n- Out of scope: c\n' >>"$work/fence.md"
run approve "$work/fence.md"

run_in "$work/repo" fence "$work/fence.md" 01
scope_file="$work/repo/.git/countersign/scope.d/$repo_sum"
if [ "$status" -ne 0 ] || ! grep -qx "plan-lint: fenced 1 slices of $work/fence.md" "$work/out"; then
  fail "fence failed on an approved plan: $status $(cat "$work/out")"
elif [ "$(scope_files "$work/repo")" != "$repo_sum" ]; then
  fail "the scope file is not named by the cksum of the checkout: $(scope_files "$work/repo")"
else
  plan_physical=$(cd "$work" && pwd -P)/fence.md
  for line in "plan	$plan_physical" "home	$repo_home" 'allow	^src/auth(/.*)?$' 'allow	^(.*/)?[^/]*\.test\.ts$' 'named	^package\.json$'; do
    if ! grep -Fxq "$line" "$scope_file"; then
      fail "the scope file lacks the line: $line"
    fi
  done
  if ! grep -Eq '^approved	[0-9a-f]{64}$' "$scope_file"; then
    fail "the scope file lacks the approved hash"
  fi
  if grep -q 'logout' "$scope_file"; then
    fail "the scope file carries a line from a slice that was not fenced"
  fi
fi

run_in "$work/repo" fence "$work/fence.md" 01 09
if [ "$status" -ne 1 ] || ! grep -qx "plan-lint: no slice 09 in $work/fence.md" "$work/out"; then
  fail "an unknown slice was not refused: $status $(cat "$work/out")"
fi

run_in "$work/repo" unfence
if [ "$status" -ne 0 ] || ! grep -qx "plan-lint: unfenced" "$work/out" || [ -n "$(scope_files "$work/repo")" ]; then
  fail "unfence left the scope file: $status $(cat "$work/out")"
fi

if [ -d "$work/repo/.git/countersign" ]; then
  fail "unfence left the empty countersign folder behind"
fi

run_in "$work/repo" unfence
if [ "$status" -ne 0 ] || ! grep -qx "plan-lint: no fence for this checkout" "$work/out"; then
  fail "unfence without a fence did not say so: $status $(cat "$work/out")"
fi

sample "$work/void.md"
run approve "$work/void.md"
printf -- '- Acceptance: more\n' >>"$work/void.md"
run_in "$work/repo" fence "$work/void.md" 01
if [ "$status" -ne 1 ] || [ -n "$(scope_files "$work/repo")" ]; then
  fail "a void plan was fenced: $status $(cat "$work/out")"
fi

mkdir "$work/plain"
run_in "$work/plain" fence "$work/fence.md" 01
if [ "$status" -ne 2 ] || ! grep -q "fence runs inside the checkout" "$work/out"; then
  fail "fence outside git was not refused: $status $(cat "$work/out")"
fi

printf '# Plan\n\n### Slice 01: feat: globs\n- Scope: `a?.ts`, `src/**/x.ts`, `**`, `a+b.ts`\n' >"$work/globs.md"
printf -- '- Acceptance: a\n- Evidence: b\n- Out of scope: c\n' >>"$work/globs.md"
run approve "$work/globs.md"
run_in "$work/repo" fence "$work/globs.md" 01
for line in 'allow	^a[^/]\.ts$' 'allow	^src/(.*/)?x\.ts$' 'allow	^.*$' 'allow	^a\+b\.ts$'; do
  if ! grep -Fxq "$line" "$scope_file"; then
    fail "the glob did not become the pattern: $line"
  fi
done
run_in "$work/repo" unfence

git -C "$work/repo" worktree add -q -b other "$work/other"
other_home=$(cd "$work/other" && pwd -P)
other_sum=$(printf '%s' "$other_home" | cksum | cut -d' ' -f1)
run_in "$work/repo" fence "$work/fence.md" 01
run_in "$work/other" fence "$work/fence.md" 02
if [ "$(scope_files "$work/repo" | wc -l | tr -d ' ')" -ne 2 ]; then
  fail "two checkouts did not each get a scope file: $(scope_files "$work/repo")"
fi
run_in "$work/repo" unfence
if [ "$(scope_files "$work/repo")" != "$other_sum" ]; then
  fail "unfence from one checkout touched the other's file: $(scope_files "$work/repo")"
fi
run_in "$work/other" unfence
if [ -n "$(scope_files "$work/repo")" ]; then
  fail "unfence from the second checkout left a file: $(scope_files "$work/repo")"
fi

if [ "$failures" -gt 0 ]; then
  exit 1
fi
echo "test-plan-lint: ok"
