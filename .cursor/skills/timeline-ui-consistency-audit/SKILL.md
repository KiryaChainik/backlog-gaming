---
name: timeline-ui-consistency-audit
description: Audits and aligns timeline/task UI consistency between Backlog and Flow screens. Use when user reports visual mismatch, chaos, or asks to make UX cleaner/consistent.
---

# Timeline UI Consistency Audit

## Instructions

1. Compare task presentation across:
   - `GamesTabView` task rows (inside game card),
   - `FlowTimelineViews` rows.
2. Check consistency dimensions:
   - color source (task vs game),
   - node/stem geometry,
   - text hierarchy (title/subtitle/meta),
   - spacing and alignment,
   - date duplication/noise,
   - section/card width parity,
   - border/corner-radius parity.
3. Propose minimal, high-impact changes first.
4. Apply same visual tokens where patterns are equivalent.
5. Rebuild and report verified visual parity.
6. Include a compact token diff (before/after): `spacing`, `radius`, `stroke`, `font`.

## Backlog Gaming parity target

- Timeline node/stem style should feel like one design system.
- Task color must reflect task settings unless user explicitly requests game-level color grouping.
- Secondary metadata should not overpower task title.

## Output format

- **Mismatch found**: concrete differences
- **Applied alignment**: exact style decisions made
- **Verified parity**: where matched (Backlog/Flow sections)
- **Token diff**: normalized values used across files
