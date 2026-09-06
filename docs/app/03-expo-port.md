# 03 — Expo port map

Rebuild the phone input layer as an Expo (React Native) app that implements [01](01-feature-inventory.md) using the architecture in [02](02-adaptation-vs-screens.md). Flutter stays the behavioural spec until Expo reaches parity on the hard constraints.

Suggested location: `code/app-expo/` (sibling to `code/app/`), so the Dart app can keep running for goldens/demos during the port.

---

## 1. What to copy as logic (no UI)

Port these as pure TypeScript first. They have almost no Flutter in them.

| Dart | Expo |
|---|---|
| `model/profile.dart` | `src/model/profile.ts` — enums, `MethodScore`, `CapabilityProfile`, `reachableRect`, `outputRow`, `maxControls`, `chooseMethod` consumers |
| `model/session.dart` | `src/model/session.ts` — `InputEvent`, `TrialCollector`, `ProfilePresets` |
| `runtime/task_spec.dart` | `src/runtime/taskSpec.ts` — shapes, demo tasks, `chooseMethod`, `patternFor` |
| `inputs/voice_modes.dart` | `src/inputs/voiceModes.ts` |
| `inputs/voice_vocab.dart` | `src/inputs/voiceVocab.ts` |
| `theme/haiku_theme.dart` (compute only) | `src/theme/haiku.ts` |
| `theme/contrast_theme.dart` | `src/theme/contrast.ts` |
| `runtime/hold_repeater.dart` | `src/inputs/holdRepeater.ts` |
| `inputs/marker_grid.dart` (tree + controller) | `src/inputs/markerGrid.ts` |

Keep the scoring formula, fallback margin `0.12`, vocal thresholds (120 / 280 / 400 / 800 ms), and dwell formula identical so presets Trackpad/switch / A / B / Floor look the same.

---

## 2. What to rebuild as views

| Dart | Expo (one component, profile as props) |
|---|---|
| `JoystickPad` | Reanimated + pan gesture; normalised vector |
| `TrackpadSurface` | Pan + optional axis lock |
| `SwitchTrigger` / `CalibratedButton` | Pressable, `minHeight` from profile |
| `HoldToSpeak` | Press in/out + settle timer |
| `VisualFieldShell` | Overlay `View` with hole; `pointerEvents="none"` on the veil |
| `InputOverlay` | Absolute stick vs docked rest |
| `OutputStrip` + log sheet | Same placement rule (`outputAtBottom`) |
| `StepFrame` | Shared calibration chrome |
| Calibration steps | Same sequence, same skip/idle |
| `CaregiverTraining` | Same three drills / three phases |
| `InputPreviewScreen` | All surfaces tryable |
| Task drivers | Discrete / continuous / pointing / text **drivers**, not 16 screens |
| `SpeechSource` | Interface + simulated impl first; later `expo-speech` / cloud STT |

---

## 3. Suggested Expo tree

```
code/app-expo/
  app/                         # Expo Router
    index.tsx                  # Setup
    measure.tsx                # axis picker + steps + results
    preview.tsx
    tasks.tsx
  src/
    model/                     # profile, session, presets  (pure)
    runtime/                   # taskSpec, drivers, shell
    inputs/                    # surfaces, voice, haptics
    calibration/               # draft, steps, results
    theme/                     # haiku, contrast
    vision/                    # field shell
    training/
    onboarding/
  test/                        # vitest: scoring, fallback, vocal classifier
```

Three routes after launch is enough. Do not create a route per profile.

---

## 4. Packages Expo may add (Flutter deliberately did not)

Add only when a feature is blocked without them:

| Need | Candidate | Notes |
|---|---|---|
| Gestures / motion | `react-native-gesture-handler`, `react-native-reanimated` | Stick, pad, hold |
| Haptics | `expo-haptics` | Same three meanings: navigate / confirm / error |
| Speech | stub first; then `expo-speech` or a chosen STT | Keep `SpeechSource` as the only call site |
| Audio clips | `expo-av` | Swap the transcript stand-in for WAVs |
| A11y | React Native `AccessibilityInfo` + `accessibilityRole` | Recorded narration already announces |

Do not add a navigation or state library until the three-screen flow needs it. Context + a tiny machine (setup / preview / tasks) matches Flutter’s `_Screen` enum.

---

## 5. Parity checklist (Expo is not done until these pass)

Behavioural, not pixel-perfect:

- [ ] Setup is tap/hold anywhere; helper button simultaneous
- [ ] Every calibration step skippable; idle 20s; three idles → end
- [ ] Live draft reshapes the next step
- [ ] Score formula + fallback margin match Dart tests
- [ ] Full 3×4 matrix + text fusion
- [ ] Output strip on unreachable row
- [ ] Joystick floats at home cell; other surfaces dock in reach
- [ ] Confirmation uses the user’s method
- [ ] Interrupt resets current step only
- [ ] Field veil does not eat pointers
- [ ] High contrast peer theme
- [ ] Presets Trackpad/switch / A / B / Floor visibly reshape
- [ ] `sounds` tier: 1 pulse = yes, 2 = next
- [ ] Locale catalog `en` / `ml`
- [ ] No agent wire required (strip is the sink)

Port the Dart unit tests (`test/*_test.dart`) to Vitest for the pure TS layer before polishing UI.

---

## 6. Build order

1. Pure TS model + tests (profile, scoring, fallback, vocal classifier, vocab).
2. Surfaces in a playground screen (the current Preview, plus the planned gear-menu Playground in [04](04-clarity-playground-and-field.md)).
3. Calibration flow + results.
4. Task shell + four drivers.
5. Training, contrast, field, locale.
6. Swap simulated speech when an API is chosen (`docs/tech` still undecided).

Do not start from a visual redesign. Start from the profile object. The UI is a function of that object.
