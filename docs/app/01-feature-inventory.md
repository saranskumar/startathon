# 01 — Flutter phone app: feature inventory

Source of truth for *what is built*: [`code/app/lib/`](../../code/app/lib/). This is the input layer only. Nothing talks to an agent, a browser, or a laptop. Resolved intents land on an on-screen output strip.

Flutter SDK only — no third-party packages. Speech recognition is stubbed behind `SpeechSource`.

---

## 1. What the app is for

A person (or helper) is **measured**, not labeled. Measurement produces a `CapabilityProfile`. That object decides:

- which touch method each task uses (ideal vs fallback)
- how big targets are, how many show at once, where they sit
- whether voice dictates, confirms by sound, or is off
- how large text is, and how much of the screen is visible
- where output lives (the row the hand cannot reach)

The demo then walks four task shapes so a judge can see the same “form” operated three different ways (presets A / B / Floor).

---

## 2. Locked session flow

Do not reorder. From [ui-ux-phone-flow.md](../desgin/ui-ux-phone-flow.md) and `lib/main.dart` + `calibration/calibration_flow.dart`:

```
open
  ├─ no confirmed profile → Start gate (full-bleed tap/hold)
  └─ confirmed this session → Preview (“Your controllers”)

Start gate → Setup
Setup
  ├─ tap/hold the start block → Continue → axis picker
  ├─ “Someone is helping” → caregiver training → axis picker
  └─ settings circle → presets / contrast / locale / redo / helper

Axis picker → gated tests (only chosen axes) → Results
  ├─ Redo → axis picker
  └─ Use this setup → Preview

Preview
  ├─ try every surface, Simpler / Level up
  ├─ Start tasks → task chain
  └─ recalibrate / settings → Setup

Tasks (fixed order)
  1 Pick a plan     (discrete)
  2 Set seat count  (continuous)
  3 Mark a spot     (pointing)
  4 Add a note      (text, fused)
  5 Review          (confirm send with the same method)
  6 Sent            (run again / recalibrate)

Interrupt resets the current step only, never the profile.
Killing the app returns to the Start gate (in-session only; no persistence).
```

---

## 3. Screens

| Screen | Code | Essential job |
|---|---|---|
| **Start gate** | `main.dart` `_StartGateScreen` | Full-bleed tap/hold, nothing else. Continues to Setup. |
| **Setup** | `main.dart` `_HomeScreen` | Helper / contrast / locale up top. Welcome autoplays. Reach zone is only the tap/hold-to-start block. Settings circle top-right. |
| **Continue** | `calibration_flow.dart` `_entry` | Slim “We'll measure what works.” + large Continue. No second welcome, no helper question. |
| **Settings sheet** | `main.dart` `_DemoSettingsSheet` | High contrast, locale chip, presets A/B/Floor, Redo setup, helper path. Presets skip measurement and jump to Preview. |
| **Caregiver training** | `training/caregiver_training.dart` | No scores. Three motions (tap, slide left, slide up). Prompt fading: together → start-together-finish-alone → from the words alone. Three independent hits graduate a drill. Skip this motion / skip all → axis picker. |
| **Axis picker** | `calibration_flow.dart` `_axisPicker` | Motor / Speech / Vision default ON as large rows. Hold a row to skip it; tap an off row to turn it back on. Start always enabled. Last remaining axis cannot be skipped. Haiku theme reacts live. Helper provenance banner if assisted. |
| **Calibration steps** | `touch_steps.dart`, `sense_steps.dart` | See §5. Shared `StepFrame`: instruction, `N of M`, always-present Skip (untested ≠ fail), Back from the second test (retake as untested). |
| **Results** | `calibration/results.dart` | Four sections: Overview, Methods, Voice & text, Tasks. Redo / Use this setup. Already uses measured size, scale, field. |
| **Preview** | `runtime/preview_screen.dart` | Output strip pinned top. Chips for Buttons / Joystick / Trackpad / Switch / Voice (best marked “yours”). Try pad. Simpler / Level up. Start tasks. |
| **Task runtime** | `runtime/demo_screen.dart` + `*_view.dart` | Ribbon (prompt + why this method), task body + dock/overlay, interrupt bar. |
| **Review / Sent** | `demo_screen.dart` | Consequential “Send it” gated; Go back; Run it again. |
| **Event log** | `runtime/output_bar.dart` | Sheet from tapping the output strip. Last 200 events + live RAW. |

Visual field veil (`vision/field_shell.dart`) wraps **everything after** vision commits, including results. Start gate and Setup stay full-field. Mask is `IgnorePointer` so aiming is not stolen.

---

## 4. Capability profile (the object everything runs off)

`lib/model/profile.dart` — `CapabilityProfile`.

### Touch

| Field | What it does at runtime |
|---|---|
| `methodScores` | Per method: success rate, time_norm, error_norm → `score = 0.5·success + 0.3·(1−time) + 0.2·(1−error)` |
| `bestMethod` | Highest score (relative, never an absolute cutoff) |
| `reachableCells` | 3×4 grid indices that registered |
| `reachableRect` / `reachAnchor` | Where docks sit; fallback = lower half |
| `outputRow` / `outputAtBottom` | Output strip on the least-reachable row, furthest from the hand centroid |
| `joystickHomeCell` / `joystickAnchor` | Floating stick home |
| `minTargetSize` | Button / skip / chrome height |
| `steadiness` | Stretch switch-scan dwell; tremor tolerance |
| `holdCapable` | Whether hold-to-repeat is offered |
| `maxControls` | From best score: ≥0.75 → 6, ≥0.55 → 4, ≥0.35 → 3, else 2 |
| `inputLevel` | `one` / `two` / `many` — caps visible options; user levels up from one |
| `visibleOptionCount` | `min(level cap, maxControls)` |

Methods: `buttons`, `joystick`, `trackpad`, `switchScan`.

### Speech

| Field | Runtime |
|---|---|
| `clarity` | `full` / `partial` / `sounds` / `none` |
| `vocabulary` | Words that landed in sentence probes |
| `usesWordVocab` | Partial + non-empty vocab → map words onto menus |

Compose modes (`inputs/voice_modes.dart`): dictate / vocal-confirm / touch-pick.

### Vision / display

| Field | Runtime |
|---|---|
| `vision` | `screen` (1.0×) / `large` (1.45×) / `none` (1.6×) text scale |
| `visualField` | `full` / `tunnel` (condensed output window) / `peripheral` (center veiled) |
| `locale` | `en` / `ml` — recorded clips only |
| `haikuTheme` | Decorative blend of motor/speech/vision seeds — **not** a diagnosis |
| `highContrast` | Peer palette (black / white / yellow), WCAG 4.5:1 text / 3:1 chrome |

### Provenance (draft only, then baked into the profile)

Axes measured (`measureMotor` / `measureSpeech` / `measureVision`), `helperChoseAxes`, skipped-step set, trackpad `axisLock` (X-only / Y-only / both).

---

## 5. Calibration

Gated by axes. Order when all on: **reach → buttons → joystick → trackpad → hold → voice → vision**.

Shared rules (`calibration_flow.dart`):

- Skip = untested, never fail.
- Idle 20s auto-skips the step. Three consecutive idle skips jump to results with the most forgiving leftover setup.
- After each step, `draft.build()` is pushed live so the next screen is already sized/themed.
- Reach is measured once and reused to place later motor tests.

### 5.1 Reach

3×4 grid. Tap cells that work. Builds `reachableCells`. Output row is the inverse.

### 5.2 Buttons

Large targets **inside the reachable zone**, size from this test. Scores success / time / error. Writes `minTargetSize`.

### 5.3 Joystick

Per reachable cell, swing through octants. Home cell = steadiest (need ~6 of 8). Writes `joystickHomeCell` + joystick method score.

### 5.4 Trackpad

Drag to a zone. If one axis is markedly worse, set `axisLock` so later pads discard that axis.

### 5.5 Hold

Press-and-hold target. Writes `holdCapable`.

### 5.6 Voice

Eight sentence probes (`inputs/voice_vocab.dart`). Spoken line is the sentence; only the **target word** is scored into vocabulary. User marks “that word was clear” / “not this one”. Simulated recogniser quality chips on stage.

Buckets: ≥6 words landed → `full`; some → `partial` + vocab; sounds heard → `sounds`; else `none`.

### 5.7 Vision

Forced choice, not self-report: stimulus word **shrinks** from a session-shuffled pool of common 2-syllable nouns; answer buttons stay large. Then field: full / tunnel / peripheral.

### 5.8 Results report

- **Overview** — axes, helper provenance, haiku card (emotion / value / three-line blessing).
- **Methods** — score table, reach count, stick home, target size, steadiness, hold, voice, vision+field, input level, personal words.
- **Voice & text** — compose-mode plan; skipped list; axis lock.
- **Tasks** — for each demo shape: chosen method, ideal vs fallback reason, native pattern one-liner.

---

## 6. Input primitives (know nothing about tasks)

`lib/inputs/surfaces.dart` and friends. Task views compose these.

| Primitive | Emits | Placement |
|---|---|---|
| `CalibratedButton` | tap | dock; height from `minTargetSize` |
| `JoystickPad` | normalised vector −1..1, press, release | **floats** at `joystickAnchor` |
| `TrackpadSurface` | normalised point 0..1, delta, optional `axisLock` | dock |
| `SwitchTrigger` | press (no aiming) | dock, very tall |
| `HoldToSpeak` | `(soundCount, heldMs)` after settle (~900 ms gap) | dock |
| `HoldRepeater` | fire, pause, then repeat | used by joystick + switch |
| `MarkerGrid` | recursive 5-cell tree (`ceil(log5 n)` picks) | cells vs mic can split (content vs dock) |

Haptics (`inputs/haptics.dart`): navigate (light), confirm (medium), error (heavy). Named by meaning.

Layout shell (`runtime/dock.dart` `InputOverlay`): content fills; dock sits in the reachable horizontal span; joystick overlays.

---

## 7. Task runtime

### 7.1 Fallback rule (`runtime/task_spec.dart`)

Static ideal (design time, not an LLM):

| Task shape | Ideal method |
|---|---|
| Discrete | Buttons |
| Continuous | Joystick |
| Pointing | Trackpad |
| Text | Buttons (selection); voice supplies content |

Rule: use ideal **unless** another method scores ≥ **0.12** higher. Then use the user’s best method with **that method’s native pattern**.

### 7.2 Interaction matrix (built, not just demoed)

| | Buttons | Joystick | Trackpad | Switch scan |
|---|---|---|---|---|
| **Discrete** | tap option | cycle + press | hover + release | auto-scan + press (row/col grid when N is large) |
| **Continuous** | stepper | push and hold *(ideal)* | drag to scrub | scan direction, press to run |
| **Pointing** | quadrant narrowing | steer cursor + press | drag + release *(ideal)* | row scan, then column scan |
| **Text** | Thesis B: touch selects field; voice fills/confirms | same fusion | same | same |

Discrete options are **paged** by `visibleOptionCount`. Vocab (when `usesWordVocab`): small menus map words onto options; large menus map first three words to next / previous / select.

### 7.3 Demo tasks

Mirror the mock site closely enough to show patterns; no agent wire.

1. Pick a plan — 6 options (Starter … Custom)
2. Set seat count — 1–50
3. Mark a spot — goal at ~`(0.72, 0.34)`; agent-assist copy only when not trackpad
4. Add a note — fused text
5. Review — “About to send…” Send it / Go back via **same** method
6. Sent

### 7.4 Text / voice fusion (Thesis B)

`runtime/text_view.dart` + `VocalClassifier`:

| Clarity | How content is filled |
|---|---|
| `full` / `partial` | Hold to speak → transcript → confirm (partial always; full if confidence low) |
| `sounds` | nod / sound / hum = yes; two+ sounds = next phrase |
| `none` | pick a suggested phrase with the calibrated touch method |

Vocal events (sounds tier): nod &lt; ~280 ms; hum ≥ ~800 ms single hold; burst = 2+ presses in the settle window. Not camera head-tracking. Not pitch.

Confirmation gate uses the **user’s method**, never a tiny dialog button they were never measured for.

---

## 8. Output, theme, onboarding

| Feature | Detail |
|---|---|
| Output strip | Last INTENT + live RAW. Top or bottom from reach. Tap → log. Stands in for the laptop wire. |
| Interrupt bar | Full width on every task. Resets current step (`_epoch++`). |
| Haiku theme | Blend of yellow (motor) / blue (speech) / pink (vision), weighted by scores. Motif is decorative. |
| High contrast | Peer theme, not a haiku variant. Also follows OS `MediaQuery.highContrast`. |
| Recorded voice | Catalog `welcome` / `training` in `en` and `ml`. Timed transcript + screen-reader announcement until WAVs exist. |
| Live draft | Partial profile applied mid-calibration. |
| Presets | A (precise + full speech), B (imprecise + partial + vocab `water/tank/yellow`), Floor (switch + sounds + tunnel). |

---

## 9. Simulated vs real

| Piece | Status |
|---|---|
| Calibration scoring, skip, idle, live draft | Real |
| All input surfaces and the 4×4(+text) matrix | Real |
| Fallback rule, paging, level-up | Real |
| Visual field mask, contrast, haiku | Real |
| Speech **interaction** (hold timing, burst count, gate) | Real |
| Speech **recogniser** | Stub: `SimulatedSpeechSource`. Swap by implementing `SpeechSource`. Voice step has a SIMULATED RECOGNISER panel so any tier can be demoed on stage. |
| WAV onboarding | Catalog only |
| Profile persistence | None — session only |
| Agent / browser / laptop | Not in this app. Seam is `AppState.emit` in `model/session.dart`. |
| Camera nod, sip-and-puff, gaze, EMG, BCI | Research / roadmap, not built |
| Real TTS narration for vision=`none` | Not built (FR5 partially: large text + field, not proactive audio) |

---

## 10. Hard constraints (must survive an Expo rewrite)

From the wireframe spec and FR table:

1. First action is never harder than tap/hold anywhere.
2. Helper path is visible at the same time as that tap, not a second screen to discover.
3. Every calibration step is skippable; skip = untested.
4. No consequential send without explicit confirm (FR7).
5. Interrupt resets the current step, not the profile (FR8).
6. Field mask never steals hits.
7. High contrast is a peer to haiku (4.5:1 / 3:1).
8. Profile switch visibly reshapes the interface (the demo’s proof).
9. Touch + voice fused at least once on a partial profile (Thesis B).
10. Task-to-ideal mapping is fixed at design time, not decided live by an LLM (FR17).

---

## 11. Out of this phone app (other surfaces)

- Desktop ranking / inspector (`code/desktop/`)
- Aperture Daily mock sites (`code/mock/`)
- Agent filling a real form
- Native OS accessibility APIs

Those stay separate. The Expo app replaces **this** input layer, not the whole product.
