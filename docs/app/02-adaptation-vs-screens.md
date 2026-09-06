# 02 — Adaptation is not a screen gallery

**Question:** If the app must adapt to users, do we have to design each and every interface in Flutter?

**Answer:** No. That is the wrong unit of design. Flutter (or Expo) is just the renderer. Adaptation lives in a **profile + primitives + mapping**. Designing every combination as its own screen is what made the Flutter app brittle.

---

## 1. Two different meanings of “design everything”

| Meaning | Required? | What you actually draw |
|---|---|---|
| **Every user gets a unique mockup** | No — combinatorial explosion | Screen for A, B, Floor, tunnel, Malayalam, one-target, six-targets… |
| **Every lever that can change is designed once as a parameter or primitive** | Yes | Surfaces, layout knobs, fallback patterns, confirmation, interrupt |

The product thesis is Thesis A: people sit on **continuous axes**, not in labeled buckets. Continuous axes cannot be served by a finite gallery of Flutter screens. They are served by a **runtime that interpolates**.

Profile A vs B vs Floor in the demo are *sample points* so a judge can see the reshape. They are not the product’s user model.

---

## 2. Why the Flutter app feels brittle

It is not brittle because Flutter cannot flex. It is brittle because much of the flex is **encoded as code branches per combination**:

```
DiscreteTaskView  ×  {buttons, joystick, trackpad, switchScan}
ContinuousTaskView ×  {buttons, joystick, trackpad, switchScan}
PointingTaskView   ×  {buttons, joystick, trackpad, switchScan}
TextTaskView       ×  compose mode × touch method
```

That is already ~16 interaction implementations, plus vision field, contrast, locale, input level, reach docking. Adding one new method (e.g. sip-and-puff) or one new task shape means touching every view again.

The **idea** in `docs/idea/03` is cleaner than the **code**:

> A fallback isn’t “the same widget, just worse.” It’s a different, appropriate interaction that achieves the same task.

The idea is a **mapping table**. The code duplicated that table inside four large widgets. That is why changing one user-facing rule feels like a rewrite.

Expo does not fix a mapping table that has been inlined into views. It only changes the language.

---

## 3. What you design once (the adaptive system)

Four layers. None of them is “a screen per user.”

```
┌─────────────────────────────────────────────┐
│  4. Screens (few, shared)                   │
│     Setup → measure → results → preview     │
│     → task shell → confirm                  │
├─────────────────────────────────────────────┤
│  3. Mapping (pure functions)                │
│     chooseMethod(profile, taskShape)        │
│     textComposeMode(clarity)                │
│     patternFor(shape, method)               │
├─────────────────────────────────────────────┤
│  2. Primitives (small set of surfaces)      │
│     button · stick · pad · switch · hold-mic│
│     option list · output strip · field veil │
├─────────────────────────────────────────────┤
│  1. Profile (data)                          │
│     scores, reach, size, clarity, field…    │
└─────────────────────────────────────────────┘
```

**Layer 1** is measured, not designed per person.

**Layer 2** is designed like hardware: a joystick, a pad, a big switch. Each primitive takes the profile as *props* (size, dead zone, axis lock, dwell). One joystick widget serves every user who needs a stick.

**Layer 3** is a spreadsheet in code: task shape × method → which primitive + which gesture. Adding a user does not add a row. Adding a *method* or a *shape* does.

**Layer 4** is a handful of destinations. Setup is the same screen for everyone (tap anywhere). The task *shell* is the same (strip + ribbon + interrupt). Only the primitive in the dock changes.

That is how the interface “flexes with users” without a new Figma file each time.

---

## 4. What actually changes per user (continuous knobs)

These are numbers and enums, not screens:

| Knob | Source | Effect |
|---|---|---|
| Target size | button test | Every control’s min height |
| Reach rect | reach grid | Dock inset; output row |
| Stick home | joystick octants | Overlay alignment |
| Option cap | score + input level | How many choices visible |
| Dwell | steadiness | Switch-scan speed |
| Text scale | vision mode | Labels |
| Field mask | visual field | Veil; hits still pass |
| Compose mode | speech clarity | Dictate vs nod vs touch-pick |
| Method | fallback rule | Which primitive is mounted |
| Palette | contrast flag | Haiku vs black/yellow |

If a new person calibrates, **no new widget is authored**. The same joystick is larger, lower, slower, or not shown.

That is the opposite of “design each and everything in Flutter.”

---

## 5. What you *do* have to design (and it is not infinite)

You still have to design, carefully, because accessibility is not CSS `font-size: larger`:

1. **The primitive set** — including the floor case (single switch). If a method has no native pattern for a shape, that cell of the matrix is a product hole, not something Expo will invent.
2. **The mapping** — ideal vs fallback, margin 0.12, “native pattern not a degraded copy.”
3. **Entry and skip** — first action = tap anywhere; no step is a trap.
4. **Fusion** — touch selects, voice fills; sounds tier is still a vocabulary.
5. **Confirmation and interrupt** — always, with the user’s method.
6. **Honesty** — untested ≠ fail; results show numbers.

That list is finite. It is the same list in Flutter or Expo. The work is **interaction design of primitives**, not **visual design of every user state**.

---

## 6. Flutter vs Expo (the brittleness is not the toolkit)

| Concern | Flutter today | Expo |
|---|---|---|
| Custom stick / field mask | `CustomPaint` — easy | Skia / SVG / Reanimated — doable |
| Gesture fidelity | Excellent | Gesture Handler + Reanimated; watch hold-to-speak and axis-lock |
| Real STT/TTS | Blocked by “SDK only” | `expo-speech`, `expo-av`, on-device or cloud — this is a real Expo win |
| OTA / iterate with users | Store builds | EAS Update — real Expo win if we will actually retune with people |
| Team / JS stack | Dart island | Matches `code/desktop` (Node) if the phone talks to the agent later |
| Offline demo, no packages | Current constraint | Relaxed; pick packages deliberately |
| Adaptation architecture | Must be extracted | Must be extracted **first**, then rendered |

Moving to Expo is justified if we want faster iteration, real speech, and a stack that can grow toward the agent. It is **not** justified as “Expo will adapt so we don’t have to design.” If we port widget-by-widget, we port the brittleness.

---

## 7. How to keep Expo from repeating the trap

**Do this:**

- Port `CapabilityProfile`, `TrialCollector`, `chooseMethod`, `VocalClassifier`, `VocabMapping`, `HaikuTheme.compute` as **pure TypeScript**. No React. Unit-test them the same way Dart tests them.
- One `TaskShell` layout. One `OptionList`. Four surface components. Task shapes are *drivers* (cycle, scrub, place, dictate) that subscribe to the active surface’s events.
- Profile is React context. Screens read knobs; they do not `switch (profile.label)`.

**Do not do this:**

- `ProfileAScreen`, `ProfileBScreen`, `FloorScreen`
- `DiscreteButtons.tsx`, `DiscreteJoystick.tsx`, … sixteen files
- Redesigning layout in Flutter *and* Expo for the same user

The Flutter app remains the **behavioural spec**. Expo is a second renderer of the same spec. When a rule changes, change the TS functions and the Dart functions should match — or freeze Flutter once Expo is the phone we ship.

---

## 8. One-line rule

> Design the **measurement**, the **primitives**, and the **mapping**. Let the user’s numbers assemble the interface. Do not design the assembled interface for each user, in Flutter or anywhere else.
