#!/bin/sh
set -eu

state=$1
plain_home=$3
root=$(cd "$(dirname "$0")/../.." && pwd -P)

commit_all() {
  git add -A
  git commit -q -m "$1"
}

start() {
  git symbolic-ref HEAD refs/heads/main
  if [ "${1:-gate}" = gate ]; then
    printf '## Gates\n\ngate: true\n' >CLAUDE.md
  else
    printf '## Gates\n\nRun the checks.\n' >CLAUDE.md
  fi
  echo one >a.txt
  commit_all base
}

baseline() {
  git_dir=$(git rev-parse --absolute-git-dir)
  mkdir -p "$git_dir/countersign/sessions"
  git rev-parse 'HEAD^{tree}' >"$git_dir/countersign/sessions/s1"
}

edit() {
  echo two >a.txt
}

stamp() {
  sh "$root/bin/gate" >/dev/null 2>&1
}

announce_stop() {
  jq -nc --arg provider "$1" --arg cwd "$(pwd -P)" '
    {provider: $provider, event: "stop", tool: "none", tool_name: "", command: "", paths: [],
     cwd: $cwd, session_id: "s1", subagent: false, stop_hook_active: false}' |
    sh "$root/hooks/policy/gate.sh" >/dev/null || [ $? -eq 10 ]
}

linked_worktree() {
  git worktree add -q -b wt .claude/worktrees/agent-x
  cd .claude/worktrees/agent-x
}

case $state in
  clean)
    start
    baseline
    ;;
  edited)
    start
    baseline
    edit
    ;;
  untracked)
    start
    baseline
    echo new >b.txt
    ;;
  ignored)
    start
    echo 'out/' >.gitignore
    commit_all ignore
    baseline
    mkdir out
    echo built >out/x
    ;;
  deleted)
    start
    baseline
    rm a.txt
    ;;
  committed)
    start
    baseline
    edit
    git commit -q -am edit
    ;;
  blocked-before)
    start
    baseline
    edit
    announce_stop claude
    announce_stop codex
    ;;
  stamped)
    start
    baseline
    edit
    stamp
    ;;
  stamped-edited)
    start
    baseline
    edit
    stamp
    echo three >a.txt
    ;;
  stamped-committed)
    start
    baseline
    edit
    stamp
    git commit -q -am edit
    ;;
  no-baseline)
    start
    edit
    ;;
  no-line)
    start no-line
    baseline
    edit
    ;;
  no-line-told)
    start no-line
    baseline
    edit
    git_dir=$(git rev-parse --absolute-git-dir)
    : >"$git_dir/countersign/sessions/s1.claude.told"
    : >"$git_dir/countersign/sessions/s1.codex.told"
    ;;
  agents-only)
    start
    git mv CLAUDE.md AGENTS.md
    commit_all agents
    baseline
    edit
    stamp
    ;;
  agents-only-unstamped)
    start
    git mv CLAUDE.md AGENTS.md
    commit_all agents
    baseline
    edit
    ;;
  not-repo)
    mkdir -p "$plain_home/plain"
    echo "$plain_home/plain"
    ;;
  wt-clean)
    start
    linked_worktree
    pwd -P
    ;;
  wt-edited)
    start
    linked_worktree
    edit
    pwd -P
    ;;
  wt-no-line)
    start no-line
    linked_worktree
    edit
    pwd -P
    ;;
  wt-stamped)
    start
    linked_worktree
    edit
    stamp
    pwd -P
    ;;
  *)
    exit 1
    ;;
esac
