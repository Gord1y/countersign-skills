#!/bin/sh
set -eu

root=$(cd "$(dirname "$0")/.." && pwd)
tool="$root/bin/agent-gh-token"
work=$(cd "$(mktemp -d "${TMPDIR:-/tmp}/test-agent-gh-token.XXXXXX")" && pwd)
trap 'rm -rf "$work"' EXIT
failures=0

fail() {
  echo "test-agent-gh-token: $1" >&2
  failures=$((failures + 1))
}

unset GH_TOKEN GIT_DIR GIT_WORK_TREE
export GIT_CONFIG_NOSYSTEM=1

mkdir -p "$work/bin" "$work/keys" "$work/repo"
openssl genrsa -out "$work/keys/app.pem" 2048 2>/dev/null
openssl rsa -in "$work/keys/app.pem" -pubout -out "$work/keys/app.pub" 2>/dev/null

cat >"$work/bin/curl" <<'EOF'
#!/bin/sh
printf '%s\n' "$*" >>"$STUB_LOG.argv"
method=GET
body=
auth=
while [ $# -gt 1 ]; do
  case $1 in
    -X) method=$2; shift 2 ;;
    -d) body=$2; shift 2 ;;
    -K) auth=$(sed -n 's/^header = "Authorization: Bearer \(.*\)"$/\1/p'); shift 2 ;;
    -H) shift 2 ;;
    *) shift ;;
  esac
done
url=$1
printf '%s %s %s\n' "$method" "${url#"$STUB_API"}" "$body" >>"$STUB_LOG"
printf '%s\n' "$auth" >"$STUB_LOG.jwt"
case "$method ${url#"$STUB_API"}" in
  "GET /orgs/acme/installation") echo '{"id":42}' ;;
  "GET /orgs/solo/installation") exit 22 ;;
  "GET /users/solo/installation") echo '{"id":7}' ;;
  "GET /orgs/admin/installation") echo '{"id":99}' ;;
  "POST /app/installations/99/access_tokens") echo '{"token":"ghs_admin","permissions":{"administration":"write","contents":"write"}}' ;;
  "POST /app/installations/"*"/access_tokens") echo '{"token":"ghs_stubbed","expires_at":"2026-01-01T00:00:00Z"}' ;;
  *) exit 22 ;;
esac
EOF
chmod +x "$work/bin/curl"

tab=$(printf '\t')
printf 'acme%s123%s%s\nsolo%s456%s%s\n' "$tab" "$tab" "$work/keys/app.pem" "$tab" "$tab" "$work/keys/app.pem" >"$work/apps.tsv"
mkdir -p "$work/inrepo" "$work/linked-keys"
git -C "$work/inrepo" init -q
cp "$work/keys/app.pem" "$work/inrepo/app.pem"
ln -s "$work/inrepo/app.pem" "$work/linked-keys/link.pem"
printf 'not a key\n' >"$work/keys/garbage.pem"
printf 'admin%s9%s%s\nlinky%s8%s%s\nbad%s5%s%s\n' "$tab" "$tab" "$work/keys/app.pem" "$tab" "$tab" "$work/linked-keys/link.pem" "$tab" "$tab" "$work/keys/garbage.pem" >>"$work/apps.tsv"

git -C "$work/repo" init -q
git -C "$work/repo" remote add origin git@github.com:acme/widget.git

export AGENT_GH_APPS="$work/apps.tsv" AGENT_GH_API=https://api.invalid STUB_API=https://api.invalid STUB_LOG="$work/log"
run() {
  (cd "$work/repo" && PATH="$work/bin:$PATH" "$tool" "$@")
}

seen=$(run sh -c 'printf %s "$GH_TOKEN"') || fail "a configured owner failed"
[ "$seen" = ghs_stubbed ] || fail "the command did not get the installation token as GH_TOKEN"
grep -qx 'POST /app/installations/42/access_tokens {"repositories":\["widget"\]}' "$work/log" ||
  fail "the token was not requested for origin's repo alone"

jwt=$(cat "$work/log.jwt")
signed=${jwt%.*}
printf '%s' "${jwt##*.}" | tr -- '-_' '+/' | awk '{ while (length($0) % 4) $0 = $0 "="; print }' |
  openssl base64 -d -A >"$work/sig"
printf '%s' "$signed" | openssl dgst -sha256 -verify "$work/keys/app.pub" -signature "$work/sig" >/dev/null 2>&1 ||
  fail "the JWT signature does not verify against the app key"
claims=$(printf '%s' "$signed" | cut -d. -f2 | tr -- '-_' '+/' | awk '{ while (length($0) % 4) $0 = $0 "="; print }' |
  openssl base64 -d -A)
[ "$(printf '%s' "$claims" | jq -r '.iss')" = 123 ] || fail "the JWT issuer is not the app id"
[ "$(printf '%s' "$claims" | jq -r '.exp - .iat')" = 600 ] || fail "the JWT lifetime is not 10 minutes"
if grep -q "$signed" "$work/log.argv"; then
  fail "the JWT appeared in curl's arguments, where any process can read it"
fi

printed=$(run true 2>&1) || fail "a command that succeeds made the tool fail"
[ -z "$printed" ] || fail "the tool printed output of its own: $printed"

: >"$work/log"
seen=$(run --repo solo/thing sh -c 'printf %s "$GH_TOKEN"') || fail "a user-owned install failed"
[ "$seen" = ghs_stubbed ] || fail "--repo solo/thing did not get a token"
grep -qx 'POST /app/installations/7/access_tokens {"repositories":\["thing"\]}' "$work/log" ||
  fail "--repo did not fall back to the user installation, scoped to the repo"

if out=$(run --repo nobody/x true 2>&1); then
  fail "an owner missing from the config did not fail"
fi
case $out in
  *"no GitHub App for nobody"*) ;;
  *) fail "an unknown owner gave the wrong message: $out" ;;
esac

if out=$(run --repo solo true 2>&1); then
  fail "a --repo without a repo name did not fail"
fi
case $out in
  *"OWNER/REPO"*) ;;
  *) fail "a --repo without a repo name gave the wrong message: $out" ;;
esac

if out=$(run --repo linky/x true 2>&1); then
  fail "a key reached through a symlink into a git work tree was used"
fi
case $out in
  *"inside a git work tree"*) ;;
  *) fail "a symlinked key in a git work tree gave the wrong message: $out" ;;
esac

rm -f "$work/ran"
if out=$(run --repo bad/x sh -c ': >"$1"' sh "$work/ran" 2>&1); then
  fail "a garbage key did not fail"
fi
case $out in
  *"could not sign with the key"*) ;;
  *) fail "a garbage key gave the wrong message: $out" ;;
esac
[ ! -e "$work/ran" ] || fail "the command ran although the key could not sign"

rm -f "$work/ran"
if out=$(run --repo admin/x sh -c ': >"$1"' sh "$work/ran" 2>&1); then
  fail "an app with the administration permission was accepted"
fi
case $out in
  *"has the administration permission"*) ;;
  *) fail "an app with administration gave the wrong message: $out" ;;
esac
[ ! -e "$work/ran" ] || fail "the command ran with an administration token"

git -C "$work/keys" init -q
if out=$(run true 2>&1); then
  fail "a key inside a git work tree was used"
fi
case $out in
  *"inside a git work tree"*) ;;
  *) fail "a key inside a git work tree gave the wrong message: $out" ;;
esac

if [ "$failures" -ne 0 ]; then
  exit 1
fi
echo "test-agent-gh-token: ok"
