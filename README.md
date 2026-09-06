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

## Repository structure

A guide to what lives where and why — each area has one job, and content doesn't move between them casually (see the "rule for keeping in sync" note in [presentation/README.md](presentation/README.md) for the one place that's explicitly a derived copy, not a source of truth).

| Path | What's there | Purpose |
|---|---|---|
| `README.md` | — | This file: concept, this map, latest-changes log. |
| `timestamp.md` | — | Auto-updated by CI on every deploy; not hand-edited. |
| **`docs/`** | | **The product & technical record — source of truth, not pitch material.** |
| `docs/README.md` | — | 2-line pointer into `idea/` and `tech/`. |
| `docs/idea/` | 27 numbered docs | The product idea itself, meant to be read in order (01 → 27): problem, model, calibration design, scope, risks, event-submission answers, meeting notes. |
| `docs/idea/README.md` | — | Reading-order index + one-line summary of every doc, including the v1→v4 concept history. |
| `docs/tech/` | | Implementation notes: what's decided, assumed, or still open about the actual stack. |
| `docs/tech/README.md` | — | Build order, decided/assumed/undecided tracker, what's actually built so far. |
| `docs/tech/research/` | 14 numbered briefs | Deep-dive research (existing solutions, viability, build recommendation) for each component or raised question. |
| `docs/tech/research/README.md` | — | Index + headline verdict per research thread. |
| `docs/desgin/desgin.md` | — | One focused technical spec: how voice/text input is classified in `code/app` (clarity tiers, vocal-event kinds, text compose modes). |
| **`code/`** | | **The actual runnable pieces.** |
| `code/app/` | `lib/`, `test/`, `README.md` | Flutter phone/remote-control app — the input layer (calibration → capability profile → adaptive runtime). `lib/` splits into `calibration/`, `inputs/`, `model/`, `runtime/`, `theme/`; `test/goldens/` renders every screen. |
| `code/desktop/` | `src/`, `test/`, `README.md` | Node/Playwright agent-controlled-browser backend + desktop inspector — `domTreeEngine` (ranking), `browserSession`, `dasherModel`, the inspector server/UI. |
| `code/mock/` | — | "Aperture Daily": mock target websites the agent/phone demo operates on (rail, pay, civic, clinic, shop, mail), plus a pattern lab and demo form. |
| **`presentation/`** | | **The live pitch deck — separate from `docs/`, not the source of truth.** |
| `presentation/slides.html` | — | The deck itself. |
| `presentation/notes/` | `outline.md`, `demo-clips.md`, `sources.md` | Slide-by-slide script, the video-clip shot list, and a traceability map back to the `docs/` claim each slide uses. |
| `presentation/media/` | — | Image/video assets referenced by `slides.html`. |
| `presentation/README.md` | — | How this directory stays in sync with `docs/` (it holds copies, never originals). |
| `.github/workflows/` | — | CI: auto-deploys `code/mock` and `code/app` to Vercel on push to those folders. |
| `.claude/launch.json` | — | Dev-server config for the Claude Code browser preview tool — not app config. |

**Rule of thumb for "where does this go":**
- A new idea, requirement, or raised question → a numbered doc in `docs/idea/`, added to its `README.md` index.
- Research backing a doc/idea (external prior art, feasibility, viability) → a numbered brief in `docs/tech/research/`, cross-linked from the `docs/idea/` doc it supports.
- A build/architecture decision (what's chosen, assumed, or still undecided about the actual stack) → `docs/tech/README.md`, not a new doc.
- Actual runnable code → `code/app/` (phone), `code/desktop/` (agent/browser backend), or `code/mock/` (target websites the demo operates on) — each has its own `README.md` for what's implemented vs. simulated.
- Anything only needed to give the pitch (script, slide content, clip list) → `presentation/`, as a traceable copy of the underlying `docs/` doc, never authored fresh there.

---

## Latest changes

Reverse-chronological log of changes to the idea/project — most recent first. Each entry links to the doc(s) that carry the full detail; this is a pointer trail, not a duplicate of their content.

- **Locked the pitch's logistics and restructured the deck around them.** 15 minutes total for presentation + demo + Q&A, demo-first running order (prove it, then explain it), a hardware analogy for "adaptive input" (foot trackball, tongue mouse — hardware precedent for the same idea we do in software), and an explicit on-stage correction that this isn't an AI-first product. See [docs/idea/21-meeting-notes-presentation-prep.md](docs/idea/21-meeting-notes-presentation-prep.md) and the updated [presentation/](presentation/README.md) (`outline.md`, `slides.html`, `demo-clips.md`, `sources.md`).
- **Built the phone input layer for real: full calibration plus every input pattern, with no agent attached.** Seven calibration steps (reach, buttons, joystick, trackpad, touch-and-hold, voice, vision) produce a live capability profile, and the runtime renders four task shapes through all four touch methods — the whole 3×4 fallback matrix, not just the two the demo needs — with touch+voice fusion on the text task. Resolved intents go to an on-screen output strip placed in the screen region calibration found the user cannot reach, since nothing is wired to a laptop yet; speech recognition is the one stubbed piece, behind a single interface. See [code/app/README.md](code/app/README.md) and the rendered screens in [code/app/test/goldens/](code/app/test/goldens/).
- **Researched input modes beyond touch/speech/switch-scanning, and captured the meeting behind it.** Web-researched gaze/eye-tracking, head-tracking, sip-and-puff, EMG, and non-invasive BCI (all roadmap, not build-scope — mostly need hardware a phone doesn't have), confirmed Android Voice Access's "show grid" already ships the meeting's "grid-based voice input" idea, and followed up on four calibration-primitive gaps the meeting raised (touch-and-hold, pattern/per-axis swipes, a sound-count voice vocabulary, predictive-text-with-minimal-confirm). See [docs/idea/20-meeting-notes-input-modes.md](docs/idea/20-meeting-notes-input-modes.md) and [docs/tech/research/10-additional-input-modes.md](docs/tech/research/10-additional-input-modes.md).
- **Resolved the open questions raised in the tree-simplification and feature-ranking meetings.** Two were externally researched (tree-node importance ranking, vision calibration method); the rest reasoned through directly, including a unified statement of the project's riskiest assumption and one real build-order tension flagged for a team call. See [docs/idea/19-open-questions-resolved.md](docs/idea/19-open-questions-resolved.md).
- **Narrowed AI's role to tree-simplification, not the orchestrating agent.** Captured the actual meeting behind this decision, added canvas-submission answers, and filled in the remaining tech research briefs (agent execution layer, mobile/remote architecture, feature ranking, vision calibration). See [docs/idea/16-canvas-submission.md](docs/idea/16-canvas-submission.md) and [docs/idea/17-meeting-notes-tree-simplification.md](docs/idea/17-meeting-notes-tree-simplification.md).
- **Added the pitch narrative brain dump** — origin story, "who's already served" framing, worked input/output examples. See [docs/idea/15-brain-dump.md](docs/idea/15-brain-dump.md).
- **Locked the agent's target automation surface and build order**: browser accessibility tree (Playwright-driven Chromium), not native OS apps — native desktop control is explicitly out of scope for this event. See [docs/tech/README.md](docs/tech/README.md).
- **Added India market research** — market size, userbase, adoption barriers, and which competitive claims are actually pitch-safe. See [docs/idea/14-market-research.md](docs/idea/14-market-research.md).
- **v3 → v4: composition became two-layered.** Split the single "fuse whatever the user can do" idea into per-user calibration *and* per-task ideal-vs-fallback input selection. See [docs/idea/03-input-calibration.md](docs/idea/03-input-calibration.md).
- **v1/v2 → v3: dropped disability-category labels for continuous ability axes**, and introduced modality composition/fusion as the core mechanism instead of single-modality selection. See [docs/idea/README.md](docs/idea/README.md) §0.
