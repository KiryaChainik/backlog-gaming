---
name: mvp-ux-polish-pass
description: Applies a fast UX polish pass for MVP screens with minimal code churn. Use when user asks to make UI cleaner, less chaotic, more readable, or more consistent.
---

# MVP UX Polish Pass

## Instructions

1. Identify top UX pain in current screen from screenshot/code:
   - visual noise,
   - weak hierarchy,
   - inconsistent spacing/alignment,
   - repeated metadata,
   - unclear affordances.
2. Propose and apply only 3-5 highest-impact changes.
3. Prefer local refactor over redesign:
   - adjust typography hierarchy,
   - align spacing/tokens,
   - reduce duplicate text,
   - unify icon/color semantics.
4. Keep behavior unchanged unless user asked otherwise.
5. Build after edits and report what improved.

## Backlog Gaming heuristics

- Task title must dominate; meta should be secondary.
- Timeline patterns should match across Backlog and Flow.
- Avoid duplicate date/game labels in same row.
- Preserve quick interactions (tap, toggle, drag/context where applicable).

## Output format

- **UX issues found** (max 5)
- **Polish changes applied** (file-level bullets)
- **Verified** (build + quick interaction sanity)
