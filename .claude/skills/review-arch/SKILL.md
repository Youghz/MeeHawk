---
name: moov-livraison:review-arch
description: >
  Analyze code architecture and identify over-engineered solutions and
  simplification opportunities. Use when: (1) Reviewing architecture decisions,
  (2) Finding unnecessary complexity or reinvented wheels,
  (3) Generating an architecture review report in docs/reviews/.
  Triggers on: review architecture, arch review, over-engineering, simplify architecture.
---

# Architecture Review

Analyze the full codebase architecture unless the user specifies a narrower scope.

## Your Stance

- **Skeptical**: question every architectural decision — justify its existence
- **Pragmatic**: prefer boring, understandable solutions over clever ones
- **Package-first**: if a maintained package does it, don't reinvent it

## What to Analyze

1. **Structure**: logical organization? Intuitive for new developers? Circular deps?
2. **Patterns**: design patterns appropriate or over-applied? Unnecessary indirection?
3. **Abstraction**: appropriate for the problem size? Would removing a layer simplify things?
4. **Dependencies**: use Context7 to check latest package docs. Redundant packages?
   Outdated deps? Custom code that a package already handles?
5. **Complexity**: inheritance hierarchies justified? Abstractions for simple operations?

For each concern, ask:
- Could this be solved with an existing package?
- Would a junior developer understand this in 6 months?
- What happens if we remove this abstraction layer?

## Output

Save to `docs/reviews/[YYYY-MM-DD]-architecture.md`. Create `docs/reviews/` if
it doesn't exist. If a file with the same name already exists, override it.

Each recommendation must be **atomic and actionable** — implementable in a single
pass.

```markdown
# Architecture Review

**Date**: [YYYY-MM-DD]
**Scope**: [Full codebase / specific area]

## Summary
[1-3 sentences: overall assessment and main simplification opportunities]

## Strengths
- [Good architectural decisions to preserve]

## Recommendations

### High Impact
- [ ] **R1** — [Title]: [What to simplify, why, where. File(s): `path`]

### Medium Impact
- [ ] **R2** — [Title]: [What to simplify, why, where. File(s): `path`]

### Low Impact
- [ ] **R3** — [Title]: [What to simplify, why, where. File(s): `path`]

*Sequential numbering (R1, R2, R3…) across all categories.*
```

## After the Review

Suggest running `moov-livraison:improve-after-review` to apply recommendations.
Always wait for explicit user confirmation before invoking it.
