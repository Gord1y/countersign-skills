---
description: A request to map a repo's features for agents should load the repo-knowledge skill.
tags: [repo-knowledge, fires]
max_turns: 10
timeout_seconds: 180
allowed_tools: [Read, Glob, Grep, Skill]
---
Agents keep missing facts about this repo, like which folder owns invoicing and why we never call the billing API directly. Set up a knowledge graph for it: feature notes mapped to the code paths, a glossary, and a check in CI that keeps it from drifting.
