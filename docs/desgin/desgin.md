# Voice and text input modes

Plan for how the Flutter phone app classifies **voice** and **text**, including users who cannot produce words — only nods, sounds, and hums.

This is a *classification inside the app*, not a new disability label. Calibration still buckets speech into `full / partial / sounds / none`. This doc says what each bucket is allowed to do, and how a single microphone capture is typed so the text task can act on it.

Code: `code/app/lib/inputs/voice_modes.dart`. Runtime: `code/app/lib/runtime/text_view.dart`.

---

## 1. Two layers (do not mix them)

| Layer | Question | Lives in |
|---|---|---|
| **Clarity** (who this user is) | Can they produce words at all? | `SpeechClarity` on the profile — set in calibration |
| **Vocal event** (what just happened) | Was that a nod, a sound, a hum, a burst, or speech? | `VocalKind` — classified from hold time + burst count |
| **Text compose mode** (how the field is filled) | Dictate, confirm suggestions by voice, or pick by touch? | `TextComposeMode` — derived from clarity |

Clarity is calibrated once. Every utterance is classified again. Compose mode does not change mid-sentence unless they re-run calibration.

---

## 2. Text compose modes

| Mode | When | How the field gets content |
|---|---|---|
| **Dictate** | `full` or `partial` | Hold to speak → transcript → confirm (partial always confirms; full confirms if confidence is low) |
| **Vocal confirm** | `sounds` | App/agent proposes phrases. Voice never has to be a word. |
| **Touch pick** | `none` | Same proposals, chosen with the calibrated touch method |

Thesis B stays: touch selects the field, voice (if any) supplies or confirms content.

---

## 3. Vocal events for the `sounds` tier

The mic is not asked for words. The UI already measures **how long** the control was held and **how many separate presses** happened in one settle window (`HoldToSpeak`). Classification is only that:

| Kind | Signal | Meaning in text task |
|---|---|---|
| **Nod** | One short burst (under ~280 ms) | Yes / accept current suggestion |
| **Sound** | One medium burst | Yes / accept (same as nod; slightly longer “ok”) |
| **Hum** | One long hold (~800 ms or more), still a single press | Yes / accept — sustained confirm (dwell) |
| **Burst** | Two or more separate sounds in the window | Next suggestion (no / skip) |
| **Speech** | Clarity is `full`/`partial` | Send to recogniser (stub or real `SpeechSource`) |
| **Silence** | Too short / nothing | Ignore, retry |

Nods here are **not** camera head-tracking. They are the smallest yes-equivalent vocal (or switch-like) pulse. Head-nod as a separate sensor is roadmap; the *meaning* (one short yes) is what we implement now.

Hums are **duration**, not pitch. We do not need a pitch detector for the demo: a long single hold is a hum.

---

## 4. Implementation order

1. **Classifier** (`VocalClassifier.classify`) — pure function, unit-tested. **Done in this pass.**
2. **Text task** uses the classifier for `sounds` instead of raw `sounds == 1 / >= 2`. **Done in this pass.**
3. **Results screen** shows the voice/text plan for this profile. **Done in this pass.**
4. Later: real VAD/burst counting behind `SpeechSource` (research 02 / 10). The classifier stays; only how `heldMs` / `soundCount` are measured changes.
5. Later: optional camera nod as another producer of `VocalKind.nod`.

---

## 5. What we are not doing yet

- Pitch / melody / several hum notes as a vocabulary
- Grid-spoken numbers (Android Voice Access pattern — research 10)
- Replacing Google Form submit with voice (that is the agent, not this screen)
