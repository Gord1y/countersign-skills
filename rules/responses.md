## Responses

- English always, whatever language I write in.
- Lead with the outcome, then a brief why. Don't restate my question, don't pad.
- **Visual choices from what I can see.** Put a layout, colour, icon, size or UI-wording choice to
  me only once the options are rendered and open in front of me (an artifact page, or the images
  opened in Preview), never from a description. A preview of new UI uses the component's real
  classes and tokens, in light and dark, with every state.

### Summary markers

End-of-turn summaries get scanned, not read. Mark the lines that carry weight with one reserved
emoji:

| Marker | Use it for |
| --- | --- |
| ✅ | Done _and_ verified: tests run, command exited clean, output read. Never for code merely written. |
| ❌ | A defect that exists now: failing test, broken behavior, found bug. Say whether you introduced it. |
| ⚠️ | Nothing broken, but a risk, caveat or accepted trade-off, including assumptions that could be wrong. |
| ⏭️ | In scope or adjacent, deliberately skipped or blocked. Always say why. |
| 🙋 | An action only I can take: migration, push, deploy, credential, external approval. |
| ❓ | A decision you need from me. |
| 💡 | An optional improvement you did not make and I did not ask for. |

- Only in the closing summary of a turn where work happened: never in narration, plain replies,
  code, commit messages or files you write.
- One per line, at line start, two spaces after. Never mid-sentence or two on a line: pick the
  weightier or split the line.
- The exception, not the default: ordinary prose stays unmarked, and more than ~8 marked lines
  means cut the summary, don't decorate it.
- The line reads correctly with the emoji stripped.
- Fixed meanings: never repurpose them or add reserved markers beyond these and 🧭.
- Never soften: a failing test is ❌ however easy the fix; dropped scope is ⏭️ however minor.

### Context warm-ups

🧭 marks a one- or two-sentence plain-language grounding of a feature, issue or term, placed
before the technical references that depend on it, at the first mention in a response of anything
from an earlier session or much earlier in a long conversation (a bare "issue 09" means nothing
after a context switch). It may appear outside closing summaries, with the same line mechanics;
one per topic, and the technical specifics still follow.

### Closing TL;DR

A summary with markers ends with a `>` blockquote of two or three sentences and nothing after it:
a plain tally of what is above, then what to do next, concretely and in order. No new information.
Skip it when nothing is marked.
