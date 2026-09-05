# Phone app — input layer

The phone side of [docs/idea/07-architecture.md](../../docs/idea/07-architecture.md), and only that side: **calibration produces a capability profile, and the profile decides how every task is operated.** Nothing here talks to an agent, a browser or a laptop. Every resolved intent is written to an on-screen output strip instead of onto a wire, so the input half can be built and judged on its own.

Flutter SDK only — no third-party packages, so `flutter run` works offline.

## Run it

```bash
flutter run -d chrome     # or: flutter run  (any attached device)
flutter test              # 32 tests: scoring, the fallback rule, every input pattern
flutter test --update-goldens test/golden_screens_test.dart   # regenerate test/goldens/*.png
```

`test/goldens/` holds a rendered screenshot of every screen — the quickest way to see the whole app without a device.

## What is implemented

**Calibration (7 steps, ~2 min)** — reachable zone, buttons, joystick, trackpad, touch-and-hold, voice, vision. Each produces real measurements: success rate, time-to-target and error, combined with the formula in [03 §3.1](../../docs/idea/03-input-calibration.md) into one score per method. Results screen shows the score table, the derived profile, and which method each task shape will use.

**After calibration** — a controller playground comes first: every input surface (buttons, joystick, trackpad, switch, voice) can be tried, and the laptop-preview strip is pinned to the top so live signals and intents are visible before any task starts. Tasks still mount only the method they need; the playground is how you see the rest.

**Runtime (4 tasks)** — discrete choice, continuous adjust, free pointing, and free text. Each task has a fixed ideal input method; the [§3.3 fallback rule](../../docs/idea/03-input-calibration.md) swaps in the user's best method when it scores meaningfully higher, using that method's own native interaction pattern.

The full 3 × 4 matrix is built, not just the two the demo needs:

| | Buttons | Joystick | Trackpad | Switch scan |
|---|---|---|---|---|
| **Discrete** | tap *(ideal)* | cycle + press | hover + release | auto-scan + press |
| **Continuous** | stepper | push and hold *(ideal)* | drag to scrub | scan direction, press to run |
| **Pointing** | quadrant narrowing | steer cursor + press | drag + release *(ideal)* | row scan, then column scan |

**Voice** is fused with touch on the text task (Thesis B): touch selects, voice supplies content — dictation with a confirmation gate at `full`/`partial`, and a one-sound-yes / two-sounds-next vocabulary at `sounds`.

**Single-switch scanning** is implemented as a fourth method, though [03 §3.5](../../docs/idea/03-input-calibration.md) lists it as not built — once the other three shared a task interface it was cheap, and it is what makes the floor case demoable.

## Deliberate design decisions

- **Output goes where input cannot.** Calibration finds the grid row the user reaches least, and the output strip is placed there — top for someone who works low on the screen, bottom for someone who works high. Dead space for input is the honest place to spend on output.
- **The joystick floats, everything else docks.** A translucent overlay anchored to the middle of the reachable zone, because a docked stick sits where the layout wants it rather than where the hand rests.
- **No calibration step can trap anyone.** Every test has a full-width skip, every test gives up on its own after a few seconds, and if nothing registers at all for 20 seconds three times running, the flow jumps to the end with the most forgiving setup. Someone who can operate none of the methods still finishes calibration — with a low-score profile, which is a real answer rather than an error.
- **Reach is measured once and reused.** The button test is placed inside the zone the user already reached, so precision is not scored down by a target they simply could not get to.
- **Vision is a forced choice, not a self-report.** The stimulus word shrinks while the two answer buttons stay large: getting it right is proof of reading it, and the answer buttons never become the limiting factor.
- **The confirmation gate uses the user's own method.** A gate rendered as a small dialog button would demand an ability the user was never measured to have.
- **Interrupt is always on screen** as a full-width bar, per [05 §6](../../docs/idea/05-scope.md).

## What is simulated, and where to swap it

**Speech recognition.** There is no microphone plugin (no packages, and [docs/tech](../../docs/tech/README.md) has not chosen an API yet). The *interaction* is real — press-and-hold timing, separate-sound counting, the clarity tiers, the confirmation gate — and only the recogniser is stubbed, behind one interface:

```
lib/inputs/voice.dart -> abstract class SpeechSource
                         SimulatedSpeechSource   <- replace this
```

The voice calibration step shows a `SIMULATED RECOGNISER` panel where the returned quality is picked explicitly. That is also useful on stage: any tier can be demoed on demand instead of hoping the room's acoustics cooperate.

**Everything downstream of the phone.** Intents stop at the output strip; the agent, the browser tree and the real form are not part of this build.

## Layout

```
lib/
  model/profile.dart      the capability profile: scores, reach, axes, derived rules
  model/session.dart      app state, event log, trial scoring, the demo presets
  inputs/surfaces.dart    raw surfaces: joystick, trackpad, switch trigger, button
  inputs/voice.dart       SpeechSource + hold-to-speak
  calibration/            the 7 steps, the flow that sequences them, the results screen
  runtime/task_spec.dart  task shapes, the static ideal mapping, the fallback rule
  runtime/*_view.dart     one file per task shape, all four methods inside each
  runtime/preview_screen.dart  controllers + top laptop-preview after calibration
  runtime/output_bar.dart the output strip and the full log sheet
```
