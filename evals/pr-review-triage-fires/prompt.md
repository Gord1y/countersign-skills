---
description: A request to triage the review comments on a PR should load the pr-review-triage skill.
tags: [pr-review-triage, fires]
max_turns: 10
timeout_seconds: 180
allowed_tools: [Read, Glob, Grep, Skill]
---
My pull request got a bot review and two human comments, and a few threads are still open. Go through all of it, check which findings are real at the current head of the branch, tell me what the reviewers missed, and give me a plan to fix it. The PR is https://github.com/example-org/example-repo/pull/482
