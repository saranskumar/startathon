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

Each tier enables a defined amount of interaction, not just a label:
- `full` / `partial` — used for free-text content per Thesis B (e.g. dictating a message).
- `sounds` — words aren't reliably parseable, but **presence of any vocalization** is still detected and used as a binary confirm/cancel signal (a yes-equivalent), so this tier still gets a real, if minimal, voice interaction rather than being silently dropped.
- `none` — voice is not offered at all.

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

**Item count (large N):** a discrete choice among 50 options doesn't get its own paging/scanning mechanics per method — instead, when N is large, the agent first uses voice/text to **filter down to a small N** (e.g. "say part of the name"), then the normal small-N pattern (buttons / joystick-cycle / trackpad-hover) applies for the final selection. This reuses the existing per-method patterns instead of inventing large-list variants of each, and it's a natural extension of the agent's existing inference role (§2.4) rather than new UI surface.

## 3.3 The fallback rule: calibration sets the ceiling, task sets the preference

> Use the task's ideal input type **unless a different method scores meaningfully higher for this user**. Otherwise, fall back to the user's best-scoring method — using **that method's own native interaction pattern** for the same task outcome, not a degraded copy of the ideal method's pattern.

This is a relative comparison, not a fixed cutoff: there's no single "viability threshold" number to tune, and it doesn't break for a user whose best score is mediocre across the board (an absolute threshold would call everything non-viable for them; a relative one still picks their genuine best).

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

## 3.5 The floor case: someone who scores low on every touch method

If a user scores low on buttons, joystick, *and* trackpad alike (and has no/unusable speech), none of the fallback patterns in §3.3 apply — every one of them still assumes *some* residual motor precision. This is exactly the person the pitch claims to serve, so it's worth having a real answer even though it isn't demoed.

**The answer, not built:** a fourth, most-degraded input method — **single-switch scanning**. One always-reachable trigger (a large zone, or even a single physical/virtual button); the system auto-highlights options on a timer, and the user presses whenever the right one is highlighted. This is the same technique existing switch-access tools already use ([01 — Problem](01-problem.md)) — the point isn't to reinvent it, it's that it becomes *one more composable method inside this system* rather than a separate tool the user has to stitch in themselves. It would need its own calibration test (can the user reliably time a single press against a moving highlight?) and its own fallback interaction pattern per task shape, same shape as §3.3.

Explicitly **not built or demoed** for this event — this is a prepared answer for if a judge asks "what about someone who can't use any of your three methods," not a build target. See [12 — Roadmap](12-roadmap.md).
