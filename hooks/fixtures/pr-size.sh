#!/bin/sh
set -eu

state=$1

lines() {
  awk -v n="$1" 'BEGIN { for (i = 1; i <= n; i++) print "line " i }'
}

write() {
  mkdir -p "$(dirname "$2")"
  lines "$1" >"$2"
}

commit_all() {
  git add -A
  git commit -q -m "$1"
}

start() {
  git symbolic-ref HEAD refs/heads/main
  echo base >README.md
  commit_all base
}

branch_from() {
  git checkout -q -b "$1"
}

case $state in
  small)
    start
    branch_from feat-x
    write 50 src/a.ts
    commit_all work
    ;;
  large)
    start
    branch_from feat-x
    write 450 src/a.ts
    commit_all work
    ;;
  lock-heavy)
    start
    branch_from feat-x
    write 50 src/a.ts
    write 2000 pnpm-lock.yaml
    commit_all work
    ;;
  generated-heavy)
    start
    branch_from feat-x
    write 50 src/a.ts
    write 900 src/generated/api.ts
    write 900 dist/x.js
    commit_all work
    ;;
  locale-heavy)
    start
    branch_from feat-x
    write 50 src/a.ts
    write 900 messages/de.json
    commit_all work
    ;;
  source-locale-heavy)
    start
    branch_from feat-x
    write 450 messages/en.json
    commit_all work
    ;;
  release-head)
    start
    branch_from release-2.0
    write 900 src/a.ts
    commit_all work
    ;;
  base-staging)
    start
    branch_from staging
    write 900 src/staged.ts
    commit_all staged
    branch_from feat-x
    write 50 src/a.ts
    commit_all work
    ;;
  *) exit 1 ;;
esac
