---
description: A small diff the user does not trust should load the impact-check skill.
tags: [impact-check, fires]
max_turns: 10
timeout_seconds: 180
allowed_tools: [Read, Glob, Grep, Skill]
---
I'm about to merge this two-line change to our date helper and I don't fully trust it. What could it break outside the diff, and is it safe to merge?

```diff
--- a/src/lib/dates.ts
+++ b/src/lib/dates.ts
@@ -12,3 +12,3 @@ export function formatDay(value: Date): string {
-  return value.toISOString().slice(0, 10)
+  return value.toLocaleDateString('en-GB')
 }
```
