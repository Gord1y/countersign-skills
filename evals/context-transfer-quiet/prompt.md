---
description: A request to summarize one pasted paragraph must not load the context-transfer skill.
tags: [context-transfer, quiet]
max_turns: 10
timeout_seconds: 180
allowed_tools: [Read, Glob, Grep, Skill]
---
Summarize this paragraph in one sentence: "Our webhook consumer retries failed deliveries with exponential backoff, but without an idempotency key a retried delivery can create the same invoice twice, so we now store the key and skip repeats."
