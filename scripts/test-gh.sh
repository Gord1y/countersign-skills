#!/bin/sh
set -eu

root=$(cd "$(dirname "$0")/.." && pwd)
work=$(mktemp -d "${TMPDIR:-/tmp}/test-gh.XXXXXX")
trap 'rm -rf "$work"' EXIT
failures=0

unset GIT_DIR GIT_WORK_TREE GIT_INDEX_FILE GH_TOKEN XDG_CONFIG_HOME CLAUDECODE CODEX_THREAD_ID
export GIT_CONFIG_GLOBAL=/dev/null GIT_CONFIG_NOSYSTEM=1
export GIT_AUTHOR_NAME=Test GIT_AUTHOR_EMAIL=test@example.com
export GIT_COMMITTER_NAME=Test GIT_COMMITTER_EMAIL=test@example.com

fail() {
  echo "test-gh: $1" >&2
  failures=$((failures + 1))
}

mkdir -p "$work/app" "$work/wrap" "$work/stub" "$work/home/.config/countersign/profile" "$work/plain"
ln -s "$root/bin/gh" "$work/wrap/gh"
cat >"$work/stub/gh" <<'STUB'
#!/bin/sh
if [ "${1:-}" = auth ] && [ "${2:-}" = token ] && [ "${3:-}" = -u ]; then
  [ "$4" != missing ] || exit 1
  echo "token-$4"
  exit 0
fi
if [ "${1:-}" = auth ] && [ "${2:-}" = git-credential ]; then
  read -r first || first=
  echo "token=${GH_TOKEN:-none} args=$* stdin=$first"
  exit 0
fi
echo "token=${GH_TOKEN:-none} args=$*"
STUB
chmod 755 "$work/stub/gh"

cat >"$work/app/agent-gh-token" <<'STUB'
#!/bin/sh
if [ "${1:-}" = --repo ]; then
  printf '%s\n' "$2" >"$(dirname "$0")/repo"
  shift 2
fi
GH_TOKEN=app-token
export GH_TOKEN
exec "$@"
STUB
chmod 755 "$work/app/agent-gh-token"

apps_file="$work/home/.config/countersign/profile/agent-gh-apps.tsv"
printf 'acme\t1\t/nonexistent.pem\n' >"$apps_file"

map_file="$work/home/.config/countersign/profile/gh-accounts.tsv"
printf 'solo\tsolo-user\nother\tother-user\nacme\tacme-bot\n\ngone\tmissing\n' >"$map_file"

make_repo() {
  git init -q -b main "$work/$1"
  git -C "$work/$1" remote add origin "$2"
}

make_repo mine git@github.com:solo/x.git
make_repo company https://github.com/Acme/y.git
make_repo other https://github.com/someone-else/z
make_repo gone https://github.com/gone/w.git

run_gh() {
  dir=$1
  shift
  (cd "$dir" && HOME="$work/home" PATH="$work/wrap:$work/stub:/usr/bin:/bin" gh "$@") >"$work/out" 2>"$work/err"
}

run_agent_gh() {
  dir=$1
  shift
  (cd "$dir" && CLAUDECODE=1 HOME="$work/home" PATH="$work/wrap:$work/app:$work/stub:/usr/bin:/bin" gh "$@") >"$work/out" 2>"$work/err"
}

if ! run_gh "$work/mine" pr list --limit 1; then
  fail "an ssh origin failed: $(cat "$work/err")"
elif [ "$(cat "$work/out")" != "token=token-solo-user args=pr list --limit 1" ]; then
  fail "an ssh origin did not pick the solo-user token: $(cat "$work/out")"
fi

run_gh "$work/company" pr list || true
[ "$(cat "$work/out")" = "token=token-acme-bot args=pr list" ] || fail "an https origin did not match its owner case-insensitively: $(cat "$work/out")"

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

printf 'protocol=https\nhost=github.com\n\n' | run_gh "$work/mine" auth git-credential get || true
[ "$(cat "$work/out")" = "token=token-solo-user args=auth git-credential get stdin=protocol=https" ] || fail "gh auth git-credential did not get the mapped token: $(cat "$work/out")"

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

run_agent_gh "$work/company" pr list || true
[ "$(cat "$work/out")" = "token=app-token args=pr list" ] || fail "an agent session did not get the app token: $(cat "$work/out")"

(cd "$work/company" && CODEX_THREAD_ID=t1 HOME="$work/home" PATH="$work/wrap:$work/app:$work/stub:/usr/bin:/bin" gh pr list) >"$work/out" 2>"$work/err" || true
[ "$(cat "$work/out")" = "token=app-token args=pr list" ] || fail "a Codex session did not get the app token: $(cat "$work/out")"

(cd "$work/company" && HOME="$work/home" PATH="$work/wrap:$work/app:$work/stub:/usr/bin:/bin" gh pr list) >"$work/out" 2>"$work/err" || true
[ "$(cat "$work/out")" = "token=token-acme-bot args=pr list" ] || fail "a session without an agent marker did not keep the account token: $(cat "$work/out")"

run_agent_gh "$work/mine" pr list || true
[ "$(cat "$work/out")" = "token=token-solo-user args=pr list" ] || fail "an owner without an app row did not keep the account token: $(cat "$work/out")"

printf 'protocol=https\nhost=github.com\n\n' | run_agent_gh "$work/company" auth git-credential get || true
[ "$(cat "$work/out")" = "token=app-token args=auth git-credential get stdin=protocol=https" ] || fail "the credential helper did not get the app token: $(cat "$work/out")"

mv "$map_file" "$map_file.off"
run_agent_gh "$work/company" pr list || true
[ "$(cat "$work/out")" = "token=app-token args=pr list" ] || fail "an app row did not work without the account map: $(cat "$work/out")"
mv "$map_file.off" "$map_file"

status=0
(cd "$work/company" && CLAUDECODE=1 HOME="$work/home" PATH="$work/wrap:$work/stub:/usr/bin:/bin" gh pr list) >"$work/out" 2>"$work/err" || status=$?
if [ "$status" -eq 0 ]; then
  fail "an app row without agent-gh-token on PATH did not fail"
elif [ -s "$work/out" ]; then
  fail "the real gh ran although agent-gh-token is missing: $(cat "$work/out")"
elif ! grep -q "agent-gh-token is not on PATH" "$work/err"; then
  fail "the missing agent-gh-token was not reported: $(cat "$work/err")"
fi

(cd "$work/company" && CLAUDECODE=1 GH_TOKEN=preset HOME="$work/home" PATH="$work/wrap:$work/app:$work/stub:/usr/bin:/bin" gh pr list) >"$work/out" 2>"$work/err" || true
[ "$(cat "$work/out")" = "token=preset args=pr list" ] || fail "a preset GH_TOKEN was replaced in an agent session: $(cat "$work/out")"

agent_in() {
  agent_dir=$1
  shift
  rm -f "$work/app/repo"
  (cd "$agent_dir" && CLAUDECODE=1 HOME="$work/home" PATH="$work/wrap:$work/app:$work/stub:/usr/bin:/bin" "$@") >"$work/out" 2>"$work/err" || true
}

agent_in "$work/plain" gh pr list -R acme/y
[ "$(cat "$work/out")" = "token=app-token args=pr list -R acme/y" ] || fail "-R acme/y outside a repo did not use the app: $(cat "$work/out")"
[ "$(cat "$work/app/repo" 2>/dev/null)" = acme/y ] || fail "-R acme/y was not passed to agent-gh-token as --repo"

agent_in "$work/plain" gh pr list -Racme/y
[ "$(cat "$work/out")" = "token=app-token args=pr list -Racme/y" ] || fail "-Racme/y outside a repo did not use the app: $(cat "$work/out")"

agent_in "$work/plain" gh pr list --repo=acme/y
[ "$(cat "$work/out")" = "token=app-token args=pr list --repo=acme/y" ] || fail "--repo=acme/y outside a repo did not use the app: $(cat "$work/out")"

agent_in "$work/plain" gh pr list --repo github.com/acme/y
[ "$(cat "$work/out")" = "token=app-token args=pr list --repo github.com/acme/y" ] || fail "--repo HOST/OWNER/REPO outside a repo did not use the app: $(cat "$work/out")"
[ "$(cat "$work/app/repo" 2>/dev/null)" = acme/y ] || fail "HOST/OWNER/REPO was not reduced to OWNER/REPO"

(cd "$work/plain" && CLAUDECODE=1 GH_REPO=acme/y HOME="$work/home" PATH="$work/wrap:$work/app:$work/stub:/usr/bin:/bin" gh pr list) >"$work/out" 2>"$work/err" || true
[ "$(cat "$work/out")" = "token=app-token args=pr list" ] || fail "GH_REPO=acme/y outside a repo did not use the app: $(cat "$work/out")"

agent_in "$work/company" gh pr list -R other/z
[ "$(cat "$work/out")" = "token=token-other-user args=pr list -R other/z" ] || fail "-R other/z from an acme checkout did not use the other mapping: $(cat "$work/out")"

run_gh "$work/plain" pr list -R acme/y || true
[ "$(cat "$work/out")" = "token=token-acme-bot args=pr list -R acme/y" ] || fail "-R acme/y outside an agent session did not use the account map: $(cat "$work/out")"

agent_in "$work/plain" gh pr list
[ "$(cat "$work/out")" = "token=none args=pr list" ] || fail "a call tied to no repo did not run as the default account: $(cat "$work/out")"

if [ "$failures" -gt 0 ]; then
  exit 1
fi
echo "test-gh: ok"
