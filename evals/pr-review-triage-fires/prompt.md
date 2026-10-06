---
description: A request to triage the review comments on a PR should load the pr-review-triage skill.
tags: [pr-review-triage, fires]
max_turns: 10
timeout_seconds: 180
allowed_tools: [Read, Glob, Grep, Skill]
---
My pull request got a bot review and two human comments, a few threads are still open, and the CI run failed. Go through all of it, check which findings and failures are real at the current head of the branch, and give me a plan to fix them. The PR is https://github.com/example-org/example-repo/pull/482
