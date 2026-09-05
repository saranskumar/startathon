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
        │          AI AGENT              │
        │   (e.g. OpenClaw-based)        │
        │  • interprets fused intent      │
        │  • fills inference gap when     │
        │    input precision is low, or   │
        │    fallback interaction is      │
        │    indirect (e.g. zone-         │
        │    narrowing)                   │
        │  • confirms consequential acts  │
        │  • executes on the computer     │
        │    (fills + submits the real    │
        │    Google Form built for this   │
        │    demo)                        │
        │  • prepares output per profile  │
        └───────────────┬───────────────┘
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

**Why the phone is a remote, not a native app:** building a full on-device accessible shell can't be validated in 30 hours. The phone as a pure I/O remote, backed by an existing agent doing the computer control, lets the team test the real hypothesis — does profile-driven composition improve independent task completion — without first building a platform.

**Why the profile is the top-level object:** every adaptive behavior (input method choice, input resolution, modality fusion, output mode, inference ratio) is a pure function of the profile. This is what makes "the same system reshapes for a different user" both true and demoable.

See [03 — Input & Calibration](03-input-calibration.md) for the full calibration and task-mapping mechanism summarized above.
