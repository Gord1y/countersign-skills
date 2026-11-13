#!/bin/sh
set -eu

state=${1:-}

case $state in
  on-feature)
    git symbolic-ref HEAD refs/heads/feat-x
    ;;
  on-main)
    git symbolic-ref HEAD refs/heads/main
    ;;
  on-release)
    git symbolic-ref HEAD refs/heads/release-1.8.0
    ;;
  detached)
    git commit -q --allow-empty -m init
    git checkout -q --detach
    ;;
  with-sub)
    git symbolic-ref HEAD refs/heads/feat-x
    mkdir sub
    git -C sub init -q
    git -C sub symbolic-ref HEAD refs/heads/feat-y
    ;;
  with-sub-main)
    git symbolic-ref HEAD refs/heads/feat-x
    mkdir sub
    git -C sub init -q
    git -C sub symbolic-ref HEAD refs/heads/main
    ;;
  *)
    exit 1
    ;;
esac
