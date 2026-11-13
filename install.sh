#!/bin/sh
set -eu

root=$(cd "$(dirname "$0")" && pwd)
# shellcheck source=lib.sh
. "$root/lib.sh"
only=
mode="link"
settings=yes
new_addition=
codex_compact_limit=200000

usage() {
  echo "usage: install.sh [--copy] [--skills name,name,...] [--no-settings] [--addition <folder>]"
  echo "--copy copies each of this repo's skills instead of linking it and records it for later updates."
  echo "--addition <folder> records a folder in this repo's layout (skills.tsv and skills/, rules.tsv"
  echo "and rules/, agents/) whose skills, rules and agents install alongside, on this and every later run."
  echo "Links each agent in agents/ into ~/.claude/agents."
  echo "Links each skill into the skill folder of every installed agent that supports it, writes"
  echo "the file ~/.claude/CLAUDE.md from the profile's CLAUDE.md (else claude/CLAUDE.template.md) plus each addition's rules,"
  echo "links bin/* and the profile's bin/* into ~/.local/bin, and generates ~/.codex/AGENTS.md and"
  echo "the file ~/.gemini/GEMINI.md from it with the rules each agent takes."
  echo "Merges claude/settings.json, then the profile's settings.json, into ~/.claude/settings.json,"
  echo "unless --no-settings."
  echo "When ~/.codex exists, also writes a managed block at the top of ~/.codex/config.toml and merges"
  echo "codex/hooks.json into ~/.codex/hooks.json, unless --no-settings. The profile's codex/config.toml"
  echo "adds its top-level keys to that block and upserts its table keys into ~/.codex/config.toml."
  echo "The profile is $profile; state, backups and the record of merged settings are in $state."
}

while [ $# -gt 0 ]; do
  case $1 in
    --copy)
      mode=copy
      ;;
    --no-settings)
      settings=no
      ;;
    --skills)
      shift
      only=${1:-}
      ;;
    --addition)
      shift
      if [ -z "${1:-}" ] || [ ! -d "$1" ]; then
        echo "install.sh: --addition needs an existing folder" >&2
        exit 2
      fi
      new_addition=$(cd "$1" && pwd)
      ;;
    -h | --help)
      usage
      exit 0
      ;;
    *)
      echo "install.sh: unknown option $1" >&2
      usage >&2
      exit 2
      ;;
  esac
  shift
done

work=$(mktemp -d "${TMPDIR:-/tmp}/countersign-skills.XXXXXX")
trap 'rm -rf "$work"' EXIT
codex_fragment="$work/codex-fragment.tsv"
: >"$codex_fragment"
if [ "$settings" = yes ] && [ -f "$codex_fragment_file" ]; then
  parse_codex_fragment "$codex_fragment_file" >"$codex_fragment" || exit 1
fi
codex_block_keys="$codex_block_keys$(awk -F "$tab" '$1 == "" { printf "|%s", $2 }' "$codex_fragment")"

mkdir -p "$state"

if [ -n "$new_addition" ]; then
  if [ "$new_addition" = "$root" ]; then
    echo "install.sh: $new_addition is this repo, not an addition" >&2
    exit 2
  fi
  if ! grep -qxF "$new_addition" "$additions" 2>/dev/null; then
    echo "$new_addition" >>"$additions"
    echo "added   $new_addition"
  fi
fi

sources() {
  echo "$root"
  [ -f "$additions" ] || return 0
  while IFS= read -r source; do
    [ -n "$source" ] || continue
    if [ -d "$source" ]; then
      echo "$source"
    else
      echo "install.sh: skipping the addition $source, which no longer exists" >&2
    fi
  done <"$additions"
}

sources >"$work/sources"
: >"$work/links"

wanted() {
  [ -z "$only" ] && return 0
  case ",$only," in
    *",$1,"*) return 0 ;;
  esac
  return 1
}

claim() {
  if grep -qxF "$1" "$work/links"; then
    echo "install.sh: two sources both install $1; rename one of them" >&2
    exit 1
  fi
  echo "$1" >>"$work/links"
}

link_one() {
  src=$1
  dest=$2
  agent=$3
  claim "$dest"
  if [ -L "$dest" ] && [ "$(readlink "$dest")" = "$src" ]; then
    echo "ok      $dest"
    return
  fi
  if tracked "$agent" "$(basename "$dest")"; then
    forget "$agent" "$(basename "$dest")"
  fi
  back_up "$dest" "$agent"
  mkdir -p "$(dirname "$dest")"
  ln -s "$src" "$dest"
  echo "linked  $dest"
}

copy_one() {
  src=$1
  dest=$2
  agent=$3
  skill=$4
  version=$5
  claim "$dest"
  if tracked "$agent" "$skill"; then
    echo "ok      $dest (copy)"
    return
  fi
  back_up "$dest" "$agent"
  mkdir -p "$(dirname "$dest")"
  cp -R "$src" "$dest"
  rm -f "$dest/local.md"
  rm -rf "$state/base/$agent/$skill"
  mkdir -p "$state/base/$agent"
  cp -R "$src" "$state/base/$agent/$skill"
  rm -f "$state/base/$agent/$skill/local.md"
  (cd "$dest" && find . -type f) | sed 's|^\./||' | sort | while IFS= read -r file; do
    printf '%s\t%s\t%s\t%s\t%s\n' "$agent" "$skill" "$version" "$file" "$(sha256_of "$dest/$file")" >>"$manifest"
  done
  echo "copied  $dest"
}

install_skills() {
  source=$1
  [ -f "$source/skills.tsv" ] || return 0
  while IFS=$tab read -r name version agents; do
    [ -n "$name" ] || continue
    wanted "$name" || continue
    if [ ! -f "$source/skills/$name/SKILL.md" ]; then
      echo "install.sh: $source/skills.tsv lists $name but skills/$name/SKILL.md is missing" >&2
      exit 1
    fi
    for agent in $(echo "$agents" | tr ',' ' '); do
      dir=$(skills_dir "$agent")
      [ -n "$dir" ] || continue
      if [ "$mode" = copy ] && [ "$source" = "$root" ]; then
        copy_one "$source/skills/$name" "$dir/$name" "$agent" "$name" "$version"
      else
        link_one "$source/skills/$name" "$dir/$name" "$agent"
      fi
    done
  done <"$source/skills.tsv"
}

while IFS= read -r source; do
  install_skills "$source"
  for file in "$source"/agents/*.md; do
    [ -f "$file" ] || continue
    link_one "$file" "$claude_home/agents/$(basename "$file")" claude-agents
  done
done <"$work/sources"

for file in "$root"/bin/* "$profile"/bin/*; do
  [ -f "$file" ] || continue
  link_one "$file" "$HOME/.local/bin/$(basename "$file")" bin
done

cp "$work/sources" "$work/owners"
if [ -f "$sources_record" ]; then
  cat "$sources_record" >>"$work/owners"
fi

owned() {
  case $1 in
    "$profile/bin/"*) return 0 ;;
  esac
  while IFS= read -r source; do
    case $1 in
      "$source/skills/"* | "$source/agents/"* | "$source/bin/"*) return 0 ;;
    esac
  done <"$work/owners"
  return 1
}

for dir in "$(skills_dir claude)" "$(skills_dir codex)" "$(skills_dir antigravity)" "$claude_home/agents" "$HOME/.local/bin"; do
  [ -n "$dir" ] && [ -d "$dir" ] || continue
  for dest in "$dir"/*; do
    [ -L "$dest" ] && [ ! -e "$dest" ] || continue
    if owned "$(readlink "$dest")"; then
      rm "$dest"
      echo "removed $dest"
    fi
  done
done
cp "$work/sources" "$sources_record"

claude_template="$root/claude/CLAUDE.template.md"
if [ -f "$profile/CLAUDE.md" ]; then
  claude_template="$profile/CLAUDE.md"
fi

render_claude_md() {
  sed "s|{ROOT}|$root|g" "$claude_template"
  tail -n +2 "$work/sources" | while IFS= read -r source; do
    [ -f "$source/rules.tsv" ] || continue
    awk -F "$tab" -v source="$source" '
      { split($2, agents, ","); for (i in agents) if (agents[i] == "claude") print "@" source "/rules/" $1 ".md" }
    ' "$source/rules.tsv"
  done
}

claude_md="$claude_home/CLAUDE.md"
claude_md_generated="$work/CLAUDE.md"
render_claude_md >"$claude_md_generated"
keep_original "$claude_md" '^@.*/rules/[A-Za-z0-9_-]+\.md$'
if [ -f "$claude_md" ] && cmp -s "$claude_md_generated" "$claude_md"; then
  echo "ok      $claude_md"
else
  if [ -e "$claude_md" ]; then
    mkdir -p "$backup/claude-md"
    mv "$claude_md" "$backup/claude-md/"
    echo "moved   $claude_md to $backup/claude-md/"
  fi
  mkdir -p "$claude_home"
  cp "$claude_md_generated" "$claude_md"
  echo "wrote   $claude_md"
fi

merge_settings='
  def joined:
    ["permissions", "allow"], ["permissions", "ask"], ["permissions", "deny"],
    ["sandbox", "excludedCommands"],
    ["sandbox", "filesystem", "allowRead"], ["sandbox", "filesystem", "denyRead"],
    ["sandbox", "filesystem", "allowWrite"], ["sandbox", "filesystem", "denyWrite"],
    ["sandbox", "network", "allowedDomains"],
    ["autoMode", "environment"], ["autoMode", "allow"], ["hooks", "SessionEnd"],
    ["hooks", "PreToolUse"], ["hooks", "Stop"], ["hooks", "SubagentStop"];
  def lists($a; $b):
    reduce joined as $path (.;
      ([$a, $b] | map((try getpath($path) catch null) // []) | add | unique) as $merged
      | if $merged == [] then . else setpath($path; $merged) end);
  .[0] as $a | .[1] as $b | ($a * $b) | lists($a; $b)
'

write_settings() {
  src="$root/claude/settings.json"
  dest="$claude_home/settings.json"
  [ -f "$src" ] || return 0
  if ! command -v jq >/dev/null 2>&1; then
    echo "skipped $dest (jq not found)"
    return 0
  fi
  layer="$work/settings-layer.json"
  if [ -f "$profile/settings.json" ]; then
    jq -s "$merge_settings" "$src" "$profile/settings.json" >"$layer"
  else
    jq . "$src" >"$layer"
  fi
  user_tmp=$(getconf DARWIN_USER_TEMP_DIR 2>/dev/null || true)
  if [ -n "$user_tmp" ]; then
    jq --arg tmp "${user_tmp%/}" '.sandbox.filesystem.allowWrite = (((.sandbox.filesystem.allowWrite // []) + [$tmp]) | unique)' "$layer" >"$layer.tmp"
    mv "$layer.tmp" "$layer"
  fi
  skill_folders=$(
    echo "$claude_home/skills"
    while IFS= read -r source; do
      echo "$source/skills"
      echo "$(cd "$source" && pwd -P)/skills"
    done <"$work/sources"
  )
  jq --arg folders "$skill_folders" '.permissions.allow = (((.permissions.allow // []) + ($folders | split("\n") | map("Read(/" + . + "/**)"))) | unique)' "$layer" >"$layer.tmp"
  mv "$layer.tmp" "$layer"
  if [ ! -e "$settings_record" ]; then
    keep_original "$dest" ""
  fi
  current="$work/settings-current.json"
  if [ -f "$dest" ]; then cp "$dest" "$current"; else echo '{}' >"$current"; fi
  if [ -f "$settings_record" ]; then
    original="$work/settings-original.json"
    if [ -f "$originals/settings.json" ]; then cp "$originals/settings.json" "$original"; else echo '{}' >"$original"; fi
    jq -s "$unmerge_settings" "$current" "$settings_record" "$original" >"$current.tmp"
    mv "$current.tmp" "$current"
  fi
  generated="$work/settings.json"
  jq -s "$merge_settings" "$current" "$layer" >"$generated"
  cp "$layer" "$settings_record"
  if [ -f "$dest" ] && cmp -s "$generated" "$dest"; then
    echo "ok      $dest"
    return 0
  fi
  if [ -e "$dest" ]; then
    mkdir -p "$backup/claude-settings"
    cp "$dest" "$backup/claude-settings/settings.json"
    echo "saved   $dest to $backup/claude-settings/"
  fi
  mkdir -p "$claude_home"
  cp "$generated" "$dest"
  echo "wrote   $dest"
}

codex_block() {
  echo "$codex_block_begin"
  printf '%s\n' "model_auto_compact_token_limit = $codex_compact_limit" 'approval_policy = "never"' 'sandbox_mode = "workspace-write"' |
    awk -v fragment_file="$codex_fragment" '
      BEGIN {
        while ((getline row < fragment_file) > 0) {
          if (substr(row, 1, 1) != "\t") continue
          row = substr(row, 2)
          position = index(row, "\t")
          count++
          order[count] = substr(row, 1, position - 1)
          profile[order[count]] = substr(row, position + 1)
        }
      }
      {
        name = $0
        sub(/[ \t]*=.*/, "", name)
        if (name in profile) {
          print profile[name]
          used[name] = 1
        } else {
          print
        }
      }
      END {
        for (i = 1; i <= count; i++) {
          if (!(order[i] in used)) print profile[order[i]]
        }
      }
    '
  echo "$codex_block_end"
}

write_codex_config() {
  [ -d "$codex_home" ] || return 0
  if [ -f "$codex_config" ] && grep -Eq "^[ $tab]*\[[ $tab]*($codex_block_keys)([].]|[ $tab])" "$codex_config"; then
    echo "skipped $codex_config (it sets a key of the managed block as a table)"
    return 0
  fi
  generated="$work/codex-config.toml"
  displaced="$work/codex-displaced"
  : >"$displaced"
  held="$work/codex-displaced-held"
  restored="$work/codex-displaced-restored"
  : >"$held"
  : >"$restored"
  if [ -f "$codex_displaced" ]; then
    split_codex_displaced "$codex_displaced" "$held" "$restored"
  fi
  codex_block >"$generated"
  cat "$restored" >>"$generated"
  if [ -f "$codex_config" ]; then
    strip_codex_block "$codex_config" "$work/codex-displaced-new" >>"$generated"
    split_codex_displaced "$work/codex-displaced-new" "$displaced" "$work/codex-displaced-unused" "$held"
  fi
  if ! strip_codex_block "$generated" "" check >/dev/null; then
    echo "skipped $codex_config (could not place the managed block safely; set the keys of the managed block yourself)"
    return 0
  fi
  reconciled="$work/codex-config-reconciled.toml"
  reconcile_codex_tables "$generated" "$codex_fragment" "$codex_upserts" "$work/codex-upserts.tsv" >"$reconciled"
  mv "$reconciled" "$generated"
  if [ -s "$work/codex-upserts.tsv" ]; then
    cp "$work/codex-upserts.tsv" "$codex_upserts"
  else
    rm -f "$codex_upserts"
  fi
  if [ -f "$codex_config" ] && cmp -s "$generated" "$codex_config"; then
    echo "ok      $codex_config"
    return 0
  fi
  if [ -s "$restored" ]; then
    echo "restored the values you had in $codex_config for keys the block no longer holds"
  fi
  if [ -s "$displaced" ]; then
    echo "kept    your $codex_config values for the block's keys in $codex_displaced"
  fi
  cat "$held" "$displaced" >"$work/codex-displaced-next"
  if [ -s "$work/codex-displaced-next" ]; then
    cp "$work/codex-displaced-next" "$codex_displaced"
  else
    rm -f "$codex_displaced"
  fi
  if [ -e "$codex_config" ]; then
    mkdir -p "$backup/codex"
    cp "$codex_config" "$backup/codex/config.toml"
    echo "saved   $codex_config to $backup/codex/"
  fi
  cp "$generated" "$codex_config"
  echo "wrote   $codex_config"
}

write_codex_hooks() {
  [ -d "$codex_home" ] || return 0
  layer="$root/codex/hooks.json"
  [ -f "$layer" ] || return 0
  if ! command -v jq >/dev/null 2>&1; then
    echo "skipped $codex_hooks (jq not found)"
    return 0
  fi
  current="$work/codex-hooks-current.json"
  previous="$work/codex-hooks-previous.json"
  generated="$work/codex-hooks.json"
  if [ -s "$codex_hooks" ]; then cp "$codex_hooks" "$current"; else echo '{}' >"$current"; fi
  if [ -s "$codex_hooks_record" ]; then cp "$codex_hooks_record" "$previous"; else echo '{}' >"$previous"; fi
  if ! jq -s "$merge_codex_hooks" "$current" "$layer" "$previous" >"$generated" 2>/dev/null; then
    echo "skipped $codex_hooks (not valid JSON)"
    return 0
  fi
  cp "$layer" "$codex_hooks_record"
  if [ -f "$codex_hooks" ] && cmp -s "$generated" "$codex_hooks"; then
    echo "ok      $codex_hooks"
    return 0
  fi
  if [ -e "$codex_hooks" ]; then
    mkdir -p "$backup/codex"
    cp "$codex_hooks" "$backup/codex/hooks.json"
    echo "saved   $codex_hooks to $backup/codex/"
  fi
  cp "$generated" "$codex_hooks"
  echo "wrote   $codex_hooks"
  echo "trust   start codex and pick \"Review hooks\" or \"Trust all and continue\": Codex skips hooks in $codex_hooks until you trust them"
}

if [ "$settings" = yes ]; then
  write_settings
  write_codex_config
  write_codex_hooks
fi

rule_agents() {
  awk -F "$tab" -v name="$2" '$1 == name { print $2 }' "$1"
}

render_instructions() {
  agent=$1
  echo "<!-- Generated by $root/install.sh from $claude_md. Edit that file or $root/rules, then run install.sh again. -->"
  echo
  while IFS= read -r line || [ -n "$line" ]; do
    case $line in
      @*)
        path=${line#@}
        case $path in
          \~/*) path="$HOME/${path#\~/}" ;;
        esac
        rules_dir=$(dirname "$path")
        rules_tsv="$(dirname "$rules_dir")/rules.tsv"
        if [ "$(basename "$rules_dir")" = rules ] && [ -f "$rules_tsv" ]; then
          case ",$(rule_agents "$rules_tsv" "$(basename "$path" .md)")," in
            *",$agent,"*) ;;
            *) continue ;;
          esac
        fi
        if [ -f "$path" ]; then
          cat "$path"
          echo
        else
          echo "$line"
        fi
        ;;
      *) echo "$line" ;;
    esac
  done <"$claude_md"
}

write_instructions() {
  agent=$1
  dest=$(instructions_file "$agent")
  [ -n "$dest" ] || return 0
  generated="$work/instructions-$agent.md"
  render_instructions "$agent" >"$generated"
  keep_original "$dest" '^<!-- Generated by .*/install\.sh from '
  if [ -f "$dest" ] && cmp -s "$generated" "$dest"; then
    echo "ok      $dest"
    return
  fi
  if [ -e "$dest" ]; then
    mkdir -p "$backup/$agent"
    mv "$dest" "$backup/$agent/"
    echo "moved   $dest to $backup/$agent/"
  fi
  cp "$generated" "$dest"
  echo "wrote   $dest"
}

write_instructions codex
write_instructions antigravity
prune_backups
