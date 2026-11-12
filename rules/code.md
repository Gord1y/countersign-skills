## Code

- Zero comments in any project; names carry the meaning. Only machine-readable pragmas stay
  (`'use client'`, `eslint-disable` with a reason). Rationale goes into the project's docs.
- Strict TypeScript: no `any` (take `unknown` and narrow), no `!` except right after a guard in the
  same scope, types inferred from schemas.
- Boring and obvious over clever. Match the codebase first: its patterns, utilities and names.
- Subtract before adding: delete dead code first, make the smallest change that works, and move
  callers instead of keeping a compatibility layer for an internal API.
- Tests check behaviour through the public seam, not the implementation. A fix lands with a test
  that fails on the bug first.
