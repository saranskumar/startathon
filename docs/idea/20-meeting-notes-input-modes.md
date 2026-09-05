# 20. Meeting Notes — Input Modes for User Interface (unverified transcript)

**Source:** auto-generated meeting summary, Sept 5 2026 20:22–20:36, four unnamed speakers ("Speaker 1–4"). **Not verified against a recording or by the team — treat as a rough transcript of a real conversation, not a settled decision.** Captured here because it's the discussion that names/expands the touch and voice sub-modes referenced loosely elsewhere in [03 — Input & Calibration](03-input-calibration.md).

---

## What was discussed

**Establishing vocabulary.** Speaker 1 opened by asking for a general term to describe the different ways a user can interact with the system. The team settled on **"input modes"** as the umbrella term — this doc and future ones should use it consistently instead of ad hoc phrasing.

**Touch input modes.** The team went further than the existing three-method split (buttons/joystick/trackpad) in [03 — Input & Calibration](03-input-calibration.md) §3.1 and named finer-grained sub-behaviors:
- **Buttons** — count and spacing should adapt to the user's dexterity/preference, potentially changing after calibration (consistent with existing docs).
- **Touch and hold** — raised as a distinct input primitive, not currently in the calibration test set.
- **Flick** — a discrete, short directional movement (e.g. "flick up," "flick down").
- **Slide / trackpad** — a continuous drag movement. Speaker 4 clarified the terminology split: "slide" can be used interchangeably with "flick" when it's a discrete gesture, while "trackpad" specifically means continuous 2D dragging.
- **Axis-limited swiping** — the team noted some users may only reliably swipe on one axis (X-only or Y-only) rather than both, and with varying precision — this is a finer-grained capability than the existing trackpad calibration currently captures (today's calibration treats trackpad as one 2D score, not per-axis).
- **Pattern swipes** — more complex sequences (e.g. left-then-up, left-then-down) proposed as a way to expand the input vocabulary for users who can't reach many discrete buttons but can produce a small set of distinguishable gesture sequences.
- **Mapping to joystick/trackpad semantics** — swipe input can be interpreted either as joystick-like (relative/directional) or trackpad-like (absolute coordinate), depending on how precisely the user can produce a swipe.

Speaker 4's running summary of confirmed touch primitives by the end of this segment: **button, trackpad, slide (= flick)**.

**Voice input modes.** Prompted by Speaker 1 asking what else beyond touch, Speaker 2/3 introduced voice as its own mode with multiple sub-tiers, going beyond the existing binary framing in [03 — Input & Calibration](03-input-calibration.md) §3.1 (`full/partial/sounds/none`):
- **Clear speech** — direct speech-to-text, for users who can articulate reliably (≈ today's `full`/`partial`).
- **Slurry speech / limited vocabulary** — for users who can't produce clearly parseable words, a simplified vocal vocabulary (e.g. one sound = "yes," two consecutive sounds = "no") was proposed as more expressive than a flat binary vocalization signal (today's `sounds` tier is currently pure binary presence/absence).
- **Grid-based voice input** — divide the screen into a numbered grid; the user speaks the number/label of the region they want, which can be combined with other input modes (e.g. voice picks the region, touch confirms). Note: this is conceptually the same mechanism as Android's shipped **Voice Access "show numbers"/"show grid"** overlay feature — see the new research brief, [tech/research/10 — Additional Input Modes](../tech/research/10-additional-input-modes.md) §3, which confirms this pattern already exists in a mainstream product and is worth citing/reusing conceptually rather than treating as novel.
- **Context-based text input** — for free-text entry, predict the likely word/phrase from context and let the user confirm with a minimal yes/no-equivalent signal, rather than requiring full dictation. This is the same shape of problem as [tech/research/07 — Dasher Integration](../tech/research/07-dasher-integration.md)'s "free-text entry without reliable speech or reliable tapping" gap, just voice-driven instead of gesture-driven predictive entry — worth reading those two together.

## Open tasks the meeting ended on (unassigned to real names — speaker numbers only)

1. Research voice input models suitable for users with speech impairments. → Addressed generally in [tech/research/02 — Speech Recognition](../tech/research/02-speech-recognition.md); the specific "slurry speech, sound-count vocabulary" idea from this meeting is **not yet separately researched** — flagged as new in the open-questions update below.
2. Determine how to map input methods to specific functionalities (joystick, trackpad). → Partially covered by [03 — Input & Calibration](03-input-calibration.md) §3.2–3.3, but the finer-grained modes named in this meeting (touch-and-hold, pattern swipes, axis-limited swiping) are not yet mapped.
3. Discuss the viability of the proposed input modes. → See [tech/research/10 — Additional Input Modes](../tech/research/10-additional-input-modes.md) for a first pass, plus this file's connection notes above.
4. Research existing solutions for various input modes, especially open-source options. → See [tech/research/10](../tech/research/10-additional-input-modes.md).

## How this connects to the rest of the docs

This meeting is best read as **naming and subdividing** what [03 — Input & Calibration](03-input-calibration.md) already scopes at a coarser grain, not proposing a contradictory model. Concretely, it surfaces four candidate additions to the input-calibration design that aren't in the current schema:

- **Touch-and-hold** as a distinct primitive (not currently calibrated).
- **Per-axis swipe capability** (X-only / Y-only / both) as a finer-grained trackpad calibration output than today's single 2D score.
- **Pattern swipes** (gesture sequences) as a way to expand vocabulary for low-dexterity users without adding more on-screen buttons.
- **A richer voice-clarity vocabulary** for the `sounds` tier — sound-count-based yes/no (one sound vs. two) instead of pure binary vocalization presence, plus grid-based voice selection and context-predictive text confirm as two new *voice-driven interaction patterns* (not new calibration tiers — they reuse whatever clarity tier is already measured).

None of these are decided or built — they're candidate scope additions this meeting raised. Recommend folding the ones the team wants to keep into [03 — Input & Calibration](03-input-calibration.md) directly (as new subsections) once prioritized, and adding the rest to [12 — Roadmap](12-roadmap.md) if deferred, the same way [19 — Open Questions Resolved](19-open-questions-resolved.md) reconciled the tree-simplification and feature-ranking meetings.

**Caveat again: this is an unverified auto-transcript.** Speaker attributions are placeholders ("Speaker 1–4"), not real names, and the summary tool may have compressed or slightly misrepresented what was actually said. Confirm with whoever was in the room before treating any specific claim here as a locked decision.
