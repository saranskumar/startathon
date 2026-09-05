# 2. The Core Model

## 2.1 Ability axes
Model **every** user — disabled or not — as a point on continuous axes. Minimum viable set for this project:

| Axis | Spectrum (one end → other end) | Governs |
|---|---|---|
| **Touch precision** | hits tiny targets → only one large zone → no reliable touch | Interface resolution (how many/how big the controls are), and which touch input *method* is viable (see [03 — Input & Calibration](03-input-calibration.md)) |
| **Speech clarity** | clear + fast → slow/slurred → single sounds only → none | Whether/how voice input is used, and how patient recognition must be |
| **Vision** | reads normal screen → needs large text → no usable vision | Output mode (screen vs. proactive narration) |

*(Future axes — cognitive load tolerance, hearing, steadiness/tremor — can extend the same model. Not in the v1 build.)*

## 2.2 The three theses
**Thesis A — Spectrum:** A tool that adapts to a user's *coordinates on these axes* serves vastly more people than a tool built for one fixed point.

**Thesis B — Composition (modality fusion):** When a user has *partial* ability on more than one axis, fusing those partial abilities produces a better interaction than any single modality alone — because each modality covers another's weakness:
- **Touch is good at selection** (pick this contact) but bad at free text.
- **Voice is good at free text** (say the message) but bad at reliable precise selection.
- A user with imprecise-but-present touch **and** slurred-but-present speech is far more capable using **both** — big touch zones for selection, patient voice for content — than being forced into either alone.

**Thesis C — Task-aware composition:** Composition isn't only per-user. Each *task* has an ideal input type (a discrete choice suits buttons, continuous movement suits a joystick, free pointing suits a trackpad), constrained by what the user's calibration says they can actually operate. See [03 — Input & Calibration](03-input-calibration.md) for the full mechanism.

**Composition is the innovation.** Not the agent.

## 2.3 The capability profile (the object everything runs off)
One data structure drives the entire system:

```
profile = {
  touch: {
    method_scores:    <per-method calibration score, e.g. {buttons: 0.9, joystick: 0.4, trackpad: 0.7}>
    reachable_zone:   <region of screen the user can comfortably reach>,
    min_target_size:  <smallest control the user can reliably hit>,
    steadiness:       <tremor / accidental-touch tolerance>,
    max_controls:     <how many controls to show at once>
  },
  speech: {
    available:        <true | false>,
    clarity_level:    <full | partial | sounds | none>
  },
  vision: {
    mode:             <screen | large | none>
  }
}
```

- The **input** composition adapts to the input axes (touch + speech), and now also to *which touch method* the user can operate (`method_scores`).
- The **output** composition adapts to the output axis (vision).
- Input and output are **decoupled**: e.g. great vision + no motor = rich screen output but minimal fused input; no vision + good motor = minimal narration output but rich input.

> Note: `method_scores` replaces the earlier assumption of a single touch surface. See [03 — Input & Calibration](03-input-calibration.md) for how these scores are produced and used.

## 2.4 The precision–inference coupling
A deliberate design law of the system:

> **The less precise the user's input, the lower the interface resolution — and the more the agent infers, always gated by confirmation.**

- High-precision input → more direct controls, less AI guessing, less confirmation friction.
- Low-precision input → fewer/bigger controls, the agent fills the inference gap, and confirmation before consequential actions protects against wrong guesses.
- This also applies when a task is done via a **fallback input method** (§3 of [03 — Input & Calibration](03-input-calibration.md)): the more indirect the fallback interaction (e.g. buttons doing coarse-to-fine zone narrowing for what's normally a pointing task), the more the agent should help narrow things down rather than leaving it all to the user.

Input precision literally tunes the ratio of *user specifies* vs. *AI infers*.
