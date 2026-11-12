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
codex_home="$HOME/.codex"
codex_config="$codex_home/config.toml"
codex_hooks="$codex_home/hooks.json"
codex_hooks_record="$state/codex-hooks-layer.json"
codex_displaced="$state/codex-config-displaced.toml"
codex_upserts="$state/codex-config-upserts.tsv"
codex_fragment_file="$profile/codex/config.toml"
codex_block_begin='# BEGIN countersign-skills: install.sh manages this block'
codex_block_end='# END countersign-skills'
codex_block_keys='model_auto_compact_token_limit|approval_policy|sandbox_mode'

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

strip_codex_block() {
  displaced_file=${2:-}
  [ -z "$displaced_file" ] || : >"$displaced_file"
  awk -v begin="$codex_block_begin" -v end="$codex_block_end" -v keys="^($codex_block_keys)[ \\t]*=" -v loose="^[ \\t]*($codex_block_keys)[ \\t]*=" -v displaced="$displaced_file" -v check="${3:-}" -v file="$1" "$codex_toml_awk"'
    function emit(text) {
      if (check == "") print text
    }
    function route(text) {
      if (diverting) print text > displaced
      else emit(text)
    }
    function track(text) {
      depth = 0
      mls = ""
      advance(value_of(text))
      if (depth < 0) depth = 0
    }
    BEGIN {
      while ((getline row < file) > 0) {
        if (row == end) closed = 1
      }
    }
    tables { emit($0); next }
    depth > 0 || mls != "" {
      advance($0)
      route($0)
      if (depth <= 0 && mls == "") {
        depth = 0
        diverting = 0
      }
      next
    }
    /^[ \t]*\[[^[:space:]]/ { tables = 1; emit($0); next }
    $0 == begin { inside = 1; next }
    $0 == end { inside = 0; next }
    inside && (closed || $0 ~ keys) { next }
    $0 ~ keys && displaced != "" {
      print > displaced
      track($0)
      diverting = depth > 0 || mls != ""
      next
    }
    $0 ~ loose && !inside { stray = 1 }
    {
      if (index($0, "=") > 0) track($0)
      emit($0)
    }
    END { if (check != "" && stray) exit 3 }
  ' "$1"
}

split_codex_displaced() {
  awk -v keys="^($codex_block_keys)[ \\t]*=" -v held="$2" -v restored="$3" -v known_file="${4:-}" "$codex_toml_awk"'
    function name_of(text) {
      sub(/[ \t]*=.*/, "", text)
      return text
    }
    BEGIN {
      printf "" > held
      printf "" > restored
      if (known_file != "") {
        while ((getline row < known_file) > 0) {
          if (row ~ keys) known[name_of(row)] = 1
        }
        close(known_file)
      }
    }
    depth > 0 || mls != "" {
      advance($0)
      if (sink != "") print > sink
      if (depth <= 0 && mls == "") depth = 0
      next
    }
    {
      sink = restored
      if ($0 ~ keys) sink = held
      if ($0 ~ keys && (name_of($0) in known)) sink = ""
      depth = 0
      advance(value_of($0))
      if (depth < 0) depth = 0
      if (sink != "") print > sink
    }
  ' "$1"
}

codex_toml_awk='
function bare(text) {
  return text ~ /^[A-Za-z0-9_-]+$/
}
function trim(text) {
  sub(/^[ \t\r]+/, "", text)
  sub(/[ \t\r]+$/, "", text)
  return text
}
function take(   position, field) {
  position = index(rest, "\t")
  if (position == 0) {
    field = rest
    rest = ""
  } else {
    field = substr(rest, 1, position - 1)
    rest = substr(rest, position + 1)
  }
  return field
}
function skip_quoted(text, from, length_of_text, quote,   at, c) {
  at = from
  while (at <= length_of_text) {
    c = substr(text, at, 1)
    if (quote == "\"" && c == "\\") {
      at += 2
      continue
    }
    if (c == quote) return at + 1
    at++
  }
  return 0
}
function advance(text,   at, size, c, three) {
  size = length(text)
  at = 1
  while (at <= size) {
    c = substr(text, at, 1)
    three = substr(text, at, 3)
    if (mls != "") {
      if (three == mls) {
        mls = ""
        at += 3
      } else if (mls == "\"\"\"" && c == "\\") {
        at += 2
      } else {
        at++
      }
      continue
    }
    if (c == "#") return
    if (three == "\"\"\"" || three == "\047\047\047") {
      mls = three
      at += 3
      continue
    }
    if (c == "\"" || c == "\047") {
      at = skip_quoted(text, at + 1, size, c)
      if (at == 0) return
      continue
    }
    if (c == "[" || c == "{") depth++
    else if (c == "]" || c == "}") depth--
    at++
  }
}
function eq_position(text,   at, size, c) {
  size = length(text)
  at = 1
  while (at <= size) {
    c = substr(text, at, 1)
    if (c == "\"" || c == "\047") {
      at = skip_quoted(text, at + 1, size, c)
      if (at == 0) return 0
      continue
    }
    if (c == "=") return at
    if (c == "#") return 0
    at++
  }
  return 0
}
function value_of(line,   text) {
  text = trim(line)
  return substr(text, eq_position(text) + 1)
}
function escape(text,   out, at, c) {
  out = ""
  for (at = 1; at <= length(text); at++) {
    c = substr(text, at, 1)
    if (c == "\\") out = out "\\\\"
    else if (c == "\n") out = out "\\n"
    else out = out c
  }
  return out
}
function unescape(text,   out, at, c) {
  out = ""
  for (at = 1; at <= length(text); at++) {
    c = substr(text, at, 1)
    if (c == "\\") {
      at++
      c = substr(text, at, 1)
      out = out (c == "n" ? "\n" : c)
    } else {
      out = out c
    }
  }
  return out
}
function decode_basic(text,   out, at, c) {
  out = ""
  for (at = 1; at <= length(text); at++) {
    c = substr(text, at, 1)
    if (c == "\\" && at < length(text)) {
      at++
      c = substr(text, at, 1)
    }
    out = out c
  }
  return out
}
function quote_segment(text,   out, at, c) {
  out = "\""
  for (at = 1; at <= length(text); at++) {
    c = substr(text, at, 1)
    if (c == "\\" || c == "\"") out = out "\\"
    out = out c
  }
  return out "\""
}
function skip_string(text, at, size,   three, closing) {
  three = substr(text, at, 3)
  if (three == "\"\"\"" || three == "\047\047\047") {
    closing = index(substr(text, at + 3), three)
    if (closing == 0) return 0
    return at + closing + 5
  }
  return skip_quoted(text, at + 1, size, substr(text, at, 1))
}
function is_scalar(body) {
  if (body ~ /^(true|false)$/) return 1
  if (body ~ /^[-+]?(inf|nan)$/) return 1
  if (body ~ /^0x[0-9A-Fa-f]+(_[0-9A-Fa-f]+)*$/ || body ~ /^0o[0-7]+(_[0-7]+)*$/ || body ~ /^0b[01]+(_[01]+)*$/) return 1
  if (body ~ /^[-+]?(0|[1-9][0-9]*(_[0-9]+)*)(\.[0-9]+(_[0-9]+)*)?([eE][-+]?[0-9]+(_[0-9]+)*)?$/) return 1
  if (body ~ /^[0-9][0-9][0-9][0-9]-[0-9][0-9]-[0-9][0-9]([Tt ][0-9][0-9]:[0-9][0-9]:[0-9][0-9](\.[0-9]+)?([Zz]|[-+][0-9][0-9]:[0-9][0-9])?)?$/) return 1
  if (body ~ /^[0-9][0-9]:[0-9][0-9]:[0-9][0-9](\.[0-9]+)?$/) return 1
  return 0
}
function value_problem(value,   at, size, c, body, stack, top) {
  size = length(value)
  c = substr(value, 1, 1)
  if (c == "\"" || c == "\047") {
    at = skip_string(value, 1, size)
    if (at == 0) return "must be complete on one line"
  } else if (c == "[" || c == "{") {
    stack = ""
    at = 1
    while (at <= size) {
      c = substr(value, at, 1)
      if (c == "\"" || c == "\047") {
        at = skip_string(value, at, size)
        if (at == 0) return "must be complete on one line"
        continue
      }
      if (c == "#") return "must be complete on one line"
      if (c == "[" || c == "{") {
        stack = stack c
      } else if (c == "]" || c == "}") {
        top = substr(stack, length(stack), 1)
        if (top == "" || (c == "]") != (top == "[")) return "has mismatched brackets"
        stack = substr(stack, 1, length(stack) - 1)
      }
      at++
      if (stack == "") break
    }
    if (stack != "") return "must be complete on one line"
  } else {
    body = value
    sub(/#.*/, "", body)
    if (is_scalar(trim(body))) return ""
    return "is not a string, number, boolean, date, array or inline table"
  }
  if (substr(value, at) !~ /^[ \t]*(#.*)?$/) return "has text after the value"
  return ""
}
function key_of(line,   text, position, key) {
  text = trim(line)
  position = eq_position(text)
  if (position == 0) return ""
  key = trim(substr(text, 1, position - 1))
  if (key ~ /^"[^"]*"$/ || key ~ /^\047[^\047]*\047$/) key = substr(key, 2, length(key) - 2)
  if (!bare(key)) return ""
  return key
}
function header_name(line,   text, size, at, c, stop, segment, inner, name) {
  text = trim(line)
  size = length(text)
  at = 2
  name = ""
  while (1) {
    while (substr(text, at, 1) ~ /[ \t]/) at++
    c = substr(text, at, 1)
    if (c == "\"" || c == "\047") {
      stop = skip_quoted(text, at + 1, size, c)
      if (stop == 0) return ""
      segment = substr(text, at, stop - at)
      inner = substr(segment, 2, length(segment) - 2)
      if (c == "\"") inner = decode_basic(inner)
      segment = bare(inner) ? inner : quote_segment(inner)
      at = stop
    } else {
      if (!match(substr(text, at), /^[A-Za-z0-9_-]+/)) return ""
      segment = substr(text, at, RLENGTH)
      at += RLENGTH
    }
    name = name (name == "" ? "" : ".") segment
    while (substr(text, at, 1) ~ /[ \t]/) at++
    c = substr(text, at, 1)
    at++
    if (c == "]") break
    if (c != ".") return ""
  }
  if (substr(text, at) !~ /^[ \t]*(#.*)?$/) return ""
  return name
}
'

parse_codex_fragment() {
  awk -v file="$1" "$codex_toml_awk"'
    function fail(reason) {
      print "install.sh: " file " line " FNR ": " reason > "/dev/stderr"
      exit 1
    }
    {
      text = trim($0)
      if (text == "" || substr(text, 1, 1) == "#") next
      if (substr(text, 1, 1) == "[") {
        if (substr(text, 2, 1) == "[") fail("arrays of tables are not supported")
        name = header_name(text)
        if (name == "") fail("not a valid table header")
        if (name in tables) fail("the table [" name "] appears twice")
        tables[name] = 1
        table = name
        next
      }
      key = key_of(text)
      if (key == "") fail("expected a comment, a [table] header or a key = value with a bare key")
      if ((table SUBSEP key) in keys) fail("the key " key " appears twice")
      keys[table SUBSEP key] = 1
      value = trim(value_of(text))
      problem = value_problem(value)
      if (problem != "") fail("the value of " key " " problem)
      print table "\t" key "\t" text
    }
  ' "$1"
}

reconcile_codex_tables() {
  awk -v fragment_file="$2" -v record_file="$3" -v record_out="$4" "$codex_toml_awk"'
    BEGIN {
      printf "" > record_out
      while ((getline row < fragment_file) > 0) {
        rest = row
        table = take()
        key = take()
        if (table == "") continue
        want_count++
        want_table[want_count] = table
        want_key[want_count] = key
        want_line[want_count] = rest
        wanted[table SUBSEP key] = 1
        wanted_table[table] = 1
      }
      close(fragment_file)
      while ((getline row < record_file) > 0) {
        rest = row
        table = take()
        key = take()
        mode = take()
        id = table SUBSEP key
        prev_count++
        prev_table[prev_count] = table
        prev_key[prev_count] = key
        prev_mode[id] = mode
        prev_original[id] = unescape(rest)
        if (mode != "kept") added_table[table] = 1
        if (mode == "added-spaced") spaced_table[table] = 1
      }
      close(record_file)
    }
    function span_text(start, stop,   out, n) {
      out = lines[start]
      for (n = start + 1; n <= stop; n++) out = out "\n" lines[n]
      return out
    }
    function replace_span(start, stop, text,   n) {
      lines[start] = text
      for (n = start + 1; n <= stop; n++) drop[n] = 1
    }
    function remove_span(start, stop,   n) {
      for (n = start; n <= stop; n++) drop[n] = 1
    }
    { lines[++count] = $0 }
    END {
      depth = 0
      mls = ""
      current = ""
      span_id = ""
      for (i = 1; i <= count; i++) {
        line = lines[i]
        if (depth == 0 && mls == "" && line ~ /^[ \t]*\[/) {
          current = header_name(line)
          if (current == "") current = trim(line)
          is_header[i] = 1
          if (!(current in header_at)) header_at[current] = i
          continue
        }
        if (depth == 0 && mls == "") {
          text = trim(line)
          if (text == "" || substr(text, 1, 1) == "#" || eq_position(text) == 0) continue
          found = key_of(line)
          span_id = ""
          if (found != "" && current != "" && !((current SUBSEP found) in key_at)) {
            span_id = current SUBSEP found
            key_at[span_id] = i
            key_end[span_id] = i
          }
          advance(value_of(line))
        } else {
          advance(line)
        }
        if (depth < 0) depth = 0
        if (depth == 0 && mls == "" && span_id != "") {
          key_end[span_id] = i
          span_id = ""
        }
      }
      for (p = 1; p <= prev_count; p++) {
        id = prev_table[p] SUBSEP prev_key[p]
        if ((id in wanted) || !(id in key_at)) continue
        if (prev_original[id] == "") remove_span(key_at[id], key_end[id])
        else replace_span(key_at[id], key_end[id], prev_original[id])
      }
      for (name in added_table) {
        if ((name in wanted_table) || !(name in header_at)) continue
        head = header_at[name]
        empty = 1
        for (j = head + 1; j <= count && !(j in is_header); j++) {
          if (!(j in drop) && lines[j] !~ /^[ \t\r]*$/) {
            empty = 0
            break
          }
        }
        if (!empty) continue
        drop[head] = 1
        if ((name in spaced_table) && head > 1 && lines[head - 1] ~ /^[ \t\r]*$/) drop[head - 1] = 1
      }
      for (w = 1; w <= want_count; w++) {
        id = want_table[w] SUBSEP want_key[w]
        if (!(want_table[w] in header_at)) continue
        present = (id in key_at) ? span_text(key_at[id], key_end[id]) : ""
        if (id in prev_mode) {
          row_mode[w] = prev_mode[id]
          row_original[w] = prev_original[id]
        } else {
          if (want_table[w] in spaced_table) row_mode[w] = "added-spaced"
          else if (want_table[w] in added_table) row_mode[w] = "added"
          else row_mode[w] = "kept"
          row_original[w] = present
        }
        if (id in key_at) {
          if (present != want_line[w]) replace_span(key_at[id], key_end[id], want_line[w])
        } else {
          after[header_at[want_table[w]]] = after[header_at[want_table[w]]] want_line[w] "\n"
        }
      }
      last = 0
      for (i = count; i >= 1; i--) {
        if (!(i in drop)) {
          last = i
          break
        }
      }
      separate = last > 0 && (lines[last] !~ /^[ \t\r]*$/ || (last in after))
      for (w = 1; w <= want_count; w++) {
        name = want_table[w]
        if (name in header_at) continue
        if (!(name in appended)) {
          appended_count++
          appended_order[appended_count] = name
          appended[name] = (appended_count == 1 && !separate) ? "added" : "added-spaced"
        }
        row_mode[w] = appended[name]
        row_original[w] = ""
        appended_body[name] = appended_body[name] want_line[w] "\n"
      }
      for (i = 1; i <= count; i++) {
        if (!(i in drop)) print lines[i]
        if (i in after) printf "%s", after[i]
      }
      for (a = 1; a <= appended_count; a++) {
        name = appended_order[a]
        if (appended[name] == "added-spaced") print ""
        print "[" name "]"
        printf "%s", appended_body[name]
      }
      for (w = 1; w <= want_count; w++) {
        print want_table[w] "\t" want_key[w] "\t" row_mode[w] "\t" escape(row_original[w]) > record_out
      }
      close(record_out)
    }
  ' "$1"
}

merge_codex_hooks='
  (.[0] | if type == "object" and ((.hooks // {}) | type) == "object" and ([(.hooks // {})[] | type] | all(. == "array")) then . else error("not a hooks file") end) as $current
  | .[1] as $layer | .[2] as $previous
  | ([$layer, $previous | (.hooks // {})[][] | .hooks[]? | .command] | unique) as $ours
  | def ours: any(.hooks[]?; .command | IN($ours[]));
  ([$layer, $previous | (.hooks // {}) | keys[]] | unique) as $events
  | reduce $events[] as $event ($current;
      ((.hooks // {})[$event] // []) as $have
      | ($have | map(select(ours))) as $mine
      | (($layer.hooks // {})[$event] // []) as $wanted
      | if $mine == $wanted then .
        else (($have | map(select(ours | not))) + $wanted) as $next
          | if $next == [] then del(.hooks[$event]) else .hooks[$event] = $next end
        end)
  | if (.hooks // null) == {} then del(.hooks) else . end
'
