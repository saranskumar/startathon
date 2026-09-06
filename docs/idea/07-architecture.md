# 7. System Architecture

```
        ┌───────────────────────────────────────────────┐
        │              CAPABILITY PROFILE                │
        │   touch {method_scores,zone,size,steadiness,   │
        │          max_controls}                          │
        │   speech {available, clarity_level}            │
        │   vision {mode}                                │
        └───────────────┬───────────────────────────────┘
                        │ drives everything below
        ┌───────────────▼───────────────┐
        │   Phone (remote control /       │
        │   thin client)                  │
        │                                 │
        │  CALIBRATION (once, per user):  │
        │   • per-method touch tests       │
        │     (buttons/joystick/trackpad)  │
        │   • reachable-zone test          │
        │   • voice clarity test           │
        │   • vision test                  │
        │   → populates the profile above  │
        │                                 │
        │  INPUT COMPOSITION (per task):  │
        │   • task's ideal input method,   │
        │     or calibrated fallback       │
        │     method w/ its own native     │
        │     interaction pattern          │
        │   • patient AI voice input       │
        │     (enabled + tuned by speech   │
        │      profile)                    │
        │   → fuses selected touch method  │
        │     (selection) + voice (free    │
        │     text)                        │
        └───────────────┬─────────────────┘
                        │ fused user intent
                        ▼
        ┌───────────────────────────────┐
        │  DESKTOP DISPATCH (no AI)       │
        │  (code/desktop, Playwright)     │
        │  • ranks the page deterministic-│
        │    ally (domTreeEngine.js's     │
        │    heuristic scorer, no LLM —   │
        │    idea/28)                     │
        │  • matches fused intent to a    │
        │    tree node by nearest/highest-│
        │    ranked candidate, incl. the  │
        │    zone-narrowing fallback      │
        │  • confirms consequential acts  │
        │  • executes on the computer     │
        │    (fills + submits the real    │
        │    Google Form built for this   │
        │    demo)                        │
        │  • prepares output per profile  │
        └───────────────┬─────────────────┘
                        │ result
                        ▼
        ┌───────────────────────────────┐
        │   OUTPUT COMPOSITION            │
        │   (set by vision profile)       │
        │   • screen / large-text view    │
        │   • proactive real-time         │
        │     narration                   │
        └─────────────────────────────────┘
```

**Why the phone is a remote, not a native app:** building a full on-device accessible shell can't be validated in 30 hours. The phone as a pure I/O remote, backed by the deterministic desktop dispatcher doing the computer control, lets the team test the real hypothesis — does profile-driven composition improve independent task completion — without first building a platform.

**Why the profile is the top-level object:** every adaptive behavior (input method choice, input resolution, modality fusion, output mode, inference ratio) is a pure function of the profile. This is what makes "the same system reshapes for a different user" both true and demoable.

See [03 — Input & Calibration](03-input-calibration.md) for the full calibration and task-mapping mechanism summarized above.
