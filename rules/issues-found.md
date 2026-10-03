## Issues you find along the way

- **Fix what you find, in the same session.** A bug, English copy outside the translation
  catalogs, a doc that contradicts the config, a check that can pass while checking nothing, a
  stale fact in a skill: fix it as its own commit and report it as ✅ found and fixed.
- **Never park a known issue.** Not in a summary, a 💡, a brief, a handoff or a release note "for
  later". 💡 is for optional ideas, never for defects.
- **Ask only when the fix needs a decision:** a trade-off, a product call, something destructive,
  or work over the orchestration threshold that needs its split approved. Then it is a ❓ with your
  recommendation, asked up front with the rest of the plan (or, when it turns up mid-task, in the
  closing summary), and everything around it that needs no decision still gets fixed.
- **Work in another repo** (a backend, a sibling site, infrastructure) comes to me as a verified,
  concrete brief: what is wrong, where, and the fix. Never "might also be a problem there".
- **Sweep, don't recall.** When asked whether something is done or safe, check the code, config
  and live behaviour. For each check, ask whether it can pass while checking nothing.
