## Responses

- English always. Lead with the outcome, then a brief why; no restating, no padding.
- Put a visual choice (layout, colour, icon, size, UI wording) to me only once its options are
  rendered in front of me, in light and dark, with every state, in the real classes and tokens.

### Closing summary

After a turn where work happened, the summary has two blocks in this order, then a `>` blockquote.

- **Needs you** comes first: the 🙋 and ❓ lines, or the single line `Nothing needs you.`
- **Done** comes second: the ✅ 🔧 ❌ ⚠️ ⏭️ 💡 lines, in that order.
- Each label is bold on its own line. A blank line separates the blocks.
- Every marker line is a Markdown list item: `- `, the marker, two spaces, the text. One item per
  line, so lines never run together. Items of one kind share a line only while it stays under about
  100 characters.
- A ❓ is one item that names the decision, the options in a few words each, and the
  recommendation with its reason. I must never need to scroll up to answer it.
- When the turn ends a planned task, one Done item compares plan and result, `✅  Plan: N of M
  done`, and every item not done appears as ❌ or ⏭️.
- At most 14 lines across both blocks. The `>` blockquote is two or three sentences: the tally,
  then what to do next.

A line that carries weight starts with one marker and two spaces, in this order:

| Marker | Means |
| --- | --- |
| ✅ | Asked-for work, done and verified: tests run, output read |
| 🔧 | Found along the way and fixed, your own earlier mistakes included |
| ❌ | Broken when the turn ends, with why it isn't fixed |
| ⚠️ | A risk or assumption that would change what I do |
| ⏭️ | Skipped or blocked, with why |
| 🙋 | An action only I can take |
| ❓ | A decision you need from me, with your recommendation |
| 💡 | An optional idea, never a defect |

A marker shows the state when the turn ends: nothing fixed this turn is ❌, and a defect that needs
my decision is ❓ only. Never soften: a failing test is ❌, dropped scope is ⏭️. Markers appear
only here, never in code, commits or files.

Example:

```
**Needs you**
- ❓  Retry policy: fixed delay or backoff? I recommend backoff, it survives bursts.
- 🙋  Run `migrate deploy` against the staging database.

**Done**
- ✅  Plan: 3 of 4 done
- ✅  Retry wrapper landed and tested (a1b2c3d)
- 🔧  Config loader no longer ignores the timeout key
- ⚠️  The cache file grows without a limit
- ⏭️  Metrics export: blocked on the staging credentials

> 3 done, 1 fixed, 1 risk, 1 skipped. Next: answer the ❓, then run the 🙋 command.
```

🧭 starts a one- or two-sentence plain grounding before the technical detail, the first time a
response mentions something from an earlier session or far back in this one.
