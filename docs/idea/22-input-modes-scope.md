# 22. Input Modes — Scope and Status

Settles [20-meeting-notes-input-modes.md](20-meeting-notes-input-modes.md)'s "candidate additions, not yet decided or built" into an actual current list: every input mode in scope, what it's for, and whether it exists in the codebase today. Doc 20 stays as the historical record of the meeting that raised these; this doc is the thing to check for current status, and should be updated (not doc 20) as items move from proposed to built.

Cross-checked directly against `code/app/lib/` — every "Built" row names the file/class that proves it, not just a design intention.

---

## 1. Voice / audio input modes

| Mode | What it is | Status |
|---|---|---|
| **Clear speech (speech-to-text)** | Real dictation, for users who can speak reliably | Architecture exists — `SpeechSource` interface in [inputs/voice.dart](../../code/app/lib/inputs/voice.dart), selected via `SpeechClarity.full`/`partial` (`canDictate`). **Stubbed**: `SimulatedSpeechSource` stands in for a real recognizer. |
| **Sound-count vocabulary** | 1 burst = yes/select, 2 bursts = next/no | **Built** — `SpeechClarity.sounds` tier, `VocalClassifier` in [inputs/voice_modes.dart](../../code/app/lib/inputs/voice_modes.dart). |
| **Hold-to-speak gesture** | Press-and-hold to capture an utterance, release to stop | **Built** — `HoldToSpeak` widget, used in calibration (`VoiceStep`), the input preview screen, and text entry. |
| **Personalized tone/pattern mapping** | Distinct hum/tone A/B/C/D → distinct commands, not just burst count | **Not built.** The current `sounds` tier only counts bursts; it doesn't distinguish which *sound* was made. |
| **Grid-based voice input** | Speak a region number/label to jump there | **Not built.** Proposed in doc 20 §"Voice input modes"; cites Android Voice Access's shipped "show grid" overlay as existing precedent (see [tech/research/10-additional-input-modes.md](../tech/research/10-additional-input-modes.md) §3). |
| **Context-predictive text (voice-driven)** | Predict the likely phrase, confirm with a minimal signal instead of full dictation | Partially built — `TextTaskView` ([runtime/text_view.dart](../../code/app/lib/runtime/text_view.dart)) offers a fixed 4-phrase list, confirmed via touch or voice. Not real prediction (see §3 below). |

## 2. Touch input modes

| Mode | What it is | Status |
|---|---|---|
| **Direct tap** | Tap a button/target directly | **Built** — `CalibratedButton`, `OptionList` in [inputs/surfaces.dart](../../code/app/lib/inputs/surfaces.dart) / [runtime/dock.dart](../../code/app/lib/runtime/dock.dart). |
| **Touch-and-hold** | Press and hold still for a duration | **Built** — `HoldStep` calibration test; produces `holdCapable` and `steadiness` on the profile. |
| **Swipe / drag (2D)** | Continuous absolute-position drag | **Built** — `TrackpadSurface`. |
| **Axis-limited swipe** | X-only or Y-only, when one axis is unreliable | **Built** — `TrackpadStep` measures per-axis error separately and sets `axisLock`. |
| **Virtual joystick** | Up/down/left/right + center-press-to-select, floating at a reachable point | **Built** — `JoystickPad`; all 8 directions calibrated via the per-cell swing test (`JoystickStep`), anchored at `joystickAnchor`. |
| **Single-switch scanning** | One large always-reachable target; system auto-cycles, user presses to select | **Built** — `SwitchTrigger`, `TouchMethod.switchScan`. |
| **Double tap / long press (as a distinct secondary gesture)** | Discrete secondary actions beyond a plain tap | **Not built.** No calibration step or handler distinguishes these from a single tap. |
| **Flick** | Short discrete directional swipe, distinct from a continuous drag | **Not built.** Doc 20 explicitly separates this from full trackpad dragging; no separate primitive exists yet. |
| **Pattern swipes / custom gestures** | Multi-step sequences (e.g. left-then-up) as an expanded vocabulary | **Not built.** Proposed in doc 20 for users who can produce a few distinguishable gestures but can't reach many discrete buttons. |
| **Limited-area predictive keyboard** | Type via left/right navigation + next-letter/word prediction, confined to the user's reachable strip | **Not built.** The one clear phone-side gap identified when this scope was reviewed — see §3. |

## 3. Explicitly deferred, and why

- **Real speech-to-text and real TTS** both require a Flutter plugin (`speech_to_text`, `flutter_tts`, or a platform channel) — there is no SDK-only path to a live microphone transcript or synthesized voice. This breaks the "Flutter SDK only, no packages" constraint the build has followed so far ([docs/tech/README.md](../tech/README.md), [code/app/README.md](../../code/app/README.md)). Whether to accept that dependency is an open decision, not yet made.
- **Haptic feedback** (`HapticFeedback` from `flutter/services.dart`) needs no package — it's part of the Flutter SDK already in use. Flagged as free, in-scope work with no reason it isn't built yet.
- **Predictive text/keyboard** does not require an LLM or any package: a local word-frequency/n-gram predictor (the same kind of thing a phone's stock keyboard uses) is fully deterministic and offline. Keep this distinction explicit — "no LLM" (a hard project constraint, see below) is not the same claim as "no prediction at all."

## 4. Standing constraint this scope must respect

No LLM, no AI ranking, anywhere in the desktop-side element extraction, navigation, or command-mapping path — confirmed as a deliberate project decision, not just a cost-saving default: the system should be fully deterministic, free to host, offline-capable, and easy to self-host. This is already how [code/desktop/src/domTreeEngine.js](../../code/desktop/src/domTreeEngine.js) is built (heuristic scoring, no LLM in the path) and should hold for any navigation-graph or command-mapping work built on top of it. Word/letter prediction for the keyboard is the one place "prediction" is wanted despite this — resolved above as a local frequency-based predictor, not an LLM call.

## 5. How this connects to the rest of the docs

- Supersedes [20-meeting-notes-input-modes.md](20-meeting-notes-input-modes.md)'s status as "candidate, not decided" — every item there now has a concrete built/not-built answer above.
- The "no LLM in the desktop path" constraint in §4 sharpens [19-open-questions-resolved.md](19-open-questions-resolved.md) §1's tier-1/tier-2 split: tier 2 (the narrow LLM fallback for genuinely ambiguous trees) is still on the table for the *ranking* problem specifically, but does not extend to navigation, command-mapping, or prediction — those stay deterministic per this doc.
- The deterministic spatial navigation graph (UP/DOWN/LEFT/RIGHT/NEXT/BACK as nearest-neighbor-by-position over extracted elements) and the predictive keyboard are the two concrete next builds this doc identifies; neither is scheduled yet.
