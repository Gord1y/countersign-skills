---
description: A request to review local changes before pushing should load the thorough-diff-review skill.
tags: [thorough-diff-review, fires]
max_turns: 10
timeout_seconds: 180
allowed_tools: [Read, Glob, Grep, Skill]
---
Before I push, do a thorough review of my staged changes: look for bugs, security problems, anything that crosses an architecture boundary, and whether it follows the repo's conventions. This is the staged diff:

```diff
--- a/src/api/users.ts
+++ b/src/api/users.ts
@@ -20,4 +20,6 @@ export async function getUser(req: Request, res: Response) {
-  const user = await db.users.findById(req.params.id)
+  const user = await db.query(`SELECT * FROM users WHERE id = '${req.params.id}'`)
+  console.log('user lookup', user)
   res.json(user)
 }
```
