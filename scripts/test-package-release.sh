#!/bin/sh
set -eu

scripts=$(cd "$(dirname "$0")" && pwd)
work=$(mktemp -d "${TMPDIR:-/tmp}/test-package-release.XXXXXX")
trap 'rm -rf "$work"' EXIT

unset GIT_DIR GIT_WORK_TREE GIT_INDEX_FILE
export GIT_CONFIG_GLOBAL=/dev/null GIT_CONFIG_NOSYSTEM=1
export GIT_AUTHOR_NAME=Test GIT_AUTHOR_EMAIL=test@example.com
export GIT_COMMITTER_NAME=Test GIT_COMMITTER_EMAIL=test@example.com

fail() {
  echo "test-package-release: $1" >&2
  exit 1
}

repo="$work/repo"
git init -q -b main "$repo"
mkdir "$repo/scripts"
cp "$scripts/package-release.sh" "$repo/scripts/package-release.sh"
printf '{"skills":[]}\n' >"$repo/catalog.json"
printf 'hello\n' >"$repo/README.md"
git -C "$repo" add .
git -C "$repo" commit -q -m "chore: start"
git -C "$repo" tag v9.9.9

(cd "$repo" && scripts/package-release.sh 9.9.9) >"$work/out" 2>&1 || fail "package-release failed on a tagged repo: $(cat "$work/out")"

tarball="$repo/dist/countersign-skills-9.9.9.tar.gz"
[ -f "$tarball" ] || fail "the tarball was not written"
tar -tzf "$tarball" | grep -qx 'countersign-skills-9.9.9/catalog.json' || fail "the tarball does not hold countersign-skills-9.9.9/catalog.json"
tar -tzf "$tarball" | grep -qx 'countersign-skills-9.9.9/README.md' || fail "the tarball does not hold the committed files"

lines=$(wc -l <"$tarball.sha256" | tr -d ' ')
[ "$lines" -eq 1 ] || fail "the .sha256 file has $lines lines, not one"
if command -v sha256sum >/dev/null 2>&1; then
  (cd "$repo/dist" && sha256sum -c countersign-skills-9.9.9.tar.gz.sha256 >/dev/null 2>&1) || fail "the .sha256 file does not verify the tarball"
else
  (cd "$repo/dist" && shasum -a 256 -c countersign-skills-9.9.9.tar.gz.sha256 >/dev/null 2>&1) || fail "the .sha256 file does not verify the tarball"
fi

cmp -s "$repo/dist/catalog.json" "$repo/catalog.json" || fail "dist/catalog.json differs from the committed catalog.json"

if (cd "$repo" && scripts/package-release.sh 9.9.8) >"$work/out" 2>&1; then
  fail "package-release accepted a version with no tag"
fi
grep -q 'does not exist' "$work/out" || fail "a missing tag did not say the ref does not exist: $(cat "$work/out")"

echo "test-package-release.sh: ok"
