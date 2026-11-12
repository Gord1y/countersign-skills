#!/bin/sh
set -eu

state=$1
row_dir=$2
row_home=$3

commit_and_add_worktree() {
  name=$1
  git -C "$row_dir" -c user.name=fixture -c user.email=fixture@example.invalid -c commit.gpgsign=false commit -q --allow-empty -m fixture
  git -C "$row_dir" worktree add -q -b "$name" "$row_dir/.claude/worktrees/$name"
}

write_fence() {
  fence_home=$(cd "$1" && pwd -P)
  approved=$2
  stamp=$3
  allow=$4
  shift 4
  plan=$row_home/plan.md
  scope_dir=$row_dir/.git/countersign/scope.d
  sum=$(printf '%s' "$fence_home" | cksum | cut -d' ' -f1)
  printf 'Approved: %s 2026-11-12\n' "$stamp" >"$plan"
  mkdir -p "$scope_dir"
  {
    printf 'plan\t%s\n' "$plan"
    printf 'approved\t%s\n' "$approved"
    printf 'home\t%s\n' "$fence_home"
    printf 'allow\t%s\n' "$allow"
    for named in "$@"; do
      printf 'named\t%s\n' "$named"
    done
  } >"$scope_dir/$sum"
}

write_default_fence() {
  write_fence "$1" "$2" "$3" '^src(/.*)?$' '^package\.json$' '^src/db/migrations/[^/]*$'
}

commit_and_add_worktree agent-x
builder=$row_dir/.claude/worktrees/agent-x

case $state in
  fenced)
    write_default_fence "$row_dir" abc abc
    mkdir -p "$builder/src"
    ln -s ../lib/a.ts "$builder/src/file.ts"
    printf '%s\n' "$builder"
    ;;
  fenced-wide)
    write_fence "$row_dir" abc abc '^\.github(/.*)?$'
    mkdir -p "$builder/.github/workflows"
    printf '%s\n' "$builder"
    ;;
  fenced-wide-named)
    write_fence "$row_dir" abc abc '^\.github(/.*)?$' '^\.github/workflows/ci\.yml$'
    mkdir -p "$builder/.github/workflows"
    printf '%s\n' "$builder"
    ;;
  fenced-other-worktree)
    git -C "$row_dir" worktree add -q -b mine "$row_dir/.claude/worktrees/mine"
    write_default_fence "$row_dir" abc abc
    printf '%s\n' "$row_dir/.claude/worktrees/mine"
    ;;
  main-checkout)
    write_default_fence "$row_dir" abc abc
    ;;
  codex-fenced)
    git -C "$row_dir" worktree add -q -b worktree-agent-codex-01 "$row_dir/.claude/worktrees/agent-codex-01"
    write_default_fence "$row_dir" abc abc
    mkdir -p "$row_dir/.claude/worktrees/agent-codex-01/src"
    ;;
  codex-reapproved)
    git -C "$row_dir" worktree add -q -b worktree-agent-codex-01 "$row_dir/.claude/worktrees/agent-codex-01"
    write_default_fence "$row_dir" abc def
    ;;
  codex-unfenced)
    git -C "$row_dir" worktree add -q -b worktree-agent-codex-01 "$row_dir/.claude/worktrees/agent-codex-01"
    ;;
  codex-fenced-other-home)
    git -C "$row_dir" worktree add -q -b worktree-agent-codex-01 "$row_dir/.claude/worktrees/agent-codex-01"
    git -C "$row_dir" worktree add -q -b agent-o "$row_dir/.claude/worktrees/agent-o"
    write_default_fence "$row_dir/.claude/worktrees/agent-o" abc abc
    ;;
  codex-fenced-nested)
    git -C "$row_dir" worktree add -q -b agent-o "$row_dir/.claude/worktrees/agent-o"
    git -C "$row_dir/.claude/worktrees/agent-o" -c user.name=fixture -c user.email=fixture@example.invalid -c commit.gpgsign=false commit -q --allow-empty -m nested
    git -C "$row_dir/.claude/worktrees/agent-o" worktree add -q -b worktree-agent-codex-01 "$row_dir/.claude/worktrees/agent-o/.claude/worktrees/agent-codex-01"
    write_default_fence "$row_dir/.claude/worktrees/agent-o" abc abc
    ;;
  fenced-from-worktree)
    git -C "$row_dir" worktree add -q -b agent-o "$row_dir/.claude/worktrees/agent-o"
    write_default_fence "$row_dir/.claude/worktrees/agent-o" abc abc
    printf '%s\n' "$builder"
    ;;
  unfenced)
    printf '%s\n' "$builder"
    ;;
  plan-gone)
    write_default_fence "$row_dir" abc abc
    rm -f "$row_home/plan.md"
    printf '%s\n' "$builder"
    ;;
  reapproved)
    write_default_fence "$row_dir" abc def
    printf '%s\n' "$builder"
    ;;
  *)
    exit 1
    ;;
esac
