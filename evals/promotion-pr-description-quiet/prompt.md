---
description: A feature PR into a release branch must not load the promotion-pr-description skill.
tags: [promotion-pr-description, quiet]
max_turns: 10
timeout_seconds: 180
allowed_tools: [Read, Glob, Grep, Skill]
---
Write the description for my pull request from `fix/login-redirect` into `release-2.3.0`. It sends a signed-out user back to the page they asked for after they sign in, instead of the dashboard. The change is in `src/auth/redirect.ts` and its test.
