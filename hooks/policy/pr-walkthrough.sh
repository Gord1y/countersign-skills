#!/bin/sh
set -u
set -f
LC_ALL=C
export LC_ALL

ui_pattern='\.(tsx|jsx|vue|svelte|css|scss|html)$'

event=$(cat)
tool=$(printf '%s' "$event" | jq -r '.tool')
[ "$tool" = shell ] || exit 0
command=$(printf '%s' "$event" | jq -r '.command')
cwd=$(printf '%s' "$event" | jq -r '.cwd')

has_walkthrough() {
  awk '
    { line = tolower($0) }
    line ~ /^[ \t]*#/ { open = 0 }
    index(line, "walkthrough") { open = 1 }
    open && line ~ /https?:\/\/[^ \t]/ { found = 1 }
    END { exit found ? 0 : 1 }'
}

segments=$(printf '%s\n' "$command" | awk '{ gsub(/&&|\|\||;|\|/, "\n"); print }')

base=
head=
body_file=
found=
while IFS= read -r segment; do
  printf '%s\n' "$segment" | grep -Eq '^[[:space:]]*([^[:space:]]*/)?gh[[:space:]]+pr[[:space:]]+create([[:space:]]|$)' || continue
  found=yes
  set -- $segment
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
      --body-file | -F)
        body_file=${2:-}
        shift
        ;;
      --body-file=*) body_file=${1#--body-file=} ;;
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

names=$(git -C "$cwd" diff --name-only "$base_ref...$head_ref" 2>/dev/null) || exit 0
ui_files=$(printf '%s\n' "$names" | grep -E "$ui_pattern") || exit 0
count=$(printf '%s\n' "$ui_files" | wc -l | tr -d ' ')
first=$(printf '%s\n' "$ui_files" | head -n 1)

printf '%s\n' "$command" | has_walkthrough && exit 0

body_file=${body_file#[\"\']}
body_file=${body_file%[\"\']}
if [ -n "$body_file" ] && [ "$body_file" != - ]; then
  case $body_file in
    /*) ;;
    *) body_file=$cwd/$body_file ;;
  esac
  if [ -f "$body_file" ] && has_walkthrough <"$body_file"; then
    exit 0
  fi
fi

echo "PR touches $count UI file(s), $first first, and its body has no walkthrough. Add a \"## Walkthrough\" section to the body with screenshots of every changed state in light and dark, or a link to a walkthrough that shows them (the walkthrough skill builds one), then create the PR again. --fill alone never passes for a UI change."
exit 10
