#!/bin/sh
set -eu

state=$1
row_dir=$2
row_home=$3

add_worktree() {
  git -C "$row_dir" -c user.name=fixture -c user.email=fixture@example.invalid -c commit.gpgsign=false commit -q --allow-empty -m fixture
  git -C "$row_dir" worktree add -q -b agent-x "$row_dir/.claude/worktrees/agent-x"
  printf '%s\n' "$row_dir/.claude/worktrees/agent-x"
}

list_row_dir() {
  mkdir -p "$row_home/.config/countersign/profile"
  printf '%s\n' "$row_dir" >"$row_home/.config/countersign/profile/worktree-only.tsv"
}

case $state in
  worktree)
    add_worktree
    ;;
  listed)
    list_row_dir
    ;;
  listed-worktree)
    list_row_dir
    add_worktree
    ;;
  listed-link)
    list_row_dir
    mkdir -p src writeups
    ln -s ../src/f writeups/link
    ;;
  no-repo)
    mkdir -p "$row_home/plain"
    printf '%s\n' "$row_home/plain"
    ;;
  *)
    exit 1
    ;;
esac
