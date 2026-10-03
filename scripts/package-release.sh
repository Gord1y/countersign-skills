#!/bin/sh
set -eu

if [ "$#" -lt 1 ] || [ "$#" -gt 2 ]; then
  echo "usage: package-release.sh <version> [<ref>]" >&2
  exit 2
fi

version=$1
ref=${2:-v$version}
name="countersign-skills-$version"
root=$(cd "$(dirname "$0")/.." && pwd)
cd "$root"

if ! git rev-parse --verify --quiet "$ref^{commit}" >/dev/null; then
  echo "package-release: the ref $ref does not exist" >&2
  exit 1
fi
if ! git cat-file -e "$ref:catalog.json" 2>/dev/null; then
  echo "package-release: $ref has no catalog.json" >&2
  exit 1
fi

if command -v sha256sum >/dev/null 2>&1; then
  sha256_of() { sha256sum "$1" | cut -d ' ' -f 1; }
else
  sha256_of() { shasum -a 256 "$1" | cut -d ' ' -f 1; }
fi

rm -rf dist
mkdir dist
git archive --format=tar.gz --prefix="$name/" -o "dist/$name.tar.gz" "$ref"
printf '%s  %s\n' "$(sha256_of "dist/$name.tar.gz")" "$name.tar.gz" >"dist/$name.tar.gz.sha256"
git show "$ref:catalog.json" >dist/catalog.json
echo "package-release: wrote dist/$name.tar.gz, dist/$name.tar.gz.sha256 and dist/catalog.json"
