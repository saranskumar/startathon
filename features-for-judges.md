# Features judges might miss

The five-minute demo cannot show this. The pitch already covers the headline (measure, don’t label; fuse partial abilities; reshape the same task). This file is the rest: accessibility and product details that are easy to skip in the talk, or that a judge will not notice unless you point at them.

Drawn from `docs/app/01-feature-inventory.md`, `docs/desgin/ui-ux-phone-flow.md`, `docs/desgin/desgin.md`, `docs/idea/`, `docs/tech/research/11–14`, and `code/app` / `code/desktop`. Only **built** behaviour is listed as a claim. Simulated or missing pieces are at the end so nobody oversells them.

---

## How to use this

- During the live demo, say the **one-liners** in the first two sections if the relevant screen is on.
- Keep the later lists for Q&A (“did you think about…?”).
- Do not tour every item. One workflow, then answer with this list.

---

## Say out loud if it is on screen

These are the details a judge will otherwise treat as ordinary UI.

| When they see… | What to say |
|---|---|
| First screen, tap anywhere | **The first action is never harder than a tap or hold anywhere.** A small “Start” button would gate the people this app is for. Same idea as Android’s volume-key shortcut and iOS’s Accessibility Shortcut. |
| Setup: big block at the bottom, tiny chips at the top | **The reachable zone is only the start block.** Helper, contrast, and language sit *out of the thumb zone* so a helper can use them without stealing the user’s one reliable target. Both paths are on the same screen — the caregiver path is not a second screen to discover. |
| “Someone is helping” | **This is occupational-therapy prompt fading, not a tutorial.** Hand-under-hand first (less coercive than moving their hand for them). Together → start-together-finish-alone → from the words alone. Three independent hits graduate a drill. **No scores** — this is before measurement. Skip-all is always pinned. |
| Calibration Skip | **Skip means untested, never failed.** Honesty in the results. Every step is skippable. Idle 20s auto-skips; three idle skips in a row jump to the most forgiving leftover setup so nobody is trapped. |
| Targets getting bigger after the button test | **The next step is already shaped.** After each test the partial profile is live-applied (size, reach, theme) before the next screen mounts. Reach is measured once and later motor tests sit *inside* that zone, so precision is not scored down by a target they could not get to. |
| Vision: shrinking word, large answer buttons | **Forced choice, not “can you see this?”** The word shrinks; the answer buttons stay large so the buttons never become the limiting factor. Then field: full / tunnel / peripheral — two opposite field-loss types, not one “partial vision” bucket. |
| Dark veil over the screen | **The mask never steals hits.** It is `IgnorePointer`. Tunnel condenses output into one window (they should not scan the whole screen). Peripheral veils the centre (eccentric viewing / central scotoma). Applying one fix to the other population would hurt them. |
| Output strip at the top or bottom | **Output lives where the hand cannot reach.** Calibration finds the least-reachable row. Dead space for input is the honest place to spend on output. Tap it for the event log. |
| Floating joystick | **The stick floats at the measured home cell.** Everything else docks in the reachable span. A docked stick would sit where the layout wants it, not where the hand rests. |
| Confirm / Send it | **The gate uses the user’s own method.** A tiny dialog OK would demand an ability they were never measured for. No consequential send without that confirm. Interrupt is a full-width bar; it resets **this step**, not the profile. |
| Text task + hold to speak | **Touch selects, voice fills (Thesis B).** Partial speech always confirms. `sounds` is still a vocabulary (one pulse = yes, two = next) — not treated as no voice. Slow speech is not timed out. |
| Profile Trackpad/switch → A → B → Floor | **The same task, four assembled interfaces.** Presets skip measurement on purpose for the room; live calibration produces the same object. Trackpad/switch is first in the gear menu: no voice, limited reach, trackpad over switch when they are close. Floor is single-switch scan + sounds — the person who scores low on every precise method still has an answer. Tunnel overlay deferred; real tunnel layout is further scope. See [docs/app/04](docs/app/04-clarity-playground-and-field.md). |

---

## Accessibility that is easy not to notice

These are easy to build and then never mention.

### Entry and dignity

- **Full-bleed start gate** — no header, no audio, no toggles. One job: tap or hold continues.
- **Helper and solo on the same first reachable screen.** Caregiver involvement in setup is a documented gap in accessible apps; it is not a checkbox inside a flow the solo user has to reach first.
- **Hold-to-skip an axis** on “What should we measure?” A tap cannot turn Motor / Speech / Vision off (too easy to miss). Hold shows a fill ring. The last remaining axis cannot be skipped.
- **Back during tests** retakes the previous step as untested. Hidden on the first test — it does not dump them back to the axis picker.
- **Skip / Back chrome grows** to the measured minimum target size as soon as buttons are measured.
- **In-session only.** Killing the app returns to the start gate. No silent persistence of a wrong profile.

### Vision and contrast

- **High contrast is a peer palette, not a dark-mode skin of the haiku theme.** Black / white / yellow. Aimed at WCAG **4.5:1 text / 3:1 chrome**. In-app toggle **and** it follows the OS `MediaQuery.highContrast` flag (users who never find the OS setting still get the in-app one).
- **Haiku theme** (yellow motor / blue speech / pink vision, blended by scores) is identity, not a diagnosis and not a control. High contrast is the legibility floor; haiku answers “who was measured.”
- **Text scale** from the vision step (`screen` 1.0× / `large` 1.45× / `none` 1.6×) is independent of field shape. Tunnel users are not forced into huge type that would overflow their narrow window.
- **Visual field stays full until vision commits**, then applies everywhere after — including the results report.

### Hearing, speech, and screen readers

- **Recorded-voice-shaped onboarding** (welcome + training) in **English and Malayalam**. Catalog stands in until WAVs exist: timed transcript plus a **screen-reader announcement** of the same words.
- **Flutter semantics:** live regions on the dock / option lists; `SemanticsService.announce` when the highlighted option changes during joystick cycle and switch scan (TalkBack / VoiceOver hear “selected,” not only a visual highlight).
- **Voice calibration is eight sentences**, not one phrase. Only the **target word** is scored into a personal vocabulary. User marks “that word was clear” / “not this one.”
- **Two vocabulary mappings:** small menus map personal words onto the options (`water` / `tank` / `yellow`); long menus map the first three words to **next / previous / select**, so a two-word vocabulary still operates an arbitrarily long list.
- **Vocal events are duration + burst count, not pitch and not a camera.** Nod under ~280 ms; hum ≥ ~800 ms single hold; burst = two+ presses in the settle window (~900 ms gap). Hold-to-speak waits; it does not punish slow or interrupted speech.
- **Named haptics:** navigate (light, fires often), confirm (medium), error (heavy). Meaning, not intensity numbers.

### Motor and layout

- **Steadiness** stretches switch-scan dwell (tremor tolerance) instead of failing the user.
- **Hold-capable** is measured; hold-to-repeat is only offered if they can hold.
- **Trackpad axis lock:** if one axis is markedly worse, later pads discard it (X-only / Y-only).
- **Input levels:** everyone can start at one target and **Level up** / **Simpler** (one → two → many, capped by `maxControls` from the score). Progressive complexity without a new screen per user.
- **Options are paged** by `visibleOptionCount` — never dump six tiny choices on a floor profile.
- **Switch scan** uses a row/column grid when N is large; pointing uses row then column. Floor case is implemented, not a slide.

### Training (caregiver)

- Default copy is **hand under theirs**, not on top.
- Phase labels are explicit: together / start-together-finish-alone / from the words alone.
- Independent-hit counter only appears in the independent phase.
- Helper provenance banner on the axis picker and results if someone else chose what to measure.

---

## Nifty product mechanics judges will not infer

The demo looks like “big buttons.” These are why it is not just big buttons.

### The profile is a runtime, not a theme

- One `CapabilityProfile` object drives method, size, reach, dock, output row, stick home, option cap, dwell, text scale, field, compose mode, and locale. **No `ProfileAScreen`.** Adding a person does not add a Flutter screen.
- **Fallback rule (design-time, not an LLM):** use the task’s ideal method unless another scores ≥ **0.12** higher. Then use the user’s best method with **that method’s native pattern** — not a shrunken copy of the ideal widget. Relative comparison, so a user who is mediocre at everything still gets their genuine best.
- **Full 4 task shapes × 4 methods matrix is built**, not only the two cells the demo needs. Discrete / continuous / pointing / text × buttons / joystick / trackpad / switch.

| Shape | Buttons | Joystick | Trackpad | Switch |
|---|---|---|---|---|
| Discrete | tap | cycle + press | hover + release | auto-scan + press |
| Continuous | stepper | push and hold | drag to scrub | scan direction, press to run |
| Pointing | recursive quadrant / 5-cell tree | steer + press | drag + release | row scan, then column |
| Text | fused: touch picks the field; voice fills or confirms | same fusion | same | same |

- **Pointing with buttons** is a recursive 5-cell `MarkerGrid` (`ceil(log5 n)` picks), not a fake trackpad.
- **Score formula is explicit:** `0.5·success + 0.3·(1−time) + 0.2·(1−error)`. Results show the table. Untested methods are not zeros.
- **`maxControls` from best score:** ≥0.75 → 6, ≥0.55 → 4, ≥0.35 → 3, else 2.
- **Ribbon on every task** states the prompt and *why this method* (ideal vs fallback). That sentence is the thesis, visible.

### Calibration design

- Order when all axes are on: **reach → buttons → joystick → trackpad → hold → voice → vision**. Only chosen axes mount (speech-only never shows a joystick).
- **Simulated recogniser panel** on the voice step — any clarity tier can be forced on stage so the room’s microphone is not the demo.
- Results are four sections (Overview / Methods / Voice & text / Tasks), already using measured size, scale, and field. “Use this setup” confirms for the session; it does not start applying the profile (application started at the first live draft).
- **Recalibrate / Redo always returns to Setup**, never a blended demo home.

### Safety and honesty

- **No AI in the path.** Calibration, mapping, vocal classifier, and desktop ranking are deterministic. Ambiguous pages get a flag, not a model call.
- **Confirmation before send; interrupt always visible.**
- Flutter **SDK only** — no third-party packages. Offline `flutter run` works.

---

## Desktop half (if there is time, or in Q&A)

Phone intents do **not** yet drive the laptop. Say that. Then, if you open the inspector:

- **Playwright reads the accessibility tree; a heuristic DOM engine ranks it.** No LLM. Navigation vs information buckets. Every score expands into the exact terms that produced it.
- **Every dropped node has a reason** (`prunedBecause`). Judges can tick “show pruned.”
- **Usage counts** boost features picked before (`usage-counts.json`) — frequency standing in for “an ML model, not an LLM,” with no training data.
- **Ambiguity banner** when there are no landmarks/headings, scores are flat, or clickable nodes have no ARIA role. The engine admits when it is guessing. On a form, all fields scoring within 0.2 of each other is correct: there is no “most important field.”
- **Overflow packs into groups** (heading / landmark, then 2×2 spatial split) instead of silently slicing to 12.
- **Page chrome is penalised; main/form is boosted.** Banner links collapse into one “Site chrome · N” group so they cannot fill the slots.
- **Rescan only when the page actually changed** (History API + MutationObserver fingerprint). Dragging a slider does not rebuild the tree; swapping a screen does.
- **Dasher-style zooming navigator:** one continuous axis; box size is predicted probability. Converts precision into time. Confirm is a **second box** (a click is not a retractable letter). Low-ranked options keep a size floor so they stay steerable. Text fields open a letter-frequency alphabet. Speed presets beginner / intermediate / advanced.
- Each ranked feature already carries **`taskShape` + Playwright `action`** — the seam the phone will consume when the wire exists.

---

## If a judge asks…

| Question | Answer |
|---|---|
| What about someone who can’t use buttons, stick, or pad? | **Single-switch scanning** is a first-class method in the same matrix (Profile Floor). Dwell from steadiness. Not a separate app they have to stitch in. |
| Isn’t this just TalkBack / Voice Access / AssistiveTouch? | Those each need **one complete channel** he does not have (swipes TalkBack needs, speech Voice Access needs). We compose residuals. |
| Why not an LLM to pick the UI? | **Task-to-ideal mapping is fixed at design time (FR17).** Live model choice is unnecessary risk and not auditable. We dropped OpenClaw for overhead, security, and latency. |
| Dysarthria / “does speech actually work?” | **Recognition is simulated on purpose.** The interaction (hold timing, bursts, confirm, vocab mapping) is real. Do not claim a dysarthria-tuned model. Hosted ASR is a swap behind `SpeechSource`. |
| Can they use their real WhatsApp? | Not yet. Mocks (Aperture Daily) are the primary surface. Phone and desktop are not wired. Formal use with the person who inspired this is planned, not done. |
| Screen reader users with full motor? | **De-emphasized.** A mature screen reader already serves that point. Value is **combinations** those tools miss. |
| Head-nod / sip-and-puff / gaze / EMG? | Roadmap. Phone doesn’t have that hardware. The *meaning* of a short yes-pulse is already the `sounds` nod. |

---

## Do not claim (yet)

Say these if asked; do not imply they shipped.

| Piece | Status |
|---|---|
| Speech recogniser | Stub (`SimulatedSpeechSource`) |
| WAV onboarding audio | Catalog + transcript + announcement only |
| Proactive TTS narration for `vision = none` | Not built (large text + field are built) |
| Phone → laptop wire / agent filling a live form | Seam is `AppState.emit`; not connected |
| Profile persistence across app kill | None |
| Camera head-tracking, sip-and-puff, gaze, BCI | Research / roadmap |
| Native OS app control (not the browser tree) | Out of event scope |
| Any LLM | Explicitly none |

---

## One-minute closing pack (if Q&A is dying)

1. First action is tap-anywhere; helper is on the same screen.
2. Skip is untested; idle cannot trap you; live draft sizes the next step.
3. Output sits in unreachable space; the field veil never eats taps.
4. Confirm and interrupt use the measured method.
5. Partial speech still has a vocabulary; `sounds` is still yes/next.
6. Tunnel and peripheral are opposite fixes.
7. Ranking a page is a deterministic engine, not a model.
8. The floor is switch-scan, not “unsupported.”
