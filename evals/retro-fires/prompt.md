---
description: The end of a run with two user corrections and a failed gate should load the retro skill.
tags: [retro, fires]
max_turns: 10
timeout_seconds: 180
allowed_tools: [Read, Glob, Grep, Skill]
---
That run is merged. Along the way I corrected you twice for writing comments into shell scripts, and the lint gate failed once on the same thing. Do a retro so this stops happening.
