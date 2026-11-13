---
description: A bug report on a codebase should load the orchestrate skill.
tags: [orchestrate, fires]
max_turns: 10
timeout_seconds: 180
allowed_tools: [Read, Glob, Grep, Skill]
---
Our `GET /invoices` endpoint returns 500 when a customer has no billing address. Find the cause and fix it, with a test.
