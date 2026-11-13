#!/bin/sh
set -eu

state=$1

commit_all() {
  git add -A
  git commit -q -m "$1"
}

start() {
  git symbolic-ref HEAD refs/heads/main
  echo base >README.md
  commit_all base
  git checkout -q -b feat-x
}

change() {
  mkdir -p "$(dirname "$1")"
  echo changed >"$1"
  commit_all work
}

case $state in
  ui)
    start
    change src/App.tsx
    ;;
  styles)
    start
    change src/a.css
    ;;
  no-ui)
    start
    change src/a.ts
    ;;
  ui-body)
    start
    change src/App.tsx
    printf '## Walkthrough\n\n![home, light](https://example.com/a.png)\n' >body.md
    ;;
  ui-body-bare)
    start
    change src/App.tsx
    printf 'Summary only\n' >body.md
    ;;
  no-base)
    git symbolic-ref HEAD refs/heads/feat-x
    echo base >README.md
    commit_all base
    ;;
  *) exit 1 ;;
esac
