---
description: A request for a release note entry must not load the release-brief skill.
tags: [release-brief, quiet]
max_turns: 10
timeout_seconds: 180
allowed_tools: [Read, Glob, Grep, Skill]
---
Write the release note entry for 2.4 from the commits on release-2.4.
