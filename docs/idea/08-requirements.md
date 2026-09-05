# 8. Requirements

## 8.1 Functional requirements
| ID | Requirement | Priority |
|----|---|---|
| FR1 | System stores a capability profile (touch/speech/vision) and can switch between at least two | P0 |
| FR2 | Touch interface resolution (control count, size, reachable zone) is derived from the touch profile | P0 |
| FR3 | Voice input is enabled/tuned by the speech profile and waits for slow/unclear speech without timing out | P0 |
| FR4 | For a partial-ability profile, touch (selection) and voice (content) are fused in one interaction | P0 |
| FR5 | Output is delivered per the vision profile: screen view or proactive real-time narration | P0 |
| FR6 | System detects a relevant event (e.g. new message) and surfaces it in the profile's output mode | P0 |
| FR7 | System confirms with the user before any consequential action | P0 |
| FR8 | User can cancel/interrupt before an action executes | P0 |
| FR9 | Agent executes the confirmed action on the actual application/computer | P0 |
| FR10 | Lower input precision → lower interface resolution + more agent inference (precision–inference coupling) | P1 |
| FR11 | Profile is user-configurable (even a preset switch counts) rather than hardcoded per build | P1 |
| FR12 | Additional axes (steadiness, cognitive load) influence the profile | P2 (stretch) |
| FR13 | System runs a per-method calibration test (buttons, joystick, trackpad) and produces a normalized score per method | P0 |
| FR14 | System runs a reachable-zone calibration test independent of method choice | P0 |
| FR15 | System runs a voice-clarity calibration test and buckets the result | P0 |
| FR16 | For the demo task, the ideal input method renders when the user's calibration score for it clears the viability threshold; otherwise the fallback method renders using its own native interaction pattern for the same task | P0 |
| FR17 | Task-to-ideal-input mapping is fixed at design time (not decided live by the agent) | P0 |

See [03 — Input & Calibration](03-input-calibration.md) for the full design behind FR13–FR17.

## 8.2 Non-functional requirements
- No consequential action without explicit confirmation — hard constraint.
- Voice input must never penalize slow, unclear, or interrupted speech.
- Every interface state shows the fewest controls necessary for that state, at the size the touch profile requires.
- Profile switch must visibly and quickly reshape the interface (this is the demo's core moment).
- Calibration must complete in a reasonable time per user; each test step should be timeboxed and skippable.
