## Code

- Zero comments in any project; names carry the meaning. Only machine-readable pragmas stay
  (`'use client'`, `eslint-disable` with a reason). Rationale goes into the project's docs.
- Strict TypeScript: no `any` (take `unknown` and narrow), no `!` except right after a guard in the
  same scope, types inferred from schemas.
- Boring and obvious over clever. Match the codebase first: its patterns, utilities and names.
