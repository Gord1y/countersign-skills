#!/bin/sh
set -eu

check=0
folder=
for arg in "$@"; do
  case "$arg" in
    --check) check=1 ;;
    *) folder=$arg ;;
  esac
done
if [ -z "$folder" ]; then
  folder=$(cd "$(dirname "$0")/.." && pwd)
else
  folder=$(cd "$folder" && pwd)
fi
target="$folder/catalog.json"
tab=$(printf '\t')

die() {
  echo "catalog.sh: $1" >&2
  exit 1
}

fm_get() {
  fm_rel=$1
  fm_key=$2
  fm_required=$3
  fm_has=0
  fm_val=
  fm_out=$(awk -v key="$fm_key" '
    NR == 1 { if ($0 != "---") { print "M1"; exit } ; next }
    $0 == "---" { print "M" NR; exit }
    index($0, key ": ") == 1 {
      value = substr($0, length(key) + 3)
      if (value ~ /^[>|]/) { print "E" NR " is a block scalar, which catalog.sh does not read"; exit }
      if (value ~ /^'\''/) { print "E" NR " is a single-quoted value, which catalog.sh does not read"; exit }
      if (length(value) >= 2 && substr(value, 1, 1) == "\"" && substr(value, length(value), 1) == "\"") {
        value = substr(value, 2, length(value) - 2)
      }
      print "V" value
      exit
    }
  ' "$folder/$fm_rel")
  case "$fm_out" in
    V*)
      fm_has=1
      fm_val=${fm_out#V}
      ;;
    E*)
      fm_line=${fm_out#E}
      fm_line=${fm_line%% *}
      die "$fm_rel:$fm_line: $fm_key ${fm_out#E"$fm_line" }"
      ;;
    M*)
      if [ "$fm_required" = 1 ]; then
        die "$fm_rel:${fm_out#M}: frontmatter has no $fm_key"
      fi
      ;;
    *)
      if [ "$fm_required" = 1 ]; then
        die "$fm_rel:1: frontmatter has no $fm_key"
      fi
      ;;
  esac
}

skills=
if [ -f "$folder/skills.tsv" ]; then
  while IFS=$tab read -r name version agents || [ -n "$name" ]; do
    rel="skills/$name/SKILL.md"
    [ -f "$folder/$rel" ] || die "$rel:1: skills.tsv lists $name but the file is missing"
    fm_get "$rel" description 1
    description=$fm_val
    fm_get "$rel" when_to_use 0
    when_has=$fm_has
    when_to_use=$fm_val
    fm_get "$rel" disable-model-invocation 0
    invocation=model
    [ "$fm_val" = true ] && invocation=manual
    entry=$(jq -cn --arg name "$name" --arg version "$version" --arg agents "$agents" \
      --arg description "$description" --argjson hasWhen "$when_has" --arg when "$when_to_use" \
      --arg invocation "$invocation" --arg path "skills/$name" \
      '{name: $name, version: $version, agents: ($agents | split(",")), description: $description,
        whenToUse: (if $hasWhen == 1 then $when else null end), invocation: $invocation, path: $path}')
    skills="$skills$entry
"
  done <"$folder/skills.tsv"
fi

rules=
if [ -f "$folder/rules.tsv" ]; then
  while IFS=$tab read -r name agents || [ -n "$name" ]; do
    rel="rules/$name.md"
    [ -f "$folder/$rel" ] || die "$rel:1: rules.tsv lists $name but the file is missing"
    title=$(awk '/^## / { sub(/^## /, ""); print; exit }' "$folder/$rel")
    [ -n "$title" ] || die "$rel:1: no ## title"
    entry=$(jq -cn --arg name "$name" --arg title "$title" --arg agents "$agents" --arg path "$rel" \
      '{name: $name, title: $title, agents: ($agents | split(",")), path: $path}')
    rules="$rules$entry
"
  done <"$folder/rules.tsv"
fi

agent_entries=
for file in "$folder"/agents/*.md; do
  [ -f "$file" ] || continue
  name=$(basename "$file" .md)
  rel="agents/$name.md"
  fm_get "$rel" description 1
  description=$fm_val
  fm_get "$rel" model 0
  model_has=$fm_has
  model=$fm_val
  entry=$(jq -cn --arg name "$name" --arg description "$description" --argjson hasModel "$model_has" \
    --arg model "$model" --arg path "$rel" \
    '{name: $name, description: $description, model: (if $hasModel == 1 then $model else null end), path: $path}')
  agent_entries="$agent_entries$entry
"
done

scratch=$(mktemp "${TMPDIR:-/tmp}/catalog.XXXXXX")
trap 'rm -f "$scratch"' EXIT
jq -n \
  --argjson skills "$(printf '%s' "$skills" | jq -s .)" \
  --argjson rules "$(printf '%s' "$rules" | jq -s .)" \
  --argjson agents "$(printf '%s' "$agent_entries" | jq -s .)" \
  '{schemaVersion: 1, skills: $skills, rules: $rules, agents: $agents}' >"$scratch"

if [ -f "$target" ] && cmp -s "$scratch" "$target"; then
  [ "$check" = 1 ] || echo "ok      $target"
  exit 0
fi
if [ "$check" = 1 ]; then
  die "$target is out of date; run scripts/catalog.sh $folder"
fi
cp "$scratch" "$target"
echo "wrote   $target"
