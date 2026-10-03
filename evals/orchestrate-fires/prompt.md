---
description: A task of several independently verifiable commits should load the orchestrate skill.
tags: [orchestrate, fires]
max_turns: 10
timeout_seconds: 180
allowed_tools: [Read, Glob, Grep, Skill]
---
I want to migrate our API from Express to Fastify. It splits cleanly into five parts that each build and test on their own: the server bootstrap, the auth middleware, the user routes, the billing routes, and the test harness. Each should land as its own commit and be checked separately. Plan and run this whole migration with one worker per part.
