#!/bin/sh
set -u
set -f
LC_ALL=C
export LC_ALL

empty_tree=4b825dc642cb6eb9a060e54bf8d69288fbee4904

event=$(cat)
kind=$(printf '%s' "$event" | jq -r '.event')
provider=$(printf '%s' "$event" | jq -r '.provider')
subagent=$(printf '%s' "$event" | jq -r '.subagent')
session_id=$(printf '%s' "$event" | jq -r '.session_id')
cwd=$(printf '%s' "$event" | jq -r '.cwd')

top=$(git -C "$cwd" rev-parse --show-toplevel 2>/dev/null) || exit 0
git_dir=$(git -C "$top" rev-parse --absolute-git-dir 2>/dev/null) || exit 0
common=$(git -C "$top" rev-parse --path-format=absolute --git-common-dir 2>/dev/null) || exit 0

tree_hash() {
  index=$(mktemp "${TMPDIR:-/tmp}/gate-index.XXXXXX") || return 1
  trap 'rm -f "$index"' EXIT
  trap 'exit 1' INT TERM
  if [ -e "$git_dir/index" ]; then
    cp -p "$git_dir/index" "$index" || return 1
  else
    rm -f "$index"
  fi
  GIT_INDEX_FILE=$index git -C "$top" add -A -- . >/dev/null 2>&1 || return 1
  GIT_INDEX_FILE=$index git -C "$top" rm -r -q -f --cached --ignore-unmatch -- .claude/worktrees >/dev/null 2>&1 || return 1
  tree=$(GIT_INDEX_FILE=$index git -C "$top" write-tree 2>/dev/null) || return 1
  [ -n "$tree" ] || return 1
  printf '%s\n' "$tree"
}

gate_line() {
  tr -d '\r' <"$1" | awk '
    /^```/ { fence = !fence; next }
    fence { next }
    /^## / { in_gates = ($0 ~ /^## Gates[[:space:]]*$/); next }
    /^# / { in_gates = 0; next }
    in_gates && /^gate:[[:space:]]*[^[:space:]]/ {
      line = $0
      sub(/^gate:[[:space:]]*/, "", line)
      sub(/[[:space:]]+$/, "", line)
      print line
      exit
    }'
}

sessions=$git_dir/countersign/sessions
case $session_id in
  '' | .* | *[!A-Za-z0-9._-]*)
    safe_id=
    base_file=
    told=
    ;;
  *)
    safe_id=yes
    base_file=$sessions/$session_id
    told=$base_file.$provider.told
    ;;
esac

record_base() {
  mkdir -p "$sessions" || return 1
  printf '%s\n' "$1" >"$base_file.$$" || return 1
  ln "$base_file.$$" "$base_file" 2>/dev/null
  rm -f "$base_file.$$"
  return 0
}

mark_blocked() {
  [ -z "$blocked" ] || { mkdir -p "$sessions" && : >"$blocked"; }
}

if [ "$kind" = pre_tool ]; then
  if [ -n "$safe_id" ] && [ ! -f "$base_file" ]; then
    first=$(tree_hash) || exit 0
    record_base "$first" || exit 0
    find "$sessions" -type f -mtime +30 -exec rm -f {} + 2>/dev/null
  fi
  exit 0
fi

[ "$kind" = stop ] || exit 0

if [ "$subagent" = true ]; then
  [ "$git_dir" != "$common" ] || exit 0
  base=$(git -C "$top" rev-parse -q --verify 'HEAD^{tree}' 2>/dev/null) || base=$empty_tree
else
  [ -n "$safe_id" ] || exit 0
  if [ ! -f "$base_file" ]; then
    first=$(tree_hash) || exit 0
    record_base "$first"
    exit 0
  fi
  base=$(head -n 1 "$base_file")
fi

current=$(tree_hash) || exit 0
[ "$current" != "$base" ] || exit 0
[ ! -f "$common/countersign/gate/$current" ] || exit 0

blocked=
if [ -n "$safe_id" ]; then
  blocked=$base_file.$provider.$current.blocked
  [ ! -f "$blocked" ] || exit 0
fi

instruction_file=
name=CLAUDE.md
if [ -e "$top/CLAUDE.md" ]; then
  instruction_file=$top/CLAUDE.md
elif [ -e "$top/AGENTS.md" ]; then
  instruction_file=$top/AGENTS.md
  name=AGENTS.md
fi
command=
if [ -n "$instruction_file" ]; then
  command=$(gate_line "$instruction_file")
fi

if [ -z "$command" ]; then
  [ "$subagent" != true ] || exit 0
  [ ! -f "$told" ] || exit 0
  mkdir -p "$sessions" && : >"$told"
  mark_blocked
  printf 'Gate: %s has no gate line. Add one line under "## Gates" in %s, in the form "gate: <command that runs all of the repo'"'"'s gates>". Then run `gate`.\n' "$name" "$name"
  exit 10
fi

mark_blocked
if [ "$subagent" = true ]; then
  printf 'Gate: this worktree has uncommitted changes and no gate has passed on them. Run `gate` in %s before you hand back; it runs "%s" and stamps the tree.\n' "$top" "$command"
else
  printf 'Gate: this session changed the working tree and no gate has passed on it. Run `gate` before you report the work as done; it runs "%s" and stamps the tree. If this turn reports nothing as done, end it again.\n' "$command"
fi
exit 10
