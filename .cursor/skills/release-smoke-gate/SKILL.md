---
name: release-smoke-gate
description: Runs a strict pre-final MVP smoke gate (build, UX paths, consistency, edge cases) and reports pass/fail coverage. Use before finalizing significant changes.
---

# Release Smoke Gate

## Instructions

1. Run build check (`xcodebuild`) on an available simulator destination.
2. Validate core paths based on touched files:
   - Backlog interactions (expand, quick add, toggle, context menu),
   - Flow interactions (periods, overdue, undated, toggle/edit/reorder),
   - visual parity for shared entities.
3. Validate edge cases:
   - empty state rendering,
   - single-item vs multi-item spacing,
   - SF Symbols validity (no runtime symbol errors).
4. Produce a strict gate result:
   - PASS only if all mandatory checks pass,
   - otherwise FAIL with explicit blockers.

## Output format

- **Gate result**: PASS / FAIL
- **Checks passed**
- **Checks failed**
- **Coverage**: requirement-to-check mapping
