#!/bin/sh
set -eu

LC_ALL=C
export LC_ALL

usage() {
  echo "usage: scripts/knowledge-lint.sh [--write]" >&2
  exit 2
}

write=0
if [ "$#" -gt 1 ]; then
  usage
fi
if [ "$#" -eq 1 ]; then
  [ "$1" = --write ] || usage
  write=1
fi

top=$(git rev-parse --show-toplevel 2>/dev/null) || {
  echo "knowledge-lint: not inside a git work tree" >&2
  exit 2
}
cd "$top"

tab=$(printf '\t')
index_path=docs/knowledge/index.md
roots_path=docs/knowledge/source-roots.txt
work=$(mktemp -d "${TMPDIR:-/tmp}/knowledge-lint.XXXXXX")
trap 'rm -rf "$work"' EXIT
errors="$work/errors"
: >"$errors"

problem() {
  printf '%s\n' "$1" >>"$errors"
}

finish_if_problems() {
  count=$(wc -l <"$errors" | tr -d ' ')
  if [ "$count" -gt 0 ]; then
    sed 's/^/knowledge-lint: /' "$errors" >&2
    echo "knowledge-lint: $count problems" >&2
    exit 1
  fi
}

git -c core.quotePath=false ls-files --cached --others --exclude-standard >"$work/listed"
git -c core.quotePath=false ls-files --deleted >"$work/deleted"
sort -u "$work/listed" >"$work/listed.sorted"
sort -u "$work/deleted" >"$work/deleted.sorted"
comm -23 "$work/listed.sorted" "$work/deleted.sorted" >"$work/files"

grep '^docs/features/[^/]*\.md$' "$work/files" >"$work/node-files" || :
if [ ! -s "$work/node-files" ]; then
  problem "no nodes in docs/features/"
  finish_if_problems
fi
node_count=$(wc -l <"$work/node-files" | tr -d ' ')

while IFS= read -r file; do
  name=${file#docs/features/}
  name=${name%.md}
  printf '%s\n' "$name" | grep -Eq '^[a-z0-9][a-z0-9-]*$' ||
    problem "$file: node name must be lowercase kebab-case"
done <"$work/node-files"

: >"$work/records"
awk -v errors="$errors" -v records="$work/records" '
function report(path, number, message) {
  if (number > 0) {
    print path ":" number ": " message >> errors
  } else {
    print path ": " message >> errors
  }
}
function trim(text) {
  sub(/^[ \t]+/, "", text)
  sub(/[ \t]+$/, "", text)
  return text
}
BEGIN {
  split("code skills api related decisions", keys, " ")
  for (i in keys) {
    allowed[keys[i]] = 1
  }
}
{
  path = $0
  name = path
  sub(/^.*\//, "", name)
  sub(/\.md$/, "", name)
  state = 0
  titled = 0
  current = ""
  number = 0
  while ((getline line < path) > 0) {
    number++
    sub(/\r$/, "", line)
    if (number == 1) {
      if (line == "---") {
        state = 1
      } else {
        report(path, 1, "no frontmatter")
        state = -1
      }
      continue
    }
    if (state == 1) {
      if (line == "---") {
        state = 2
        continue
      }
      if (line ~ /^[ \t]*$/) {
        continue
      }
      if (line ~ /^[ \t]+-[ \t]+/) {
        if (current == "") {
          report(path, number, "not a key or a list item")
          continue
        }
        if (current == "?") {
          continue
        }
        value = line
        sub(/^[ \t]+-[ \t]+/, "", value)
        value = trim(value)
        if (value ~ /^".*"$/) {
          value = substr(value, 2, length(value) - 2)
        }
        if (value != "") {
          print name "\t" current "\t" value "\t" number >> records
        }
        continue
      }
      if (line ~ /^[A-Za-z][A-Za-z0-9_-]*:/) {
        key = line
        sub(/:.*$/, "", key)
        rest = line
        sub(/^[^:]*:/, "", rest)
        rest = trim(rest)
        if (!(key in allowed)) {
          report(path, number, "unknown key " key)
          current = "?"
        } else if (rest == "[]") {
          current = ""
        } else if (rest == "") {
          current = key
        } else {
          report(path, number, key " must be a list: write " key ": [] or one - item per line")
          current = "?"
        }
        continue
      }
      report(path, number, "not a key or a list item")
      continue
    }
    if (state == 2 && !titled && line ~ /^# /) {
      heading = trim(substr(line, 3))
      if (heading != "") {
        print name "\ttitle\t" heading "\t" number >> records
        titled = 1
      }
    }
  }
  close(path)
  if (state == 1) {
    report(path, 1, "frontmatter is not closed")
  }
  if (state == 2 && !titled) {
    report(path, 0, "no # title")
  }
}
' "$work/node-files"

: >"$work/globs.tsv"
awk -v errors="$errors" -v globs="$work/globs.tsv" '
BEGIN { FS = "\t" }
$2 != "code" { next }
{
  node = $1
  glob = $3
  number = $4
  path = "docs/features/" node ".md"
  if (index(glob, "./") == 1 || substr(glob, 1, 1) == "/") {
    print path ":" number ": " glob " must be relative to the repo root" >> errors
    next
  }
  if (index(glob, "[") || index(glob, "]") || index(glob, "|") || index(glob, "`")) {
    print path ":" number ": " glob " uses an unsupported character" >> errors
    next
  }
  source = glob
  if (substr(source, length(source)) == "/") {
    source = source "**"
  }
  size = length(source)
  depth = 0
  broken = 0
  ere = "^"
  i = 1
  while (i <= size) {
    c = substr(source, i, 1)
    if (c == "*") {
      if (substr(source, i, 3) == "**/") {
        ere = ere "(.*/)?"
        i += 3
      } else if (substr(source, i, 2) == "**") {
        ere = ere ".*"
        i += 2
      } else {
        ere = ere "[^/]*"
        i++
      }
    } else if (c == "?") {
      ere = ere "[^/]"
      i++
    } else if (c == "{") {
      if (depth > 0) {
        broken = 1
      }
      depth++
      ere = ere "("
      i++
    } else if (c == "}") {
      if (depth == 0) {
        broken = 1
      }
      depth = 0
      ere = ere ")"
      i++
    } else if (c == "," && depth > 0) {
      ere = ere "|"
      i++
    } else if (index(".+()^$\\", c) > 0) {
      ere = ere "\\" c
      i++
    } else {
      ere = ere c
      i++
    }
  }
  if (depth != 0 || broken) {
    print path ":" number ": " glob " has an unbalanced or nested brace" >> errors
    next
  }
  print node "\t" number "\t" glob "\t" ere "$" >> globs
}
' "$work/records"
finish_if_problems

distinct_globs=$(cut -f3 "$work/globs.tsv" | sort -u | wc -l | tr -d ' ')

{
  printf '# Knowledge index\n\n'
  printf 'Generated by `scripts/knowledge-lint.sh --write` from the nodes in `docs/features/`. '
  printf 'Edit the nodes, never this file. '
  printf 'CI runs `scripts/knowledge-lint.sh`, which fails on a code glob that matches no file, '
  printf 'a dead link, or a source area no node covers.\n\n'
  pointers=
  if [ -f docs/knowledge/GLOSSARY.md ]; then
    pointers='Glossary: [GLOSSARY.md](GLOSSARY.md).'
  fi
  if [ -d docs/adr ]; then
    pointers="${pointers:+$pointers }Decisions: [docs/adr/](../adr/)."
  fi
  if [ -n "$pointers" ]; then
    printf '%s\n\n' "$pointers"
  fi
  printf '## Paths\n\n| Path | Nodes |\n| --- | --- |\n'
  awk -F '\t' '{ print $3 "\t" $1 }' "$work/globs.tsv" | sort -u | awk -F '\t' '
    function flush() {
      if (current != "") {
        print "| `" current "` | " list " |"
      }
    }
    $1 != current {
      flush()
      current = $1
      list = ""
    }
    {
      link = "[" $2 "](../features/" $2 ".md)"
      list = (list == "" ? link : list ", " link)
    }
    END { flush() }
  '
  printf '\n## Nodes\n\n| Node | Title |\n| --- | --- |\n'
  awk -F '\t' '$2 == "title" { print $1 "\t" $3 }' "$work/records" | sort -t "$tab" -k1,1 | awk -F '\t' '
    {
      title = $2
      gsub(/\|/, "\\|", title)
      print "| [" $1 "](../features/" $1 ".md) | " title " |"
    }
  '
} >"$work/index.md"

if ! cmp -s "$work/index.md" "$index_path" 2>/dev/null; then
  if [ "$write" -eq 1 ]; then
    mkdir -p docs/knowledge
    cp "$work/index.md" "$index_path"
    echo "wrote $index_path"
  else
    problem "$index_path is out of date; run scripts/knowledge-lint.sh --write"
  fi
fi

: >"$work/matched"
while IFS=$tab read -r node number glob ere; do
  if ! grep -E -e "$ere" "$work/files" >>"$work/matched"; then
    problem "docs/features/$node.md:$number: $glob matches no file"
  fi
done <"$work/globs.tsv"

while IFS=$tab read -r node key value number; do
  case "$key" in
    related)
      target=${value%.md}
      grep -qxF "docs/features/$target.md" "$work/node-files" ||
        problem "docs/features/$node.md:$number: related node $value does not exist"
      ;;
    decisions)
      if [ ! -f "$value" ] && [ ! -f "docs/features/$value" ] && [ ! -f "docs/adr/$value.md" ]; then
        problem "docs/features/$node.md:$number: decision $value does not exist"
      fi
      ;;
  esac
done <"$work/records"

while IFS= read -r file; do
  grep -Eiq 'as of [0-9a-f]{7,40}, [0-9]{4}-[0-9]{2}-[0-9]{2}' "$file" ||
    problem "$file: no dated claim (as of <short sha>, <date>)"
done <"$work/node-files"

{
  grep -E '^docs/(features|knowledge|adr)/.*\.md$' "$work/files" || :
  if [ -f "$index_path" ]; then
    echo "$index_path"
  fi
} | sort -u >"$work/markdown-files"
: >"$work/links.tsv"
awk -v links="$work/links.tsv" '
{
  path = $0
  folder = path
  if (!sub(/\/[^\/]*$/, "", folder)) {
    folder = "."
  }
  fenced = 0
  number = 0
  while ((getline line < path) > 0) {
    number++
    sub(/\r$/, "", line)
    if (line ~ /^[ \t]*(```|~~~)/) {
      fenced = !fenced
      continue
    }
    if (fenced) {
      continue
    }
    gsub(/`[^`]*`/, "", line)
    rest = line
    while ((at = index(rest, "](")) > 0) {
      rest = substr(rest, at + 2)
      end = index(rest, ")")
      if (end == 0) {
        break
      }
      target = substr(rest, 1, end - 1)
      rest = substr(rest, end + 1)
      sub(/^[ \t]+/, "", target)
      if (substr(target, 1, 1) == "<") {
        sub(/^</, "", target)
        sub(/>.*$/, "", target)
      } else {
        sub(/[ \t].*$/, "", target)
      }
      sub(/#.*$/, "", target)
      sub(/\?.*$/, "", target)
      if (target == "" || target ~ /^[A-Za-z][A-Za-z0-9+.-]*:/) {
        continue
      }
      resolved = target
      gsub(/%20/, " ", resolved)
      if (substr(resolved, 1, 1) == "/") {
        resolved = substr(resolved, 2)
      } else {
        resolved = folder "/" resolved
      }
      print path "\t" number "\t" target "\t" resolved >> links
    }
  }
  close(path)
}
' "$work/markdown-files"
while IFS=$tab read -r file number target resolved; do
  [ -e "$resolved" ] || problem "$file:$number: dead link $target"
done <"$work/links.tsv"

: >"$work/roots"
: >"$work/excluded"
declared=0
if [ -f "$roots_path" ]; then
  line_number=0
  while IFS= read -r line || [ -n "$line" ]; do
    line_number=$((line_number + 1))
    entry=$(printf '%s' "$line" | tr -d '\r' | sed 's/^[[:space:]]*//; s/[[:space:]]*$//; s|/*$||')
    case "$entry" in
      "") ;;
      !*) printf '%s\n' "${entry#!}" >>"$work/excluded" ;;
      *)
        declared=1
        if awk -v root="$entry/" 'index($0, root) == 1 { found = 1; exit } END { exit !found }' "$work/files"; then
          printf '%s\n' "$entry" >>"$work/roots"
        else
          problem "$roots_path:$line_number: $entry has no files"
        fi
        ;;
    esac
  done <"$roots_path"
fi
if [ "$declared" -eq 0 ] && awk 'index($0, "src/") == 1 { found = 1; exit } END { exit !found }' "$work/files"; then
  echo src >"$work/roots"
fi

while IFS= read -r root; do
  awk -v root="$root" '
    index($0, root "/") == 1 {
      rest = substr($0, length(root) + 2)
      slash = index(rest, "/")
      if (slash > 0) {
        print root "/" substr(rest, 1, slash - 1)
      }
    }
  ' "$work/files"
done <"$work/roots" | sort -u >"$work/areas"

while IFS= read -r area; do
  if grep -qxF "$area" "$work/excluded"; then
    continue
  fi
  if ! awk -v prefix="$area/" 'index($0, prefix) == 1 { found = 1; exit } END { exit !found }' "$work/matched"; then
    problem "$area: no node covers this source area"
  fi
done <"$work/areas"

finish_if_problems
echo "knowledge-lint: ok ($node_count nodes, $distinct_globs distinct globs)"
