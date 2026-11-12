#!/bin/sh
set -eu
LC_ALL=C
export LC_ALL

event=$(cat)
paths=$(printf '%s' "$event" | jq -r '.paths[]?')
[ -n "$paths" ] || exit 0
cwd=$(printf '%s' "$event" | jq -r '.cwd')

resolve() {
  rest=
  probe=$1
  while [ -n "$probe" ] && [ ! -d "$probe" ]; do
    rest=/${probe##*/}$rest
    probe=${probe%/*}
  done
  [ -n "$probe" ] || probe=/
  base=$(cd "$probe" && pwd -P)
  if [ "$base" = / ]; then
    printf '%s\n' "${rest:-/}"
  else
    printf '%s%s\n' "$base" "$rest"
  fi
}

within() {
  case $1 in
    "$2" | "$2"/*) return 0 ;;
  esac
  return 1
}

normalise() {
  out=
  rest=${1#/}
  while [ -n "$rest" ]; do
    seg=${rest%%/*}
    case $rest in
      */*) rest=${rest#*/} ;;
      *) rest= ;;
    esac
    case $seg in
      '' | .) ;;
      ..) out=${out%/*} ;;
      *) out=$out/$seg ;;
    esac
  done
  printf '%s\n' "${out:-/}"
}

top=$(git -C "$cwd" rev-parse --show-toplevel 2>/dev/null) || exit 0
top=$(resolve "$top")
common=$(git -C "$top" rev-parse --path-format=absolute --git-common-dir 2>/dev/null) || common=$top/.git
main=$(resolve "${common%/*}")
[ "$main" != "$top" ] || exit 0

scope_file=
for candidate in "$common"/countersign/scope.d/*; do
  [ -f "$candidate" ] || continue
  home=$(awk -F'\t' '$1 == "home" { print $2; exit }' "$candidate")
  case $top in
    "$home"/.claude/worktrees/agent-*) ;;
    *) continue ;;
  esac
  plan=$(awk -F'\t' '$1 == "plan" { print $2; exit }' "$candidate")
  [ -f "$plan" ] || continue
  approved=$(awk -F'\t' '$1 == "approved" { print $2; exit }' "$candidate")
  current=$(awk '/^Approved: / { hash = $2 } END { print hash }' "$plan")
  [ "$approved" = "$current" ] || continue
  scope_file=$candidate
  break
done
[ -n "$scope_file" ] || exit 0

sensitive_kind() {
  lower=$(printf '%s' "$1" | tr 'A-Z' 'a-z')
  case $lower in
    migrations/* | */migrations/*)
      echo migrations
      return
      ;;
    .github/workflows/*)
      echo "CI workflow"
      return
      ;;
    .github/rulesets/*)
      echo ruleset
      return
      ;;
    messages/en.json | */messages/en.json | locales/en/* | */locales/en/*)
      echo "i18n source keys"
      return
      ;;
  esac
  case ${lower##*/} in
    package.json | package-lock.json | npm-shrinkwrap.json | pnpm-lock.yaml | pnpm-workspace.yaml | yarn.lock | bun.lock | bun.lockb | requirements*.txt | pyproject.toml | poetry.lock | uv.lock | pipfile | pipfile.lock | gemfile | gemfile.lock | go.mod | go.sum | cargo.toml | cargo.lock | podfile | podfile.lock)
      echo dependencies
      ;;
    .env | .env.* | *.config.* | settings.json | settings.local.json)
      echo "env and config"
      ;;
    openapi.* | *.openapi.* | swagger.* | *.graphql | *.gql | *.prisma)
      echo "API contract"
      ;;
  esac
}

matches() {
  REL=$1 awk -F'\t' -v kinds="$2" '
    index(kinds, "," $1 ",") > 0 && $2 != "" && ENVIRON["REL"] ~ $2 { found = 1 }
    END { exit !found }
  ' "$scope_file"
}

IFS='
'
set -f
for path in $paths; do
  target=$(resolve "$path")
  hops=0
  while [ -L "$target" ] && [ "$hops" -lt 8 ]; do
    link=$(readlink "$target")
    case $link in
      /*) ;;
      *) link=${target%/*}/$link ;;
    esac
    target=$(normalise "$(resolve "$link")")
    hops=$((hops + 1))
  done
  within "$target" "$top" || continue
  [ "$target" != "$top" ] || continue
  rel=${target#"$top"/}
  if ! matches "$rel" ",allow,named,"; then
    echo "scope denied: $rel is outside the approved plan's scope for this batch ($plan). Return to planning: stop, and report the file and why the unit needs it."
    exit 10
  fi
  kind=$(sensitive_kind "$rel")
  if [ -n "$kind" ] && ! matches "$rel" ",named,"; then
    echo "scope denied: $rel is a sensitive surface ($kind) that the approved plan names no line for ($plan). Return to planning: stop, and report the file and why the unit needs it."
    exit 10
  fi
done
exit 0
