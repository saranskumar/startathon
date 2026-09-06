# Phone app UI/UX wireframe spec

**Also see** [idea/30 — Meeting Notes: Onboarding & Calibration Walkthrough](../idea/30-meeting-notes-onboarding-calibration-walkthrough.md) for the decisions that drove Start gate, Hold reorder, and axis hold-to-skip.

Low-fi wireframe in text: every screen, what is essential vs supporting, and the only legal order. Documents what is already built in `code/app` plus the intended flow. Not a pixel mock. Not a visual redesign.

**Code:** `code/app/lib/main.dart` (screens), `calibration/`, `runtime/`, `training/`, `vision/`.  
**Requirements:** [idea/08-requirements.md](../idea/08-requirements.md).  
**Scope:** [idea/05-scope.md](../idea/05-scope.md).  
**Voice/text modes:** [desgin.md](desgin.md).

---

## 1. Purpose

| Who | What they do |
|---|---|
| **Person being measured** | Tap/hold to start, run (or skip) tests, use the resulting controllers on a short task chain |
| **Optional helper** | Same phone; practice motions first, then pick which axes to measure |
| **Judge / demo** | Skip live calibration via Profile A / B / Floor presets; same runtime object |

**Done** means: a `CapabilityProfile` exists, then at least one consequential intent is confirmed and â€œsentâ€ (logged to the output strip â€” no real laptop wire in this build).

---

## 2. Global rules

These apply once measurement has started (live draft) and after a confirmed profile (preview + demo).

| Rule | Detail |
|---|---|
| **Output strip** | Laptop preview: last intent + live raw signal. Sits on the row the user cannot reach (`outputAtBottom`). Tap opens the event log. |
| **Visual field shell** | Tunnel or peripheral veil; mask uses `IgnorePointer`. Stays **full** until vision commits; then applies including on the results report. |
| **Theme** | Haiku after axes/profile; **high contrast** is a peer palette (WCAG 4.5:1 text / 3:1 chrome), not a haiku variant. |
| **Scale / targets** | Text scale from vision; min target size from buttons â€” applied to Skip and later chrome **as soon as measured**. |
| **Input dock** | Joystick floats at stick home / reach anchor; everything else docks inside the reachable zone. |
| **Live draft** | After each test, `draft.build()` is pushed into `AppState` so the next step is already shaped. |
| **Recalibrate / Redo** | Settings, results, or preview tune â†’ **Setup** (clears confirmation). Never back to a blended demo home. |

**Calibration step chrome** (shared `StepFrame`):

- One short instruction line, always in the same place.
- Progress `N of M`.
- **Skip this test** always present; height follows measured `minTargetSize`.
- **Back** from the second test on, same size, opposite Skip (left). Retakes the previous test as untested. Hidden on the first test â€” does not return to the axis picker.
- Skip = **untested**, never failed.

---

## 3. Locked end-to-end flow

Do not reorder these edges.

```mermaid
flowchart TD
  open[App open]
  startGate[Start gate: tap/hold]
  setup[Setup: tap/hold block]
  continueScreen[Continue]
  settings[Settings circle]
  demoMenu[Demo: presets, contrast, locale]
  train[Caregiver training]
  axes[What to measure]
  tests[Tests: each uses prior results]
  results[Your setup - already calibrated]
  preview[Your controllers]
  task[Task chain]
  review[Confirm send]
  sent[Sent]

  open -->|not confirmed| startGate
  open -->|confirmed this session| preview
  startGate -->|tap/hold| setup
  setup -->|tap/hold the block| continueScreen
  setup -->|Someone is helping| train
  setup --> settings
  continueScreen --> axes
  preview --> settings
  settings --> demoMenu
  demoMenu -->|preset| preview
  demoMenu -->|Redo setup| setup
  demoMenu -->|Someone is helping| train
  train --> axes
  axes --> tests
  tests --> results
  results -->|Use this setup| preview
  results -->|Redo| axes
  preview -->|Start tasks| task
  task -->|interrupt| task
  task -->|last task resolved| review
  review -->|Send it| sent
  review -->|Go back| task
  sent -->|Run it again| task
  preview -->|recalibrate| setup
  task -->|recalibrate| setup
  sent -->|Recalibrate| setup
```

### Flow notes

- **Start gate is first** â€” full-bleed tap/hold, nothing else. Then Setup.
- **Setup** â€” helper / contrast / locale sit up top, out of the thumb zone. The reachable lower region is only the tap/hold-to-start block. Welcome clip autoplays. Demo presets live behind the **settings circle** (top-right).
- **Continue** (after Setup tap) is a slim reach-zone screen. It does not replay welcome or re-ask the helper question.
- **Presets skip measurement on purpose** (judge demo, scope item 3). Live calibration and a preset both produce the same `CapabilityProfile`.
- **Assisted:** training â†’ axes (not training â†’ entry). Helper button stays on Setup at the same time as the start block.
- **After each motor/voice/vision step**, the partial profile is live-applied before the next step.
- **Back** during tests returns one step and starts that test over as untested. Hidden on the first test; it does not return to the axis picker.
- **Results already use** measured size, scale, and field. â€œUse this setupâ€ confirms for the session; it does not start applying the profile.
- In-session only: killing the app returns to the Start gate / Setup path.

---

## 4. Screen inventory

Each screen: ASCII wireframe â†’ essential â†’ supporting â†’ functions.

### 4.0a Start gate

First screen. One job: a tap or hold continues to Setup. No header, no audio, no toggles.

```
â”Œâ”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”
â”‚                                     â”‚
â”‚            (touch icon)             â”‚  â† full-bleed tap/hold
â”‚                                     â”‚
â””â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”˜
```

| Essential | Supporting |
|---|---|
| Full-bleed tap/hold â†’ Setup | |

### 4.1 Setup

```
â”Œâ”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”
â”‚ [helping] [contrast] [locale] (gear)â”‚  â† upper, out of thumb zone
â”‚ Set up how you control things       â”‚
â”‚ Recorded welcome (autoplay)         â”‚
â”œâ”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”¤
â”‚ â”Œ TAP / HOLD TO START â”             â”‚  â† only thing in reach zone
â””â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”˜
```

| Essential | Supporting |
|---|---|
| Lower block tap/hold â†’ Continue | Recorded welcome, autoplay, Play recording to replay |
| Helper / contrast / locale in the upper region | Settings circle â†’ demo sheet |

**Functions:** start solo measurement (via Continue); start assisted training; open settings for presets/contrast/locale.

### 4.1b Settings sheet (demo / judge)

| Essential | Supporting |
|---|---|
| High contrast + locale chips | |
| OR START FROM A SAVED PROFILE (A / B / Floor) | |
| Redo setup (when a profile is confirmed) | |
| Someone is helping set this up | |

Presets jump straight to preview. Redo clears confirmation and remounts Setup.

### 4.1c Continue (after Setup tap)

Slim post-tap screen. Does not replay welcome or re-ask the helper question. Assisted sessions skip this and open training.

```
â”Œâ”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”
â”‚ We'll measure what works.           â”‚  â† out of thumb zone
â”œâ”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”¤
â”‚ â”Œ CONTINUE â”                        â”‚  â† reach zone, tap/hold
â””â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”˜
```

| Essential | Supporting |
|---|---|
| Large Continue tap/hold â†’ axis picker | Settings circle if shown |

### 4.2 Caregiver training

Reached only via â€œSomeone is helpingâ€¦â€. No scores. Practice before measurement.

```
â”Œâ”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”
â”‚ Practice with a helper              â”‚
â”‚ (no score copy)                     â”‚
â”‚ â”Œâ”€ Recorded training clip â”€â”€â”€â”€â”€â”€â”€â”€â” â”‚
â”‚ â””â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”˜ â”‚
â”‚ Motion 1 of 3 Â· Together            â”‚
â”‚ Instruction: Tap the square.        â”‚
â”‚ Helper: Hand under theirsâ€¦          â”‚
â”‚ â”Œâ”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â” â”‚
â”‚ â”‚           ARENA / TAP           â”‚ â”‚
â”‚ â””â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”˜ â”‚
â”‚ [ Try again ]                       â”‚
â”‚ [ Skip this motion ]                â”‚
â”œâ”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”¤
â”‚ [ Skip all practice, go to measure ]â”‚  â† pinned footer
â””â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”˜
```

| Essential | Supporting |
|---|---|
| One motion at a time: tap â†’ slide left â†’ slide up | Recorded training narration |
| Phase label: together / start-together-finish-alone / from the words alone | Independent hit counter when in independent phase |
| Helper copy: hand-under-hand default | |
| Arena (only practice target) | |
| Try again, skip this motion | |
| **Skip all practice, go to measurement** â€” pinned, always visible | |

**Functions:** fade prompt full â†’ partial â†’ independent (3 independent successes graduate a drill); skip motion; skip all â†’ axis picker (`helperChoseAxes = true`).

---

### 4.3 Axis picker â€” â€œWhat should we measure?â€

```
â”Œâ”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”
â”‚ What should we measure?             â”‚
â”‚ (optional) Setting this up forâ€¦     â”‚  â† only if helperChoseAxes
â”‚ All three start ON. Hold a row to skip. â”‚
â”‚ WHICH ENVIRONMENTS                  â”‚
â”‚ â”Œ Motor â€¦â€¦â€¦â€¦â€¦â€¦â€¦ â˜‘ hold-to-skip â”     â”‚
â”‚ â”Œ Speech â€¦â€¦â€¦â€¦â€¦ â˜‘ hold-to-skip â”     â”‚
â”‚ â”Œ Vision â€¦â€¦â€¦â€¦â€¦ â˜‘ hold-to-skip â”     â”‚
â”‚ [ Start ]                           â”‚  â† always enabled
â””â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”˜
```

| Essential | Supporting |
|---|---|
| Motor / Speech / Vision as **large whole-row targets**. All three default **ON**. | Helper provenance banner |
| Turning an axis **off** is a hold-to-confirm on that row (fill ring, same duration as the hold test). A tap does not turn it off; a tap on an off row turns it back on. | Haiku theme begins reacting live as rows change |
| Start always enabled. Last remaining axis cannot be skipped. | |

**Functions:** set `measureMotor` / `measureSpeech` / `measureVision`. Axes left off contribute **no** steps (speech-only never mounts joystick).

---

### 4.5 Measurement steps

Only steps for axes left on. Order when all on: reach â†’ buttons â†’ joystick â†’ trackpad â†’ hold â†’ voice â†’ vision.

| Step | Person does | Essential UI |
|---|---|---|
| **Reach** | Tap cells that work | 3Ã—4 grid, skip |
| **Buttons** | Hit large targets | Targets at measured size, skip |
| **Joystick** | Swing per reachable cell | Stick + home-cell result, skip |
| **Trackpad** | Drag; axis lock if needed | Pad, skip |
| **Hold** | Press and hold | Hold target, skip |
| **Voice** | Say 8 sentences | Current sentence, word kept, â€œThat word was clearâ€ / â€œNot this oneâ€, hold-to-speak, next sentence |
| **Vision** | Read shrinking word, then field | Acuity choice â†’ full / tunnel / peripheral |

| Essential on every step | Supporting |
|---|---|
| Instruction + progress + Skip + Back (from step 2) | Idle timeout may skip a stuck step; toast explains |
| Skip / Back = untested | Simulated speech clarity chips on Voice |

**Voice buckets** after sentences: â‰¥6 words landed â†’ `full`; some â†’ `partial` + vocabulary; sounds heard â†’ `sounds`; else `none`.

---

### 4.6 Results â€” â€œYour setupâ€

Four sections (tabs / section nav), not one endless scroll.

```
â”Œâ”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”
â”‚ Your setup                          â”‚
â”‚ [Overview][Methods][Voice][Tasks]   â”‚
â”‚ â€¦section bodyâ€¦                      â”‚
â”œâ”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”¤
â”‚ [ Redo ]           [ Use this setup ]â”‚
â””â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”˜
```

| Section | Essential content |
|---|---|
| **Overview** | Measured environments; helper provenance if any; haiku card |
| **Methods** | Per-method scores; reach count; stick home; target size; steadiness; hold; voice; vision + field; input level; personal words if any |
| **Voice & text** | Dictate / vocal-confirm / touch-pick plan; skipped list; swipe axis lock if set |
| **Tasks** | For each task shape: which method, ideal vs fallback reason |

| Footer essential | Supporting |
|---|---|
| **Redo** â†’ axis picker | Haiku motif (identity, not a control) |
| **Use this setup** â†’ preview | |

---

### 4.7 Preview â€” â€œYour controllersâ€

```
â”Œâ”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”
â”‚ â–“â–“â–“ OUTPUT STRIP (laptop preview) â–“â–“â–“â”‚
â”‚ Your controllers          [tune]    â”‚
â”‚ [Buttons][JoystickÂ·yours][â€¦][Voice] â”‚
â”‚ Hint for current surface            â”‚
â”‚ â”Œâ”€â”€â”€â”€ try pad / dock â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â” â”‚
â”‚ â””â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”˜ â”‚
â”‚ [Simpler] Level: â€¦ [Level up]       â”‚
â”‚ [ Start tasks ]                     â”‚
â””â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”˜
```

| Essential | Supporting |
|---|---|
| Output strip pinned | Level label copy |
| Surface chips: Buttons, Joystick, Trackpad, Switch, Voice (strongest marked â€œyoursâ€) | |
| Try pad using this profileâ€™s size / reach / voice mode | |
| **Simpler / Level up** (one â†’ two â†’ many targets) | |
| **Start tasks** | |
| Recalibrate (tune) â†’ home | |

---

### 4.8 Demo task chain

Fixed order. Every task screen shares:

```
â”Œâ”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”
â”‚ â–“â–“â–“ OUTPUT STRIP â–“â–“â–“                â”‚  (top or bottom by reach)
â”‚ Ribbon: prompt + why this method    â”‚
â”‚ [recalibrate] [controllers]         â”‚
â”‚ â”Œâ”€â”€â”€â”€ task body / dock â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â” â”‚
â”‚ â””â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”˜ â”‚
â”‚ [ Stop / start this step over ]     â”‚
â””â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”˜
```

| # | Task | Shape | Essential behavior |
|---|---|---|---|
| 1 | Pick a plan | Discrete | Options paged by `visibleOptionCount`; method from fallback rule |
| 2 | Set seat count | Continuous | Adjust + confirm with chosen method |
| 3 | Mark a spot | Pointing | Place marker; agent-assist only when not trackpad |
| 4 | Add a note | Text (fusion) | See Thesis B below |
| 5 | Review | Discrete | â€œAbout to sendâ€¦â€ + **Send it** / **Go back** via **same** method |
| 6 | Sent | Done | Run it again / Recalibrate |

**Interrupt:** resets **current step** state only (not the whole profile / collected answers).

#### Text task â€” Thesis B (essential)

| Clarity | How content is filled |
|---|---|
| `full` / `partial` | Hold to speak â†’ transcript â†’ confirm (partial always confirms) |
| `sounds` | One sound / nod / hum = yes; two sounds = next phrase |
| `none` | Pick a suggested phrase by touch method |

**Vocabulary** (when `usesWordVocab`): small menus map words onto options; long menus map first three words to next / previous / select (e.g. `water` / `tank` / `yellow`).

---

## 5. How the same screen changes

| Lever | What changes |
|---|---|
| **Profile A** | Precise touch, clear speech â†’ buttons-heavy, dictate, full field, many targets |
| **Profile B** | Imprecise touch + partial speech â†’ often joystick fallback, vocab words, two targets |
| **Floor** | Switch scan, sounds tier, tunnel field, one target |
| **Input level** | How many discrete options visible at once (one / two / many capped by `maxControls`) |
| **Visual field** | Tunnel: condensed output window; peripheral: center veiled; both leave hits through |
| **High contrast** | Black / white / yellow peer theme |
| **Locale** | Recorded onboarding catalog `en` / `ml` |
| **Fallback rule** | Ideal method for the task shape unless another scores â‰¥ margin higher |

---

## 6. Supporting (never block the path)

- Event log sheet (from output strip).
- Play-recording button (timed transcript + screen-reader announcement until WAVs exist).
- Toast on skip / idle.
- Level-up / Simpler chrome on preview.
- Haiku motif on results.

---

## 7. Hard constraints (non-negotiable)

| Constraint | Why / FR |
|---|---|
| First action never harder than a single tap/hold anywhere | Issue #1; entry must not gate on precision |
| Helper path visible at the same time, not a second screen to discover | Research 11 |
| Every calibration step skippable | FR13â€“15 honesty; untested â‰  fail |
| No consequential send without explicit confirm | FR7 |
| Interrupt resets current step, not whole profile | FR8 |
| Skip / untested â‰  fail | Results / scoring honesty |
| Field mask never steals hits | Issue #4 |
| High contrast peer to haiku (4.5:1 / 3:1) | Research 11 |
| Profile switch visibly reshapes the interface | Scope item 3; FR11 |
| Touch + voice fused at least once on partial profile | Scope item 4; FR4 |

---

## 8. Out of scope for this phone wireframe

- Desktop ranking / inspector.
- Aperture Daily mock websites.
- Real microphone / WAV assets (catalog stands in).
- Agent filling a real form / laptop wire.
- Camera head-nod as a separate sensor.

Those are other surfaces or future work; this spec stays on the Flutter phone flow only.
