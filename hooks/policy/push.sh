#!/bin/sh
set -eu
set -f

protected_pattern='main|staging|release-.*|release-hotfix.*'

protected_list=$(printf '%s' "$protected_pattern" | sed 's/|/, /g; s/[.][*]/*/g')
tilde='~'
tab=$(printf '\t')
marker=$(printf '\001')
newline='
'
word_start='(^|[^[:alnum:]_-])'
word_end='([^[:alnum:]_-]|$)'

deny() {
  printf '%s\n' "$1"
  exit 10
}

deny_protected() {
  deny "push denied: $1 is protected ($protected_list). Push your feature branch and open a PR."
}

deny_rewrite() {
  deny "push denied: $1 rewrites or removes remote branches. Push without it."
}

deny_hidden_push() {
  deny "push denied: a git push inside $1 can't be checked. Run git push directly."
}

deny_hidden_gh() {
  deny "push denied: a gh call inside $1 can't be checked. Run gh directly."
}

deny_api_branches() {
  deny "gh api denied: this call moves, merges or protects branches; agents never do that through the API."
}

is_protected() {
  printf '%s\n' "$1" | grep -Eqx "$protected_pattern"
}

resolve() {
  case $2 in
    /*) resolved=$2 ;;
    "$tilde") resolved=${HOME:-/} ;;
    "$tilde"/*) resolved=${HOME:-}/${2#??} ;;
    *) resolved=$1/$2 ;;
  esac
}

matches() {
  printf '%s' "$flat" | grep -Eq "$1"
}

check_generic() {
  if matches "${word_start}git${word_end}" && matches "${word_start}push${word_end}"; then
    deny_hidden_push "$1"
  fi
  if matches "${word_start}gh${word_end}" && matches "${word_start}(merge|api|auth|alias)${word_end}"; then
    deny_hidden_gh "$1"
  fi
}

cut_comment() {
  rest=$1
  kept=
  quote=
  previous=' '
  while [ -n "$rest" ]; do
    after=${rest#?}
    char=${rest%"$after"}
    rest=$after
    if [ -n "$quote" ]; then
      if [ "$char" = "$quote" ]; then
        quote=
      fi
    else
      case $char in
        '"' | "'") quote=$char ;;
        '#')
          case $previous in
            ' ' | "$tab") break ;;
          esac
          ;;
      esac
    fi
    kept=$kept$char
    previous=$char
  done
}

note_heredoc() {
  case $1 in
    *'<<'*) ;;
    *) return 0 ;;
  esac
  before=${1%%<<*}
  introduced=${1#*<<}
  case $introduced in
    '<'*) return 0 ;;
  esac
  introduced=${introduced#-}
  introduced=${introduced#"${introduced%%[![:space:]]*}"}
  case $introduced in
    \'*) delimiter=${introduced#\'}; delimiter=${delimiter%%\'*} ;;
    \"*) delimiter=${introduced#\"}; delimiter=${delimiter%%\"*} ;;
    *) return 0 ;;
  esac
  owner=
  for word in $before; do
    owner=${word##*[!A-Za-z]}
  done
  if [ "$owner" != cat ]; then
    return 0
  fi
  after_delimiter=${introduced#?"$delimiter"?}
  case $after_delimiter in
    *'|'*) return 0 ;;
  esac
  heredoc_end=$delimiter
}

prepare_code() {
  heredoc_end=
  while IFS= read -r line; do
    if [ -n "$heredoc_end" ]; then
      trimmed=${line#"${line%%[![:space:]]*}"}
      if [ "$trimmed" = "$heredoc_end" ]; then
        heredoc_end=
      fi
      continue
    fi
    cut_comment "$line"
    printf '%s\n' "$kept"
    note_heredoc "$kept"
  done
}

check_current_branch() {
  status=0
  if [ -n "$gitdir" ]; then
    resolve "$dir" "$gitdir"
    branch=$(git --git-dir="$resolved" symbolic-ref --short -q HEAD 2>/dev/null) || status=$?
  else
    branch=$(git -C "$dir" symbolic-ref --short -q HEAD 2>/dev/null) || status=$?
  fi
  case $status in
    0)
      if is_protected "$branch"; then
        deny_protected "$branch"
      fi
      ;;
    1) deny "push denied: HEAD is detached, so the target branch is unknown. Check out your feature branch and push it." ;;
  esac
}

check_refspec() {
  case $1 in
    +* | :*) deny_rewrite "$1" ;;
    HEAD | @)
      head_pushed=true
      return 0
      ;;
    *"$marker"* | *'`'*)
      head_pushed=true
      return 0
      ;;
    *'$'*) deny_hidden_push "a shell variable" ;;
  esac
  case $1 in
    *:*) destination=${1#*:} ;;
    *) destination=$1 ;;
  esac
  destination=${destination#refs/heads/}
  case $destination in
    *"$marker"* | *'`'*)
      head_pushed=true
      return 0
      ;;
    *'$'*) deny_hidden_push "a shell variable" ;;
    *'*'*) deny_protected "$destination" ;;
  esac
  if is_protected "$destination"; then
    deny_protected "$destination"
  fi
}

inspect_push() {
  positionals=0
  head_pushed=false
  tags_pushed=false
  skip_next=false
  for arg in "$@"; do
    if [ "$skip_next" = true ]; then
      skip_next=false
      continue
    fi
    case $arg in
      --force | --force-with-lease* | --force-if-includes | --delete | --mirror | --all | --prune) deny_rewrite "$arg" ;;
      --tags) tags_pushed=true ;;
      -o | --push-option | --repo | --receive-pack | --exec) skip_next=true ;;
      --*) ;;
      -*[fd]*) deny_rewrite "$arg" ;;
      -*) ;;
      *)
        positionals=$((positionals + 1))
        if [ "$positionals" -gt 1 ]; then
          check_refspec "$arg"
        fi
        ;;
    esac
  done
  if [ "$head_pushed" = true ]; then
    check_current_branch
  elif [ "$positionals" -le 1 ] && [ "$tags_pushed" = false ]; then
    check_current_branch
  fi
}

inspect_git() {
  dir=$workdir
  gitdir=
  while [ $# -gt 0 ]; do
    case $1 in
      -C)
        [ $# -ge 2 ] || return 0
        resolve "$dir" "$2"
        dir=$resolved
        shift 2
        ;;
      --git-dir=*)
        gitdir=${1#*=}
        shift
        ;;
      --git-dir)
        [ $# -ge 2 ] || return 0
        gitdir=$2
        shift 2
        ;;
      -c)
        [ $# -ge 2 ] || return 0
        case ${2%%=*} in
          remote.*.push | push.* | alias.*)
            check_generic "git -c"
            return 0
            ;;
        esac
        shift 2
        ;;
      --work-tree | --namespace | --super-prefix | --config-env | --exec-path)
        [ $# -ge 2 ] || return 0
        shift 2
        ;;
      -*) shift ;;
      push)
        shift
        inspect_push "$@"
        return 0
        ;;
      *) return 0 ;;
    esac
  done
}

inspect_gh_api() {
  graphql=false
  explicit_get=false
  explicit_write=false
  fields=false
  hits_protection=false
  hits_refs=false
  expect_method=false
  skip_next=false
  query_text=$*
  for arg in "$@"; do
    if [ "$expect_method" = true ]; then
      expect_method=false
      note_method "$arg"
      continue
    fi
    if [ "$skip_next" = true ]; then
      skip_next=false
      continue
    fi
    case $arg in
      -X | --method) expect_method=true ;;
      --method=*) note_method "${arg#--method=}" ;;
      -X?*) note_method "${arg#-X}" ;;
      -f | -F | --field | --raw-field | --input)
        fields=true
        skip_next=true
        ;;
      -f?* | -F?* | --field=* | --raw-field=* | --input=*) fields=true ;;
      -H | --header | -q | --jq | -t | --template | --hostname | --cache | -p | --preview) skip_next=true ;;
      -*) ;;
      graphql) graphql=true ;;
      *rulesets* | *branches/*/protection*) hits_protection=true ;;
      *git/refs* | *contents/* | */merges* | *pulls/*/merge*) hits_refs=true ;;
    esac
  done
  if [ "$graphql" = true ]; then
    case $query_text in
      *mergePullRequest* | *enablePullRequestAutoMerge* | *BranchProtectionRule* | *Ruleset* | *updateRef* | *deleteRef* | *createRef*) deny_api_branches ;;
    esac
  fi
  writes=false
  if [ "$explicit_write" = true ]; then
    writes=true
  elif [ "$fields" = true ] && [ "$explicit_get" = false ]; then
    writes=true
  fi
  if [ "$writes" = true ]; then
    if [ "$hits_protection" = true ]; then
      deny "gh api denied: rulesets and branch protection are not edited by agents."
    fi
    if [ "$hits_refs" = true ]; then
      deny_api_branches
    fi
  fi
}

note_method() {
  case $1 in
    GET | get) explicit_get=true ;;
    *) explicit_write=true ;;
  esac
}

inspect_gh() {
  group=
  subcommand=
  skip_next=false
  for arg in "$@"; do
    if [ "$skip_next" = true ]; then
      skip_next=false
      continue
    fi
    case $arg in
      -R | --repo) skip_next=true ;;
      -*) ;;
      *)
        if [ -z "$group" ]; then
          group=$arg
        elif [ -z "$subcommand" ]; then
          subcommand=$arg
        fi
        ;;
    esac
  done
  case $group in
    pr)
      if [ "$subcommand" = merge ]; then
        deny "gh pr merge denied: a person merges after review."
      fi
      ;;
    alias)
      if [ "$subcommand" = set ] || [ "$subcommand" = import ]; then
        deny "gh alias denied: an alias can rename gh pr merge."
      fi
      ;;
    auth)
      if [ "$subcommand" = token ]; then
        deny "gh auth token denied: agents never read the token."
      fi
      if [ "$subcommand" = status ]; then
        for arg in "$@"; do
          case $arg in
            --show-token) deny "gh auth token denied: agents never read the token." ;;
            --*) ;;
            -*t*) deny "gh auth token denied: agents never read the token." ;;
          esac
        done
      fi
      ;;
    api) inspect_gh_api "$@" ;;
  esac
}

inspect_segment() {
  hidden_prefix=
  while [ $# -gt 0 ]; do
    case $1 in
      GIT_DIR=* | GIT_WORK_TREE=*)
        hidden_prefix=${1%%=*}
        shift
        ;;
      [A-Za-z_]*=*) shift ;;
      env)
        case ${2-} in
          -*)
            hidden_prefix='env'
            break
            ;;
        esac
        shift
        ;;
      command | exec | time | nohup | '{' | '!' | then | do | else) shift ;;
      *) break ;;
    esac
  done
  [ $# -gt 0 ] || return 0
  if [ -z "$hidden_prefix" ]; then
    case $1 in
      cd)
        shift
        if [ $# -gt 0 ]; then
          resolve "$workdir" "$1"
          workdir=$resolved
        fi
        return 0
        ;;
      git | */git)
        shift
        inspect_git "$@"
        return 0
        ;;
      gh | */gh)
        shift
        inspect_gh "$@"
        return 0
        ;;
    esac
    check_generic "$1"
  else
    check_generic "$hidden_prefix"
  fi
}

event=$(cat)
tool=$(printf '%s' "$event" | jq -r '.tool')
if [ "$tool" != shell ]; then
  exit 0
fi
command=$(printf '%s' "$event" | jq -r '.command | gsub("\\\\\n"; " ")')
cwd=$(printf '%s' "$event" | jq -r '.cwd')

workdir=$cwd
code=$(printf '%s\n' "$command" | prepare_code)
segments=$(printf '%s\n' "$code" | sed "s/[\$](/$marker/g" | tr ';&|()' '\n\n\n\n\n')

remaining=$segments$newline
while [ -n "$remaining" ]; do
  segment=${remaining%%"$newline"*}
  remaining=${remaining#*"$newline"}
  segment=$(printf '%s' "$segment" | tr -d "\"'\\\\")
  set -- $segment
  flat=$*
  inspect_segment "$@"
done

exit 0
