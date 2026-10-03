tab=$(printf '\t')
stamp=$(date +%Y%m%d-%H%M%S)
config_home="${XDG_CONFIG_HOME:-$HOME/.config}/countersign"
state="$config_home/skills"
profile="$config_home/profile"
manifest="$state/manifest.tsv"
additions="$state/additions.tsv"
settings_record="$state/settings-layer.json"
sources_record="$state/sources.tsv"
originals="$state/originals"
backup="$state/backups/$stamp"
backups_kept=5
claude_home=${CLAUDE_CONFIG_DIR:-$HOME/.claude}

skills_dir() {
  case $1 in
    claude) echo "$claude_home/skills" ;;
    codex)
      if [ -d "$HOME/.codex" ]; then echo "$HOME/.agents/skills"; fi
      ;;
    antigravity)
      if [ -d "$HOME/.gemini/antigravity-cli" ]; then echo "$HOME/.gemini/antigravity-cli/skills"; fi
      ;;
  esac
}

sha256_of() {
  if command -v sha256sum >/dev/null 2>&1; then
    sha256sum "$1" | awk '{ print $1 }'
  else
    shasum -a 256 "$1" | awk '{ print $1 }'
  fi
}

back_up() {
  dest=$1
  agent=$2
  if [ -e "$dest" ] || [ -L "$dest" ]; then
    mkdir -p "$backup/$agent"
    mv "$dest" "$backup/$agent/"
    echo "moved   $dest to $backup/$agent/"
  fi
}

tracked() {
  [ -f "$manifest" ] || return 1
  awk -F "$tab" -v agent="$1" -v skill="$2" '$1 == agent && $2 == skill { found = 1 } END { exit !found }' "$manifest"
}

forget() {
  if [ -f "$manifest" ]; then
    remaining=$(mktemp "${TMPDIR:-/tmp}/countersign-skills.XXXXXX")
    awk -F "$tab" -v agent="$1" -v skill="$2" '!($1 == agent && $2 == skill)' "$manifest" >"$remaining"
    mv "$remaining" "$manifest"
  fi
  rm -rf "$state/base/$1/$2"
}

prune_backups() {
  [ -d "$state/backups" ] || return 0
  ls -1 "$state/backups" | sort -r | tail -n +$((backups_kept + 1)) | while IFS= read -r old; do
    rm -rf "${state:?}/backups/$old"
    echo "pruned  $state/backups/$old"
  done
}

instructions_file() {
  case $1 in
    codex)
      if [ -d "$HOME/.codex" ]; then echo "$HOME/.codex/AGENTS.md"; fi
      ;;
    antigravity)
      if [ -d "$HOME/.gemini/antigravity-cli" ]; then echo "$HOME/.gemini/GEMINI.md"; fi
      ;;
  esac
}

keep_original() {
  dest=$1
  marker=$2
  [ -f "$dest" ] || return 0
  [ -e "$originals/$(basename "$dest")" ] && return 0
  if [ -n "$marker" ] && grep -qE "$marker" "$dest"; then
    return 0
  fi
  mkdir -p "$originals"
  cp "$dest" "$originals/$(basename "$dest")"
  echo "kept    $dest as it was, in $originals"
}

unmerge_settings='
  def leaves:
    if type == "object" then (keys_unsorted[] as $k | (.[$k] | leaves) as $p | [$k] + $p) else [] end;
  def at($p): try getpath($p) catch null;
  .[0] as $current | .[1] as $layer | .[2] as $original
  | reduce ($layer | leaves) as $p ($current;
      ($layer | getpath($p)) as $merged
      | ($original | at($p)) as $before
      | at($p) as $now
      | if $now == null then .
        elif ($merged | type) == "array" and ($now | type) == "array" then
          ($now - ($merged - (if ($before | type) == "array" then $before else [] end))) as $rest
          | if $rest == [] then delpaths([$p]) else setpath($p; $rest) end
        elif $now == $merged then
          (if $before == null then delpaths([$p]) else setpath($p; $before) end)
        else . end)
  | reduce ([$layer | paths(type == "object")] | sort_by(length) | reverse | .[]) as $p (.;
      if at($p) == {} then delpaths([$p]) else . end)
'
