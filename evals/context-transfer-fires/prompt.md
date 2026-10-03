---
description: A request to carry a session over to a fresh chat should load the context-transfer skill.
tags: [context-transfer, fires]
max_turns: 10
timeout_seconds: 180
allowed_tools: [Read, Glob, Grep, Skill]
---
This conversation has got long and I'm switching to a new chat. We decided to move the billing webhooks to a queue because retries were duplicating invoices, we verified the idempotency key fix in staging, and the remaining work is the dead-letter handling. Write me something I can paste into the new chat so it can pick up exactly where we stopped.
