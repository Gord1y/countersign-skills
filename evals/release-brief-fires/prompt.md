---
description: A request for the UX probe's release brief should load the release-brief skill.
tags: [release-brief, fires]
max_turns: 10
timeout_seconds: 180
allowed_tools: [Read, Glob, Grep, Skill]
---
We cut 2.4 today. Before the UX probe runs, write its brief: what changed for users since the last probed ref. The probe folder is ~/qa-probe/shop and the app runs at http://localhost:3000.
