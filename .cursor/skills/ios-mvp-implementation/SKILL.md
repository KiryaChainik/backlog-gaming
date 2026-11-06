---
name: ios-mvp-implementation
description: Implements MVP iOS changes in fast phases with safety checks. Use when user asks to implement/fix/build features directly ("делай", "внедри", "сделай", "почини") in this Backlog Gaming project.
---

# iOS MVP Implementation

## Instructions

1. Start with interactive clarification (`AskQuestion`) for medium/large requests:
   - goal, constraints, priority, done criteria.
2. Build a mini plan (3-7 bullets) from selected options.
3. Implement directly (no long re-planning if requirements are clear).
4. Keep scope tight to requested feature/fix.
5. After edits touching 2+ files, run project build check.
6. If build fails, fix before final response.
7. Run requirement traceability before final response.
8. Return concise report: changed / verified / risks.

## Project-specific checks

- Prefer existing architecture: SwiftUI + Store-based MVVM.
- Preserve gesture-safe patterns:
  - `Button(.plain)` over `onTapGesture` near drag/toggle actions.
  - Avoid `List` inside `ScrollView`.
- Keep date formatting consistent with `AppDateFormatting`.

## Output format

- **Changed**: key file-level changes (3-6 bullets)
- **Verified**: build + key scenario checks
- **Risks/next**: remaining caveats or next useful step
- **Coverage**: each user requirement mapped to `done / partial / not done`
