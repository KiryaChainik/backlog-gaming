---
name: xcodebuild-triage
description: Diagnoses and fixes build failures quickly for this iOS project. Use when user says app does not build, shows Xcode errors, or reports simulator/destination issues.
---

# Xcodebuild Triage

## Instructions

1. Reproduce with `xcodebuild` on an available simulator destination.
2. If destination is invalid, switch to an installed simulator (e.g. iPhone 17).
3. Classify failure type:
   - compile/type errors,
   - Swift 6 actor isolation warnings-as-errors,
   - config/signing/destination issues.
4. Fix root cause (not just symptom).
5. Re-run build to green before final response.

## Common project-specific pitfalls

- `ShapeStyle` misuse in SwiftUI fills.
- `@MainActor` isolation leakage into `Codable` contexts.
- Gesture refactors introducing compile regressions in large SwiftUI views.

## Output format

- **Root cause**
- **Fix applied**
- **Build result** (succeeded/failed + destination used)
