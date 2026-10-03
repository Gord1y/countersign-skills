# Why orchestrate's rules are what they are

The evidence behind the rules in `SKILL.md`, kept here so the skill itself stays short. Read it
when a rule looks arbitrary, before changing one.

## Why an orchestrator at all

- **Builders sharing one working tree corrupt each other.** Seven once ran in a single checkout:
  each one's half-written files failed everyone else's `lint` and `typecheck`, and a partially
  written JSON file took the running dev server down for all of them.
- **A main session that writes code stops orchestrating.** It spends the most expensive context in
  the session on work a cheaper agent does as well, and has nothing left for review.

## Why builders don't commit (copy-back)

Builders that committed in their own worktrees hit four problems:

- Subagent worktrees were cut from the remote default branch, not the integration branch, so briefs
  opened with `git reset --keep <branch>`. The repos deny `git reset*`, so at least seven builders
  stopped at their first command with no changes. `worktree.baseRef: "head"` now cuts worktrees
  from the orchestrator's `HEAD`. The orchestrator checks the first worktree instead of reading
  the setting: settings merge from the user, project and local files, and a repo whose hook guards
  paths outside it asks before every read of `~/.claude/settings.json`.
- Builder commits ran the repo's pre-commit hook (lint-staged) inside the Bash sandbox, where its
  backup stash could not read a file the sandbox denied, so commits failed at random.
- `git cherry-pick` sat on the repos' `ask` list, so every integration waited for the user, and
  `git apply`, `git am`, `git merge` and `git rebase` are denied.
- Each unit left a branch behind that only the user could delete.

Landing the worktree's files with `land-worktree` and committing in the main checkout needs none of
those commands, runs the hooks once per unit in a normal checkout, and leaves only the harness's
own worktree branch, which has no commits.

An earlier stale-base case: a builder spawned after seven commits had landed branched from the
session's starting commit, reported a test count from that old base, and reasoned from a file a
landed commit had rewritten. That is why every hand-back still checks the base.

## Model tiers

- Top-tier builders stalled repeatedly on long tool chains (about ten minutes lost per stall,
  several needing a respawn), and the ones that stalled read everything before editing anything.
- A top-tier builder handed "handle odd inputs defensively" on a parser and verdict unit took an
  hour: a 345-line scanner, 56 parameterized odd-input tests, coverage runs and repeated full gates.
- In one 60-day window, top-tier builders were an eighth of all builders and used about a third of
  all builder tokens.

## Builder speed

- Builders burned 30 to 60 minutes each on repeated production builds, rediscovering before/after
  numbers the session already had.
- Units in one run took 40 to 60 minutes each. The causes were "read docs/X whole" lines,
  open-ended edge-case work, full gates after every change, and amend round trips.
- "Run the gates once" alone did not hold: builders still averaged three full-gate runs each, and
  the builders that ran it three or more times, or made thirty tool calls before their first edit,
  used 80% of all builder tokens.
- One builder ran for 692 minutes because nothing compared its elapsed time with its budget.
- Uncapped research reports have reached 75,000 characters, all of it landing in the main context.
