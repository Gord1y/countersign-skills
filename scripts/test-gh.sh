#!/bin/sh
set -eu

root=$(cd "$(dirname "$0")/.." && pwd)
work=$(mktemp -d "${TMPDIR:-/tmp}/test-gh.XXXXXX")
trap 'rm -rf "$work"' EXIT
failures=0

unset GIT_DIR GIT_WORK_TREE GIT_INDEX_FILE GH_TOKEN XDG_CONFIG_HOME
export GIT_CONFIG_GLOBAL=/dev/null GIT_CONFIG_NOSYSTEM=1
export GIT_AUTHOR_NAME=Test GIT_AUTHOR_EMAIL=test@example.com
export GIT_COMMITTER_NAME=Test GIT_COMMITTER_EMAIL=test@example.com

fail() {
  echo "test-gh: $1" >&2
  failures=$((failures + 1))
}

mkdir -p "$work/wrap" "$work/stub" "$work/home/.config/countersign/profile" "$work/plain"
ln -s "$root/bin/gh" "$work/wrap/gh"
cat >"$work/stub/gh" <<'STUB'
#!/bin/sh
if [ "${1:-}" = auth ] && [ "${2:-}" = token ] && [ "${3:-}" = -u ]; then
  [ "$4" != missing ] || exit 1
  echo "token-$4"
  exit 0
fi
echo "token=${GH_TOKEN:-none} args=$*"
STUB
chmod 755 "$work/stub/gh"

map_file="$work/home/.config/countersign/profile/gh-accounts.tsv"
printf 'Gord1y\tGord1y\nfreedomseeker-ai\tdanylo-freedomseeker\n\ngone\tmissing\n' >"$map_file"

make_repo() {
  git init -q -b main "$work/$1"
  git -C "$work/$1" remote add origin "$2"
}

make_repo mine git@github.com:Gord1y/x.git
make_repo company https://github.com/Freedomseeker-AI/y.git
make_repo other https://github.com/someone-else/z
make_repo gone https://github.com/gone/w.git

run_gh() {
  dir=$1
  shift
  (cd "$dir" && HOME="$work/home" PATH="$work/wrap:$work/stub:/usr/bin:/bin" gh "$@") >"$work/out" 2>"$work/err"
}

if ! run_gh "$work/mine" pr list --limit 1; then
  fail "an ssh origin failed: $(cat "$work/err")"
elif [ "$(cat "$work/out")" != "token=token-Gord1y args=pr list --limit 1" ]; then
  fail "an ssh origin did not pick the Gord1y token: $(cat "$work/out")"
fi

run_gh "$work/company" pr list || true
[ "$(cat "$work/out")" = "token=token-danylo-freedomseeker args=pr list" ] || fail "an https origin did not match its owner case-insensitively: $(cat "$work/out")"

run_gh "$work/other" pr list || true
[ "$(cat "$work/out")" = "token=none args=pr list" ] || fail "an owner outside the map did not pass through: $(cat "$work/out")"

mv "$map_file" "$map_file.off"
run_gh "$work/mine" pr list || true
[ "$(cat "$work/out")" = "token=none args=pr list" ] || fail "a missing map file did not pass through: $(cat "$work/out")"
mv "$map_file.off" "$map_file"

(cd "$work/mine" && GH_TOKEN=preset HOME="$work/home" PATH="$work/wrap:$work/stub:/usr/bin:/bin" gh pr list) >"$work/out" 2>"$work/err" || true
[ "$(cat "$work/out")" = "token=preset args=pr list" ] || fail "a preset GH_TOKEN was replaced: $(cat "$work/out")"

run_gh "$work/mine" auth status || true
[ "$(cat "$work/out")" = "token=none args=auth status" ] || fail "gh auth did not pass through untouched: $(cat "$work/out")"

run_gh "$work/plain" pr list || true
[ "$(cat "$work/out")" = "token=none args=pr list" ] || fail "a directory outside git did not pass through: $(cat "$work/out")"

if run_gh "$work/gone" pr list; then
  fail "an account without a token did not fail"
elif [ -s "$work/out" ]; then
  fail "the real gh ran although the account has no token: $(cat "$work/out")"
elif ! grep -q "missing" "$work/err"; then
  fail "the error did not name the account: $(cat "$work/err")"
fi

status=0
(cd "$work/mine" && HOME="$work/home" PATH="$work/wrap:/usr/bin:/bin" gh pr list) >"$work/out" 2>"$work/err" || status=$?
if [ "$status" -ne 127 ]; then
  fail "a PATH with only the wrapper exited $status, not 127"
elif ! grep -q "no gh found on PATH besides this wrapper" "$work/err"; then
  fail "the missing gh was not reported: $(cat "$work/err")"
fi

if [ "$failures" -gt 0 ]; then
  exit 1
fi
echo "test-gh: ok"
