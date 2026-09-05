# Adaptive Capability-Profile Access Layer

Startathon submission.

## Core idea

Most accessibility tools force a user into one fixed, pre-labeled bucket — "screen reader user," "switch user," "voice user" — and make them adopt a single input method wholesale. This project instead treats accessibility as a **continuous capability profile**: every user is measured (via short calibration tests, not a self-reported disability label) on a handful of ability axes — touch precision, speech clarity, vision — and the interface is assembled from whatever *combination* of partial abilities that person actually has, rather than picking the one modality they're "supposed" to use.

Two ideas make this work:

1. **Composition, not selection.** Two weak input channels used together (e.g. imprecise touch + unclear-but-detectable speech) beat forcing a user to rely on one weak channel alone. The system fuses whatever partial signal is available instead of demanding one clean one.
2. **Composition is two-layered.** It happens *per-user* (calibration decides what this person can actually operate, scored per input method rather than pass/fail) **and** *per-task* (each task/screen has a design-time ideal input type — discrete choice, continuous/directional, free pointing — and the system falls back to a user's best-scoring method, using that method's own native interaction pattern, only when it scores meaningfully better than the task's ideal).

An AI agent sits underneath this to fill inference gaps — e.g. matching fused, imprecise multi-modal input to a real action — but it's infrastructure, not the product: it's used narrowly (matching intent to a tree node, or simplifying a complex UI tree) and always under a confirmation gate, not as a general orchestrator interpreting everything.

See [docs/idea/](docs/idea/README.md) for the full concept (problem, model, calibration design, scope, risks, event-submission answers) and [docs/tech/](docs/tech/README.md) for implementation notes and research briefs. [`code/app/`](code/app/) is the Flutter phone/remote-control app; [`code/mock/`](code/mock/) is the mock target application the adaptive layer operates on; [`presentation/`](presentation/README.md) is the pitch deck.

---

## Latest changes

Reverse-chronological log of changes to the idea/project — most recent first. Each entry links to the doc(s) that carry the full detail; this is a pointer trail, not a duplicate of their content.

- **Built the phone input layer for real: full calibration plus every input pattern, with no agent attached.** Seven calibration steps (reach, buttons, joystick, trackpad, touch-and-hold, voice, vision) produce a live capability profile, and the runtime renders four task shapes through all four touch methods — the whole 3×4 fallback matrix, not just the two the demo needs — with touch+voice fusion on the text task. Resolved intents go to an on-screen output strip placed in the screen region calibration found the user cannot reach, since nothing is wired to a laptop yet; speech recognition is the one stubbed piece, behind a single interface. See [code/app/README.md](code/app/README.md) and the rendered screens in [code/app/test/goldens/](code/app/test/goldens/).
- **Researched input modes beyond touch/speech/switch-scanning, and captured the meeting behind it.** Web-researched gaze/eye-tracking, head-tracking, sip-and-puff, EMG, and non-invasive BCI (all roadmap, not build-scope — mostly need hardware a phone doesn't have), confirmed Android Voice Access's "show grid" already ships the meeting's "grid-based voice input" idea, and followed up on four calibration-primitive gaps the meeting raised (touch-and-hold, pattern/per-axis swipes, a sound-count voice vocabulary, predictive-text-with-minimal-confirm). See [docs/idea/20-meeting-notes-input-modes.md](docs/idea/20-meeting-notes-input-modes.md) and [docs/tech/research/10-additional-input-modes.md](docs/tech/research/10-additional-input-modes.md).
- **Resolved the open questions raised in the tree-simplification and feature-ranking meetings.** Two were externally researched (tree-node importance ranking, vision calibration method); the rest reasoned through directly, including a unified statement of the project's riskiest assumption and one real build-order tension flagged for a team call. See [docs/idea/19-open-questions-resolved.md](docs/idea/19-open-questions-resolved.md).
- **Narrowed AI's role to tree-simplification, not the orchestrating agent.** Captured the actual meeting behind this decision, added canvas-submission answers, and filled in the remaining tech research briefs (agent execution layer, mobile/remote architecture, feature ranking, vision calibration). See [docs/idea/16-canvas-submission.md](docs/idea/16-canvas-submission.md) and [docs/idea/17-meeting-notes-tree-simplification.md](docs/idea/17-meeting-notes-tree-simplification.md).
- **Added the pitch narrative brain dump** — origin story, "who's already served" framing, worked input/output examples. See [docs/idea/15-brain-dump.md](docs/idea/15-brain-dump.md).
- **Locked the agent's target automation surface and build order**: browser accessibility tree (Playwright-driven Chromium), not native OS apps — native desktop control is explicitly out of scope for this event. See [docs/tech/README.md](docs/tech/README.md).
- **Added India market research** — market size, userbase, adoption barriers, and which competitive claims are actually pitch-safe. See [docs/idea/14-market-research.md](docs/idea/14-market-research.md).
- **v3 → v4: composition became two-layered.** Split the single "fuse whatever the user can do" idea into per-user calibration *and* per-task ideal-vs-fallback input selection. See [docs/idea/03-input-calibration.md](docs/idea/03-input-calibration.md).
- **v1/v2 → v3: dropped disability-category labels for continuous ability axes**, and introduced modality composition/fusion as the core mechanism instead of single-modality selection. See [docs/idea/README.md](docs/idea/README.md) §0.
