# When a builder parks or fails

Read this when a hand-back reports a gap that stopped the builder, or a unit fails.

## A parked unit

A parked unit is a brief with a gap, not a failed attempt, and doesn't use the retry. If the
plan's defaults or the reversible-call rule settle it, decide, fold the answer into the brief and
respawn. If it is load-bearing, mark it parked and write the question, options and your
recommendation under the plan file's `## Waiting for you`; units depending on it park too; the
rest of the run finishes, and it all goes to the user as ❓ in the closing summary.

Respawn, don't resume: a builder that stops without changes has its worktree removed by the
harness, so a resumed one finds none.

## Edits done, tooling blocked

A builder whose diff is complete but whose install or gate the sandbox or auto mode stopped has
not failed. Verify the hand-back as Step 7 says, reading the whole diff, land it, and let Step 8's
gate cover it; record `tooling blocked` and the gate runs as 0 in the unit table. Use the retry
only when the diff itself falls short of the brief.

## A failed unit

**One corrected retry, then park it.** The respawn's brief names exactly what went wrong and fixes
the fact the builder got wrong. A second failure parks the unit with both attempts in the closing
summary. Don't finish it yourself, don't retry a third time; the other units still land.
