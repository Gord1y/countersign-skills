---
description: A request to explain how a subsystem works before changing it should load the how-it-works skill.
tags: [how-it-works, fires]
max_turns: 10
timeout_seconds: 180
allowed_tools: [Read, Glob, Grep, Skill]
---
Our app has a job scheduler: a cron-style trigger enqueues jobs into Redis, worker processes pull them, and failed jobs go to a retry set with a delay. I'm about to change the retry behaviour and have never touched this part. Explain how that whole subsystem works so I understand it first: the main concepts, how a job flows through it, where things live, and what usually trips people up.
