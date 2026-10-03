## Code

- **Zero comments** — no `//`, no `/* */`, no JSDoc, in any project. Names carry the meaning.
  The only exception is machine-readable pragmas (`'use client'`, `eslint-disable` with a
  reason). Rationale that would have been a comment goes into the project's docs or README —
  and actually gets written there, never dropped.
- **Strict TypeScript, no `any`.** Use `unknown` and narrow; no `!` except right after a checked
  guard in the same scope; infer types from schemas instead of hand-duplicating them.
- **Boring and obvious over clever.** Write the implementation I can defend line-by-line.
- **Match the existing codebase first.** Before writing anything, find how the repo already does
  it — reuse its patterns, utilities, and naming instead of inventing new ones.
