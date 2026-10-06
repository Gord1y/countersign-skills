---
description: A request to add a release note entry should load the release-notes skill.
tags: [release-notes, fires]
max_turns: 10
timeout_seconds: 180
allowed_tools: [Read, Glob, Grep, Skill]
---
Add the CSV export I just merged into `release-2.3.0` to its release note, `releases/release-2.3.0.md`. The invoices page now has an Export button that downloads the rows currently shown as a CSV file.
