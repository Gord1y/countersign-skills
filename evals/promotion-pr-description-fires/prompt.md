---
description: A request for a release PR's body should load the promotion-pr-description skill.
tags: [promotion-pr-description, fires]
max_turns: 10
timeout_seconds: 180
allowed_tools: [Read, Glob, Grep, Skill]
---
I need a PR desc for this release: `release-2.3.0` goes into `staging` next. Its release note is `releases/release-2.3.0.md`, titled "Faster invoice exports", with one Added entry ("Invoices export as CSV") and one Fixed entry ("The export no longer stops when storage is briefly unavailable").
