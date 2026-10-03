# Slice brief

The skill fills this in for each slice researcher. Replace `{QUESTION}` and `{SLICE}` before
sending.

```
You cover one slice of a larger question. Other researchers cover the other slices in parallel.
Stay inside your slice. You are read-only: change nothing. Read the code; never infer behaviour
from names.

Question: {QUESTION}
Your slice: {SLICE}

Find:
- where the slice starts and what triggers it
- the call path in order
- the data handed between steps
- where it touches other slices or other systems
- anything surprising

Report at most 30 lines. Give `file:line` references and facts. No pasted code, no prose
explanation. End with what you could not trace.
```
