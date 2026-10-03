---
description: A request for a PR body should load the feature-pr-description skill.
tags: [feature-pr-description, fires]
max_turns: 10
timeout_seconds: 180
allowed_tools: [Read, Glob, Grep, Skill]
---
Draft the description for my pull request. The branch adds a retry with backoff to the invoice export job, because it failed whenever the storage API returned a 503. The change is in `src/jobs/exportInvoices.ts` (new `withRetry` wrapper, three attempts) and `src/jobs/exportInvoices.test.ts` (two new tests for the retry path).
