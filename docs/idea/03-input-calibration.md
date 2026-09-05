# 3. Input & Calibration

This is the layer that turns the abstract capability profile ([02 — Core Model](02-core-model.md)) into something measured from a real user, and turns that measurement into which input surface renders for which task. Worked out during pitch prep; fully functional across all inputs is the current build target (not scripted/staged), per team decision.

---

## 3.1 Calibration: measuring the touch axis across multiple input methods

The touch axis isn't just "how big should the control be" — different users may not be able to operate the same *kind* of control at all. Candidate touch input methods:

- **Buttons** — discrete tap targets.
- **Joystick** — a virtual stick for continuous/directional movement.
- **Trackpad** — a drag surface for free 2D pointing.

### Per-method test
Each method gets the same abstract test — "reach this target" — so scores are comparable across methods even though the physical interaction differs:

| Method | Calibration test |
|---|---|
| Buttons | Show 2–3 buttons at varying size/position; ask the user to press each in sequence. |
| Joystick | Show a target direction/zone; ask the user to move the stick there and hold. |
| Trackpad | Show a target zone; ask the user to drag a pointer into it. |

For each attempt, capture: success/fail, time-to-target, and error (distance off-target / number of mis-hits before success). Combine into one normalized score per method:

```
score(method) = 0.5 × success_rate + 0.3 × (1 − time_normalized) + 0.2 × (1 − error_normalized)
```

Output is a **score table per user**, not a single winner — e.g. `{buttons: 0.9, joystick: 0.4, trackpad: 0.7}`. Keeping all three scores (not just the best) is what makes the fallback-interaction design in §3.3 possible.

### Reachable zone
Separate from method choice — ask the user to tap a grid of points spread across the screen (or just the four corners + center), and record which register reliably. This builds `reachable_zone` regardless of which method scored highest.

### Voice
Ask the user to say one short fixed phrase. Score via whatever the speech API returns (per-utterance confidence, or a self-computed word-error-rate against the expected phrase). Bucket into `clarity_level`: `full / partial / sounds / none`.

### Vision
*(Open — see [09 — Open Questions](09-open-questions.md).)* Likely a direct question ("can you read this? yes/no") or a shrinking-font-size check until the user can no longer confirm, mapping to `mode: screen | large | none`.

---

## 3.2 Task-to-input mapping (fixed by design, not decided live)

Each task/screen is pre-designed with an **ideal** input type, based on the shape of the interaction — this mapping is static, decided at design time, not inferred live by the agent (a live-LLM-decided version was considered and explicitly rejected as unnecessary build risk for the event):

| Task shape | Ideal input |
|---|---|
| Discrete choice (pick one of N options) | Buttons |
| Continuous/directional (scroll, adjust) | Joystick |
| Free 2D pointing (tap anywhere) | Trackpad |

## 3.3 The fallback rule: calibration sets the ceiling, task sets the preference

> Use the task's ideal input type **if** the user's calibration score for it clears a viability threshold. Otherwise, fall back to the user's next-best scored method — using **that method's own native interaction pattern** for the same task outcome, not a degraded copy of the ideal method's pattern.

This is the key refinement: a fallback isn't "the same widget, just worse." It's a different, appropriate interaction that achieves the same task:

**Discrete selection** (e.g. pick a contact):
- Buttons (ideal): direct tap on the option.
- Joystick (fallback): cycle/highlight through options, press to confirm — like a game menu.
- Trackpad (fallback): drag to hover, release to select.

**Continuous/directional** (e.g. scroll a list):
- Joystick (ideal): push and hold to scroll.
- Buttons (fallback): stepper — "next"/"previous" pair instead of continuous motion.
- Trackpad (fallback): drag gesture to scroll.

**Free pointing** (e.g. tap a spot on a map):
- Trackpad (ideal): drag a cursor, tap to place.
- Joystick (fallback): move a cursor with the stick, click to place.
- Buttons (fallback): coarse-to-fine zone narrowing (pick a quadrant, then a sub-zone, then confirm) — the agent should help narrow this down per §2.4, since it's the most indirect fallback.

## 3.4 Build-scope note

The full picture is a 3-task-shapes × 3-methods matrix (9 interaction implementations). **The locked demo scope ([05 — Locked Scope](05-scope.md)) only needs two of these**: the ideal interaction for whichever method Profile A uses, and the fallback interaction for whichever method Profile B falls back to, for the one task actually demoed. Building the full matrix is roadmap, not event scope — see [12 — Roadmap](12-roadmap.md).
