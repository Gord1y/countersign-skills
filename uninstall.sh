#!/bin/sh
set -eu

root=$(cd "$(dirname "$0")" && pwd)
# shellcheck source=lib.sh
. "$root/lib.sh"

usage() {
  echo "usage: uninstall.sh"
  echo "Undoes install.sh for this repo, its additions and the profile:"
  echo "- removes every link it made (skills, agents, bin) and moves its copies to the backup folder;"
  echo "- in ~/.claude/settings.json, puts back or removes each value the last install merged, unless"
  echo "  you changed it since;"
  echo "- puts back the CLAUDE.md, AGENTS.md and GEMINI.md you had before the first install, or moves"
  echo "  the generated ones to the backup folder."
  echo "Everything it replaces goes to $state/backups/<time>/ first. The profile and the list of"
  echo "additions are left alone, so install.sh can put everything back."
}

while [ $# -gt 0 ]; do
  case $1 in
    -h | --help)
      usage
      exit 0
      ;;
    *)
      echo "uninstall.sh: unknown option $1" >&2
      usage >&2
      exit 2
      ;;
  esac
done

work=$(mktemp -d "${TMPDIR:-/tmp}/countersign-skills.XXXXXX")
trap 'rm -rf "$work"' EXIT
echo "$root" >"$work/sources"
if [ -f "$additions" ]; then
  cat "$additions" >>"$work/sources"
fi
if [ -f "$sources_record" ]; then
  cat "$sources_record" >>"$work/sources"
fi

owned() {
  case $1 in
    "$profile/bin/"*) return 0 ;;
  esac
  while IFS= read -r source; do
    [ -n "$source" ] || continue
    case $1 in
      "$source/skills/"* | "$source/agents/"* | "$source/bin/"*) return 0 ;;
    esac
  done <"$work/sources"
  return 1
}

for dir in "$(skills_dir claude)" "$(skills_dir codex)" "$(skills_dir antigravity)" "$claude_home/agents" "$HOME/.local/bin"; do
  [ -n "$dir" ] && [ -d "$dir" ] || continue
  for dest in "$dir"/*; do
    [ -L "$dest" ] || continue
    if owned "$(readlink "$dest")"; then
      rm "$dest"
      echo "removed $dest"
    fi
  done
done

if [ -f "$manifest" ]; then
  awk -F "$tab" '!seen[$1 FS $2]++ { print $1 FS $2 }' "$manifest" >"$work/copies"
  while IFS=$tab read -r agent skill; do
    dir=$(skills_dir "$agent")
    if [ -n "$dir" ] && [ -d "$dir/$skill" ] && [ ! -L "$dir/$skill" ]; then
      back_up "$dir/$skill" "$agent"
    fi
  done <"$work/copies"
  rm -f "$manifest"
  rm -rf "$state/base"
fi

settings_file="$claude_home/settings.json"
if [ -f "$settings_record" ] && [ -f "$settings_file" ]; then
  if command -v jq >/dev/null 2>&1; then
    if [ -f "$originals/settings.json" ]; then
      cp "$originals/settings.json" "$work/original.json"
    else
      echo '{}' >"$work/original.json"
    fi
    jq -s "$unmerge_settings" "$settings_file" "$settings_record" "$work/original.json" >"$work/settings.json"
    mkdir -p "$backup/claude-settings"
    cp "$settings_file" "$backup/claude-settings/settings.json"
    if [ ! -f "$originals/settings.json" ] && [ "$(jq -c . "$work/settings.json")" = "{}" ]; then
      rm "$settings_file"
      echo "removed $settings_file"
    else
      cp "$work/settings.json" "$settings_file"
      echo "cleaned $settings_file"
    fi
    rm -f "$settings_record" "$originals/settings.json"
  else
    echo "skipped $settings_file (jq not found)"
  fi
fi

put_back() {
  dest=$1
  folder=$2
  [ -n "$dest" ] || return 0
  back_up "$dest" "$folder"
  if [ -f "$originals/$(basename "$dest")" ]; then
    mv "$originals/$(basename "$dest")" "$dest"
    echo "restored $dest"
  fi
}

put_back "$claude_home/CLAUDE.md" claude-md
put_back "$(instructions_file codex)" codex
put_back "$(instructions_file antigravity)" antigravity
