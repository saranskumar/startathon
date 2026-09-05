# 22. Input Methods Scope — What the System Accepts and Outputs

Reconciles [20 — Meeting Notes: Input Modes](20-meeting-notes-input-modes.md)'s open candidates into a
settled scope statement, the same way [19 — Open Questions Resolved](19-open-questions-resolved.md)
reconciled the tree-simplification/feature-ranking meetings. Cross-referenced against the real build
in [code/app/](../../code/app/) and [code/desktop/](../../code/desktop/) rather than restated as
aspiration — each item below says whether it exists today, not just whether it's planned.

The unifying principle, carried over from the input-scope discussion: **every input method, whatever
its physical form, normalizes to the same small command vocabulary before anything downstream sees
it.** The desktop/DOM side never needs to know whether `NEXT` came from a swipe, a joystick push, or a
tone. This is not a new decision — it's already how [discrete_view.dart](../../code/app/lib/runtime/discrete_view.dart) / [continuous_view.dart](../../code/app/lib/runtime/continuous_view.dart) / [pointing_view.dart](../../code/app/lib/runtime/pointing_view.dart) are built (every `TouchMethod` resolves to the same `onResolve`/`onRaw`
regardless of source) — this doc just states it as an explicit, permanent rule rather than an emergent
property of the current code.

---

## 1. Input methods

### 🎙️ Audio input — two tiers, chosen by calibration, not by the user

Not one audio mode — **which** audio mode a person gets is decided by their measured `SpeechClarity`
(calibration's voice step, [03 — Input & Calibration](03-input-calibration.md)), exactly the same
per-user/per-axis composition principle the rest of the profile already uses:

- **`full` / `partial` → real speech-to-text.** Direct dictation for people who can speak reliably
  (full) or with lower confidence needing per-field confirmation (partial).
- **`sounds` → personalized tone/hum vocabulary, not speech-to-text at all.** For people who can
  vocalize but not produce parseable words. Today this is burst-*count* only (1 sound = yes, 2 = next,
  per [20](20-meeting-notes-input-modes.md)'s "sound-count vocabulary"). Distinct registered
  *tones* mapped to distinct commands (Tone A → Select, Tone B → Cancel, Tone C → Next, Tone D → Back)
  is a richer version of the same tier, not yet built.
- **`none` → voice not offered.** Falls back to touch-only, already the case.

**Status:** the seam is real and already built — [`SpeechSource`](../../code/app/lib/inputs/voice.dart)
is an interface with exactly one stub implementation
(`SimulatedSpeechSource`) swapped in per `SpeechClarity` tier; `canDictate` already gates dictation vs.
sound-count. What's stubbed is the recognizer behind it, not the architecture. **Open decision:** a
real recognizer needs a package (`speech_to_text` or a platform channel) — this build has otherwise
stayed Flutter-SDK-only with zero dependencies beyond `cupertino_icons`
([docs/tech/README.md](../tech/README.md)). Team has not yet decided whether to accept that
dependency; multi-tone mapping (as opposed to burst-count) has no such blocker and can be built
SDK-only.

### 👆 Adaptive touch input

Tap, double-tap, long-press, swipe (4 directions + diagonal), continuous drag/slide, flick, custom
gesture — all operating inside the user's calibrated reachable area
(`CapabilityProfile.reachableRect`), never full-bleed.

**Status:** built. [`TrackpadSurface`](../../code/app/lib/inputs/surfaces.dart) covers drag/slide/tap;
[`JoystickPad`](../../code/app/lib/inputs/surfaces.dart) covers directional/flick-equivalent input.
Custom/pattern gestures (per [20](20-meeting-notes-input-modes.md)'s "pattern swipes") are not built —
still an open candidate, no blocker to building it.

### 🎮 Virtual joystick

Up/down/left/right/center-select inside the accessible area, for navigating extracted UI elements.

**Status:** built as a calibrated input method (`TouchMethod.joystick`), including the per-reachable-cell
swing calibration and reach-anchored placement. What it steers is currently the phone's own task views
(discrete/continuous/pointing); steering a *live desktop page's* DOM via the joystick needs the
desktop-side navigation piece below.

### ⌨️ Limited-area predictive keyboard

Navigate letters/word-predictions via left↔right movement, slide, flick, or a selection gesture,
inside the reachable area; the system offers next-letter/next-word suggestions, autocomplete, space,
backspace.

**Status:** not built. [`text_view.dart`](../../code/app/lib/runtime/text_view.dart) currently offers a
fixed 4-phrase suggestion list, not word-level prediction. A local frequency/n-gram predictor is
SDK-only and does not trigger the same package question audio does — this is **not** an LLM, and
should not be confused with one when scoping it.

---

## 2. Normalized commands

The full vocabulary every input method above collapses into, regardless of physical origin:

```
Navigation:  UP  DOWN  LEFT  RIGHT  NEXT  PREVIOUS
Selection:   SELECT  CONFIRM  YES  NO  CANCEL  BACK
Interaction: CLICK  DOUBLE_CLICK  LONG_PRESS  SCROLL_UP  SCROLL_DOWN
Text:        TYPE_CHARACTER  TYPE_WORD  SPACE  BACKSPACE  ENTER
```

**Status:** the phone side's task views already emit an equivalent ad hoc vocabulary through
`AppState.emit`/`onRaw` (free-text `InputEvent.text`, not yet this fixed enum). The desktop side's
`domTreeEngine.js` features already carry a matching `action` field (`click`/`fill`/`check`/`select`/
`set`, see [code/desktop/README.md](../../code/desktop/README.md)). Formalizing both into this exact
shared vocabulary is what the still-unstarted phone↔desktop transport
([docs/tech/README.md](../tech/README.md)) will need to agree on — this list is that contract's first
draft.

## 3. Feedback to the user

- **Visual** — high-contrast, large controls, focus highlight. Partially built: `VisionMode.textScale`
  scales every control; there is no separate high-contrast theme yet.
- **Audio** — TTS announcing the selected element ("Submit button, selected"), TalkBack compatibility.
  **Not built**, and like real STT, real TTS needs a package (`flutter_tts` or a platform channel) —
  the same open dependency decision as audio input.
- **Haptic** — navigation/selection/error feedback. **Not built, but zero-cost to add**: `HapticFeedback`
  lives in `flutter/services.dart`, part of the Flutter SDK itself, not a package. No reason to defer
  this behind the STT/TTS decision.

## 4. Open decision this doc surfaces

Real speech-to-text and real TTS both need an external package; this build has otherwise stayed
dependency-free by design. Multi-tone audio mapping, custom touch patterns, the predictive keyboard,
haptics, and desktop-side DOM navigation for the joystick all have **no such blocker** and can proceed
regardless of how the STT/TTS question is decided.
