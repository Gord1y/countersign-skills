#!/bin/sh
set -u
set -f
LC_ALL=C
export LC_ALL

limit=400
event=$(cat)
tool=$(printf '%s' "$event" | jq -r '.tool')
[ "$tool" = shell ] || exit 0
command=$(printf '%s' "$event" | jq -r '.command')
cwd=$(printf '%s' "$event" | jq -r '.cwd')

segments=$(printf '%s\n' "$command" | awk '{ gsub(/&&|\|\||;|\|/, "\n"); print }')

base=
head=
found=
while IFS= read -r segment; do
  [ -n "$segment" ] || continue
  set -- $segment
  [ $# -ge 3 ] || continue
  case $1 in
    gh | */gh) ;;
    *) continue ;;
  esac
  [ "$2" = pr ] && [ "$3" = create ] || continue
  found=yes
  shift 3
  while [ $# -gt 0 ]; do
    case $1 in
      --base | -B)
        base=${2:-}
        shift
        ;;
      --base=*) base=${1#--base=} ;;
      --head | -H)
        head=${2:-}
        shift
        ;;
      --head=*) head=${1#--head=} ;;
    esac
    shift
  done
  break
done <<SEGMENTS
$segments
SEGMENTS
[ -n "$found" ] || exit 0

if [ -z "$head" ]; then
  head=$(git -C "$cwd" symbolic-ref --short -q HEAD 2>/dev/null) || head=
fi
case $head in
  main | staging | release-*) exit 0 ;;
esac

if [ -z "$base" ]; then
  base=$(git -C "$cwd" symbolic-ref --short -q refs/remotes/origin/HEAD 2>/dev/null) || base=
  base=${base#origin/}
  [ -n "$base" ] || base=main
fi

if git -C "$cwd" rev-parse --verify -q "refs/remotes/origin/$base^{commit}" >/dev/null 2>&1; then
  base_ref=origin/$base
elif git -C "$cwd" rev-parse --verify -q "refs/heads/$base^{commit}" >/dev/null 2>&1; then
  base_ref=$base
else
  exit 0
fi

head_ref=HEAD
if [ -n "$head" ] && git -C "$cwd" rev-parse --verify -q "refs/heads/$head^{commit}" >/dev/null 2>&1; then
  head_ref=$head
fi

numstat=$(git -C "$cwd" diff --numstat --no-renames "$base_ref...$head_ref" 2>/dev/null) || exit 0

changed=$(printf '%s\n' "$numstat" | awk -F'\t' '
  NF < 3 || $1 == "-" { next }
  {
    path = $3
    count = split(path, part, "/")
    name = part[count]
    skip = 0
    if (name ~ /lock/) skip = 1
    if (name ~ /\.snap$/) skip = 1
    for (i = 1; i < count; i++) if (part[i] == "generated" || part[i] == "dist" || part[i] == "__generated__") skip = 1
    if (path ~ /(^|\/)messages\/[^\/]+\.json$/ && name != "en.json") skip = 1
    if (path ~ /(^|\/)locales\/[^\/]+\/[^\/]+\.json$/ && part[count - 1] != "en") skip = 1
    if (!skip) total += $1 + $2
  }
  END { print total + 0 }')

if [ "$changed" -gt "$limit" ]; then
  echo "PR too large: $changed changed lines against $base (limit $limit, lockfiles, generated files and translated catalogs excluded). Split it into stacked PRs of $limit lines or fewer, each one reviewable and green on its own."
  exit 10
fi
exit 0
