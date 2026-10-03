---
description: A question needing several exploratory reads across a repo should load the codebase-research skill.
tags: [codebase-research, fires]
max_turns: 10
timeout_seconds: 180
allowed_tools: [Read, Glob, Grep, Skill]
---
I need to understand how authentication works across a monorepo I don't know yet: where tokens are issued, where they are refreshed, and which services validate them. I expect this to take many searches and file reads, and I want to keep the cost of the exploration down. How should you go about finding this out?
