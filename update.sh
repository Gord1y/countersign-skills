#!/bin/sh
set -eu

root=$(cd "$(dirname "$0")" && pwd)
# shellcheck source=lib.sh
. "$root/lib.sh"

usage() {
  echo "usage: update.sh"
  echo "Updates every skill that install.sh --copy installed to the version in this repo. Files you"
  echo "did not edit are replaced; files you edited are merged with git merge-file, and your version"
  echo "is kept next to them as <file>.mine. local.md is never touched."
}

while [ $# -gt 0 ]; do
  case $1 in
    -h | --help)
      usage
      exit 0
      ;;
    *)
      echo "update.sh: unknown option $1" >&2
      usage >&2
      exit 2
      ;;
  esac
done

if [ ! -s "$manifest" ]; then
  echo "update.sh: nothing to update (no copies installed)"
  exit 0
fi

work=$(mktemp -d "${TMPDIR:-/tmp}/countersign-skills.XXXXXX")
trap 'rm -rf "$work"' EXIT
: >"$work/empty"

joined() {
  if [ -s "$1" ]; then
    paste -sd, "$1" | sed 's/,/, /g'
  fi
}

recorded_digest() {
  awk -F "$tab" -v agent="$1" -v skill="$2" -v file="$3" '$1 == agent && $2 == skill && $4 == file { print $5 }' "$manifest"
}

merge_one() {
  target=$1
  base_file=$2
  new_file=$3
  label_old=$4
  label_new=$5
  if [ -e "$target.mine" ]; then
    (back_up "$target.mine" "$agent") >/dev/null
  fi
  cp "$target" "$target.mine"
  merge_status=0
  git merge-file -L yours -L "shipped $label_old" -L "shipped $label_new" "$target" "$base_file" "$new_file" || merge_status=$?
  if [ "$merge_status" -gt 127 ]; then
    echo "update.sh: git merge-file failed on $target" >&2
    exit 2
  fi
}

record_merge() {
  if [ "$merge_status" -eq 0 ]; then
    echo "$1" >>"$work/merged"
  else
    echo "$1" >>"$work/conflicted"
    conflicts=$((conflicts + merge_status))
  fi
}

handle_file() {
  file=$1
  new_file="$newdir/$file"
  base_file="$basedir/$file"
  target="$skill_dir/$file"
  recorded=$(recorded_digest "$agent" "$skill" "$file")
  if [ -f "$new_file" ]; then
    if [ -z "$recorded" ]; then
      if [ ! -e "$target" ]; then
        mkdir -p "$(dirname "$target")"
        cp "$new_file" "$target"
        changed=1
      elif ! cmp -s "$new_file" "$target"; then
        merge_one "$target" "$work/empty" "$new_file" "$old" "$new"
        record_merge "$file"
      fi
    elif [ ! -e "$target" ]; then
      mkdir -p "$(dirname "$target")"
      cp "$new_file" "$target"
      changed=1
    elif [ "$(sha256_of "$target")" = "$recorded" ]; then
      if ! cmp -s "$new_file" "$target"; then
        cp "$new_file" "$target"
        changed=1
      fi
    elif ! cmp -s "$new_file" "$base_file"; then
      if [ ! -f "$base_file" ]; then
        base_file="$work/empty"
      fi
      merge_one "$target" "$base_file" "$new_file" "$old" "$new"
      record_merge "$file"
    fi
  elif [ -e "$target" ]; then
    if [ "$(sha256_of "$target")" = "$recorded" ]; then
      rm -f "$target"
      changed=1
    else
      echo "$file" >>"$work/kept"
    fi
  fi
}

update_pair() {
  agent=$1
  skill=$2
  dir=$(skills_dir "$agent")
  if [ -z "$dir" ]; then
    echo "skipped $agent $skill: $agent is not installed"
    return
  fi
  skill_dir="$dir/$skill"
  if [ -L "$skill_dir" ] || [ ! -e "$skill_dir" ]; then
    forget "$agent" "$skill"
    echo "forgot  $agent $skill: no longer a copy"
    return
  fi
  new=$(awk -F "$tab" -v skill="$skill" '$1 == skill { print $2 }' "$root/skills.tsv")
  if [ -z "$new" ] || [ ! -d "$root/skills/$skill" ]; then
    forget "$agent" "$skill"
    echo "kept    $agent $skill: no longer shipped; your copy stays as it is"
    return
  fi
  newdir="$root/skills/$skill"
  basedir="$state/base/$agent/$skill"
  old=$(awk -F "$tab" -v agent="$agent" -v skill="$skill" '$1 == agent && $2 == skill { print $3; exit }' "$manifest")
  (
    cd "$newdir"
    find . -type f | sed 's|^\./||' | grep -v '^local\.md$' || true
    awk -F "$tab" -v agent="$agent" -v skill="$skill" '$1 == agent && $2 == skill { print $4 }' "$manifest"
  ) | sort -u >"$work/files"
  changed=0
  conflicts=0
  : >"$work/merged"
  : >"$work/conflicted"
  : >"$work/kept"
  while IFS= read -r file; do
    handle_file "$file"
  done <"$work/files"
  forget "$agent" "$skill"
  mkdir -p "$state/base/$agent"
  cp -R "$newdir" "$basedir"
  rm -f "$basedir/local.md"
  (cd "$basedir" && find . -type f) | sed 's|^\./||' | sort | while IFS= read -r file; do
    printf '%s\t%s\t%s\t%s\t%s\n' "$agent" "$skill" "$new" "$file" "$(sha256_of "$basedir/$file")" >>"$manifest"
  done
  merged_files=$(joined "$work/merged")
  conflict_files=$(joined "$work/conflicted")
  kept_files=$(joined "$work/kept")
  suffix=
  if [ -n "$kept_files" ]; then
    suffix=" (kept: $kept_files)"
  fi
  if [ -n "$conflict_files" ]; then
    mine_files=$(echo "$conflict_files" | sed 's/, /.mine, /g').mine
    echo "conflict $agent $skill $old -> $new: $conflicts conflicts marked in $conflict_files; your version is in $mine_files$suffix"
    any_conflict=1
  elif [ -n "$merged_files" ]; then
    mine_files=$(echo "$merged_files" | sed 's/, /.mine, /g').mine
    echo "merged  $agent $skill $old -> $new: your edits merged into $merged_files; your version is in $mine_files$suffix"
  elif [ "$changed" -eq 1 ]; then
    echo "updated $agent $skill $old -> $new$suffix"
  else
    echo "ok      $agent $skill $new$suffix"
  fi
}

awk -F "$tab" '!seen[$1 FS $2]++ { print $1 FS $2 }' "$manifest" >"$work/pairs"
any_conflict=0
while IFS=$tab read -r pair_agent pair_skill; do
  update_pair "$pair_agent" "$pair_skill"
done <"$work/pairs"

prune_backups
[ "$any_conflict" -eq 0 ] || exit 1
