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

top=$(git -C "$cwd" rev-parse --show-toplevel 2>/dev/null) || exit 0
top=$(resolve "$top")
common=$(git -C "$top" rev-parse --path-format=absolute --git-common-dir 2>/dev/null) || common=$top/.git
main=$(resolve "${common%/*}")

worktree_only=no
list_file=${XDG_CONFIG_HOME:-$HOME/.config}/countersign/profile/worktree-only.tsv
if [ "$main" = "$top" ] && [ -f "$list_file" ]; then
  while IFS= read -r line || [ -n "$line" ]; do
    case $line in
      *[![:space:]]*) ;;
      *) continue ;;
    esac
    case $line in
      '#'*) continue ;;
      \~/*) line=$HOME/${line#\~/} ;;
    esac
    case $line in
      /*)
        if [ "$(resolve "$line")" = "$main" ]; then
          worktree_only=yes
        fi
        ;;
    esac
  done <"$list_file"
fi

uid=$(id -u)
other_places=
add_place() {
  place=$(resolve "$1")
  if [ "$place" != / ]; then
    other_places="$other_places$place
"
  fi
}
add_place "$HOME/.claude/plans"
add_place "$HOME/.claude/projects"
add_place "/private/tmp/claude-$uid"
add_place "/tmp/claude-$uid"
if [ -n "${TMPDIR:-}" ]; then
  add_place "$TMPDIR"
fi

in_other_place() {
  while IFS= read -r place; do
    if [ -n "$place" ] && ! within "$top" "$place" && within "$1" "$place"; then
      return 0
    fi
  done <<EOF
$other_places
EOF
  return 1
}

IFS='
'
set -f
for path in $paths; do
  target=$(resolve "$path")
  if in_other_place "$target"; then
    continue
  fi
  if within "$target" "$top"; then
    if [ "$worktree_only" = yes ] && ! within "$target" "$top/writeups"; then
      echo "write denied: $top is worktree-only. Make a worktree with \`git worktree add -b <branch> $top/.claude/worktrees/<name>\` or the EnterWorktree tool, then write there by absolute path."
      exit 10
    fi
    continue
  fi
  if [ "$main" != "$top" ] && within "$target" "$main/writeups"; then
    continue
  fi
  echo "write denied: $path is outside this repo ($top). Write inside the repo, ~/.claude/plans, the scratchpad or writeups/."
  exit 10
done
exit 0
