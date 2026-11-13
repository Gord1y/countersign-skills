#!/bin/sh
set -eu
LC_ALL=C
export LC_ALL

event=$(cat)
paths=$(printf '%s' "$event" | jq -r '.paths[]?')
[ -n "$paths" ] || exit 0

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

marker=/.claude/worktrees/agent-
scope_file=
plan=
root=

load_fence() {
  [ -d "$2" ] || return 1
  top=$(git -C "$2" rev-parse --show-toplevel 2>/dev/null) || return 1
  [ "$(resolve "$top")" = "$2" ] || return 1
  common=$(git -C "$2" rev-parse --path-format=absolute --git-common-dir 2>/dev/null) || return 1
  for candidate in "$common"/countersign/scope.d/*; do
    [ -f "$candidate" ] || continue
    home=$(awk -F'\t' '$1 == "home" { print $2; exit }' "$candidate")
    [ "$home" = "$1" ] || continue
    plan=$(awk -F'\t' '$1 == "plan" { print $2; exit }' "$candidate")
    [ -f "$plan" ] || continue
    approved=$(awk -F'\t' '$1 == "approved" { print $2; exit }' "$candidate")
    current=$(awk '/^Approved: / { hash = $2 } END { print hash }' "$plan")
    [ "$approved" = "$current" ] || continue
    scope_file=$candidate
    root=$2
    return 0
  done
  return 1
}

fence_for() {
  prefix=
  remainder=$1
  while :; do
    case $remainder in
      *"$marker"*) ;;
      *) return 1 ;;
    esac
    prefix=$prefix${remainder%%"$marker"*}
    remainder=${remainder#*"$marker"}
    if load_fence "$prefix" "$prefix/.claude/worktrees/agent-${remainder%%/*}"; then
      return 0
    fi
    prefix=$prefix$marker
  done
}

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

while IFS= read -r path; do
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
  fence_for "$target" || continue
  within "$target" "$root" || continue
  [ "$target" != "$root" ] || continue
  rel=${target#"$root"/}
  if ! matches "$rel" ",allow,named,"; then
    echo "scope denied: $rel is outside the approved plan's scope for this batch ($plan). Return to planning: stop, and report the file and why the unit needs it."
    exit 10
  fi
  kind=$(sensitive_kind "$rel")
  if [ -n "$kind" ] && ! matches "$rel" ",named,"; then
    echo "scope denied: $rel is a sensitive surface ($kind) that the approved plan names no line for ($plan). Return to planning: stop, and report the file and why the unit needs it."
    exit 10
  fi
done <<EOF
$paths
EOF
exit 0
