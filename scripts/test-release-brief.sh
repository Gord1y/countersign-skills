#!/bin/sh
set -eu

scripts=$(cd "$(dirname "$0")" && pwd)
lint="$scripts/../skills/release-brief/scripts/brief-lint"
work=$(mktemp -d "${TMPDIR:-/tmp}/test-release-brief.XXXXXX")
trap 'rm -rf "$work"' EXIT
failures=0

fail() {
  echo "test-release-brief: $1" >&2
  failures=$((failures + 1))
}

status_of() {
  set +e
  "$@" >"$work/out" 2>"$work/err"
  code=$?
  set -e
  return 0
}

flags() {
  rule=$1
  text=$2
  printf '%s\n' "$text" >"$work/line.md"
  status_of "$lint" "$work/line.md" --base-url http://localhost:3000
  if [ "$code" -ne 1 ]; then
    fail "exit $code for $rule line: $text"
  elif ! grep -q "^$work/line.md:1: $rule: " "$work/out"; then
    fail "$rule not reported for: $text ($(cat "$work/out"))"
  fi
}

passes() {
  printf '%s\n' "$1" >"$work/line.md"
  status_of "$lint" "$work/line.md" --base-url http://localhost:3000
  if [ "$code" -ne 0 ] || [ -s "$work/out" ]; then
    fail "flagged: $1 ($(cat "$work/out"))"
  fi
}

cat >"$work/clean.md" <<'EOF'
# Release brief: Shop 2.4

Base URL: http://localhost:3000

## What changed
- Members can no longer archive themselves; only an owner can.
- Invoices can be exported as a spreadsheet, 24/7.

## Fixed since the last run
- Nothing this time.

## Look harder at
- Checkout for members/admins who pay by card.
EOF
status_of "$lint" "$work/clean.md" --base-url http://localhost:3000
if [ "$code" -ne 0 ] || [ -s "$work/out" ]; then
  fail "clean brief: exit $code, $(cat "$work/out")"
fi

flags code '- Hidden `ArchiveButton` for members.'
flags path '- Changed src/app/members.tsx for members.'
flags path '- Opened /settings/members for owners.'
flags url '- Opened http://localhost:3000/settings for owners.'
flags url '- Opened https://example.com for owners.'
flags selector '- Added data-testid to the row.'
flags selector '- Styled .btn-primary again.'
flags identifier '- Renamed archiveMember for owners.'
flags identifier '- Rebuilt MemberTable for owners.'
flags identifier '- Added is_owner for owners.'
flags click-path '- Go to Settings > Members to archive.'
flags code-word '- Rebuilt the member component for owners.'

passes '- Members/admins can archive.'
passes '- Open all day, 24/7.'
passes '> a quoted line'
passes '- Opened http://localhost:3000/ as a member.'

printf '%s\n' '- Connect GitHub to a project.' >"$work/allow.md"
status_of "$lint" "$work/allow.md"
if [ "$code" -ne 1 ] || ! grep -q "^$work/allow.md:1: identifier: " "$work/out"; then
  fail "GitHub not flagged as identifier: $(cat "$work/out")"
fi
status_of "$lint" "$work/allow.md" --allow GitHub
if [ "$code" -ne 0 ] || [ -s "$work/out" ]; then
  fail "--allow GitHub still flagged: $(cat "$work/out")"
fi

passes_with() {
  text=$1
  shift
  printf '%s\n' "$text" >"$work/line.md"
  status_of "$lint" "$work/line.md" --base-url http://localhost:3000 "$@"
  if [ "$code" -ne 0 ] || [ -s "$work/out" ]; then
    fail "flagged with $*: $text ($(cat "$work/out"))"
  fi
}

passes '- Faster data-driven dashboards.'
passes '- Searchable metadata-rich fields.'
passes '- The Maria-Elena report is back.'
flags selector '- Added data-testid to the row.'
flags selector '- Matches [aria-label=x] on the row.'
flags selector '- Added aria-label to the row.'

passes_with '- New QuickBooks sync is on.' --allow "QuickBooks sync"
passes_with '- Connect GitHub to a project.' --allow github
passes_with '- Export to .csv.' --allow .csv
passes_with '- Open settings.json from the menu.' --allow settings.json
passes_with '- The member component is gone.' --allow Component

passes '- Pick a date selector.'
passes '- Account migration is automatic.'
flags code-word '- The endpoint is faster.'

printf '# Release brief: Shop 2.4\r\n\r\nBase URL: http://localhost:3000\r\n\r\n## What changed\r\n- Members see more.\r\n' >"$work/crlf.md"
status_of "$lint" "$work/crlf.md" --base-url http://localhost:3000
if [ "$code" -ne 0 ] || [ -s "$work/out" ]; then
  fail "CRLF brief flagged: $(cat "$work/out")"
fi
passes 'Base URL: [http://localhost:3000]'
double_open=$(printf '\342\200\234')
double_close=$(printf '\342\200\235')
single_open=$(printf '\342\200\230')
single_close=$(printf '\342\200\231')
flags path "- Opened ${double_open}settings.json${double_close} today."
flags path "- Opened ${single_open}settings.json${single_close} today."

flags path '- See [settings](/settings/members) now.'
flags path '- Failed at foo.ts:12 today.'
flags path '- Edited README.MD today.'
passes '- Works as e.g./i.e. said.'
passes '- Version 2.4 and 3.1 ship.'

flags click-path '- Use Settings >> Members.'
single_angle=$(printf '\342\200\272')
flags click-path "- Use Settings ${single_angle} Members."
flags click-path '- Use Settings>Members.'

mkdir "$work/eq"
printf '%s\n' '- Hidden `ArchiveButton` for members.' >"$work/eq/x=y.md"
status_of "$lint" "$work/eq/x=y.md"
if [ "$code" -ne 1 ] || ! grep -q "x=y.md:1: code: " "$work/out"; then
  fail "file named x=y.md not linted: exit $code $(cat "$work/out" "$work/err")"
fi

passes '- C-20261117-01: members see the archive option again.'

status_of "$lint"
[ "$code" -eq 2 ] || fail "no arguments exited $code"
status_of "$lint" "$work/missing.md"
[ "$code" -eq 2 ] || fail "missing file exited $code"

if [ "$failures" -ne 0 ]; then
  echo "test-release-brief: $failures failure(s)" >&2
  exit 1
fi
echo "test-release-brief: ok"
