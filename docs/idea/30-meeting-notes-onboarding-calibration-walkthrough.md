# 30. Meeting Notes: Live Usability Walkthrough — Onboarding & Calibration Flow

**Source:** Voice-memo transcript, product owner narrating a live run through `code/app` (home screen → calibration → results), 2026-09-06. Unverified transcript, same status as docs 24–27.

**Status:** Raw feedback organized and cross-checked against the actual code (`code/app/lib/`). **Nothing has been implemented from this doc yet** — this is the "why it's failing, how it's failing, what we'd need to do about it" pass the feedback itself asked for, not a spec to build from without a follow-up decision pass. Each item below separates *what's currently there* (file/line, verified) from *what was reported* from *what to actually decide/do*.

**Reads together with:** [24 — Onboarding Entry & Accessibility](24-meeting-notes-onboarding-entry-and-accessibility.md) (the original entry-screen/high-contrast/recorded-audio ask — this doc is the first live check of how that landed), [03 — Input & Calibration](03-input-calibration.md), [UI/UX phone flow](../desgin/ui-ux-phone-flow.md) — the **locked** wireframe spec ("do not reorder these edges"). See the conflicts section immediately below before reading further — several items in this doc's feedback disagree with what that spec already locked, and those need a decision, not a silent pick.

---

## Decisions — conflicts with the locked UI/UX spec, now resolved by the product owner

`docs/desgin/ui-ux-phone-flow.md` is marked as a **locked** flow ("Do not reorder these edges"). Four items in the feedback below contradicted it directly; each has now been decided in favor of the feedback, with follow-up mechanics settled in a clarification pass. **These decisions amend the locked spec** — `docs/desgin/ui-ux-phone-flow.md` itself has not been edited yet and should be updated to match once this doc is reviewed, so the two documents don't silently diverge.

1. **Autoplay the welcome recording — RESOLVED, and expanded in scope.** Since this ships as a native Flutter app, browser-autoplay-blocking policy doesn't apply the way it would on Flutter web. Decision: add a new minimal **"start"/"begin" screen before everything else** — a single low-effort button, no other content — as the standard entry point for **every** user (real deployment and demo alike), not just a demo-mode gate. The actual Setup screen (header, recorded welcome, tap-to-start block) only mounts after that first press. This both sidesteps any residual autoplay-policy concern (the press is a user gesture, satisfying platform audio policy on any build target including web) and gives the flow one clear first action instead of a screen with several things on it at once. **This adds a new node to the locked mermaid flow** (`open → [new] start-gate → setup`) — flag this explicitly when the spec doc gets updated, since the flow diagram is otherwise "do not reorder."
2. **Hold step position — RESOLVED, moves after Buttons (not after Reach as first proposed), and changes scope.** Final order: **Reach → Buttons → Hold → Joystick → Trackpad**. Rationale from the product owner: running Hold right after Buttons lets the app cross-reference the two — e.g. 5 buttons found tappable in the Buttons step, 2 of which are also holdable, yields 7 distinct possible inputs (5 tap-only + 2 tap-and-hold) rather than one undifferentiated capability. **This changes what Hold measures, not just its position:** Hold becomes a **per-button test**, run once for each button/cell the Buttons step already found tappable, rather than one generic "press anywhere below and hold" test on an arbitrary target. This is a bigger implementation change than a reorder — `HoldStep` (`touch_steps.dart:901-1053`) needs to iterate over the Buttons step's result set instead of running once, and total calibration time for this step scales with however many buttons were found (was O(1) attempt, now O(N)) — worth a quick sanity check on total calibration duration once this is speced further.
3. **Axis picker defaults — RESOLVED.** All three axes (Motor/Speech/Vision) default **ON**. The "skip this axis" affordance (per §4 below) is a **large, low-effort, long-press/hold-to-confirm toggle** — consistent with the app's existing hold-to-confirm pattern (`HoldStep`'s own ring-fill interaction is a precedent for this UI pattern) — not a precise tap-to-toggle.
4. **High-contrast / language / "someone is helping" placement — RESOLVED.** Final rule, in the product owner's own words: *the reachable zone is reserved for the user doing it themselves* — the bottom/thumb-reach region of the Setup screen holds **only** the primary tap-to-start action. High contrast, language, and "someone is helping" all move **outside** that reach zone (e.g. upper area of the screen): high contrast and language don't need to be within easy reach because they're correct **by default** and don't require the target user to interact with them at all; "someone is helping" doesn't need to be in the target user's reach zone either, since a caregiver — not the target user — is the one who acts on it. They should still be reachable *somewhere* on screen via some control, just not competing for the same zone as the primary action.
   - **High contrast:** ON by default, opt-out (confirmed).
   - **Language default:** stays `'en'`, **not** device/browser locale. Checked against the actual code: `locale` state is real and threaded through (`session.dart:48`, `calibration_flow.dart:36-41`, `profile.dart:171`), but it only changes which `RecordedNarration` clip is looked up (welcome/training audio-text, `recorded_voice.dart:70-75`) — every other string in the app (button labels, step instructions, axis picker copy, results, etc.) is hardcoded English regardless of locale. Per the product owner's own rule ("if it's not [fully] implemented... only that page/content gets it, none of the other pages do" — which matches exactly what's true here), defaulting to device locale would overstate what the toggle actually does, so it stays defaulted to `'en'`.
   - **Demo-only presets** ("start from a saved profile"): move behind the **settings-circle icon** already specified in the locked spec (`ui-ux-phone-flow.md` §4.1b) — not a new hamburger icon as first suggested.
5. **Post-calibration "playground" (§12 below) — the old “missing playground” report resolved cleanly (no conflict with the locked spec).** A **new** Playground is now planned separately: gear/settings → 2-wide mode cards → Calibration or lightweight Demo. See [app/04](../app/04-clarity-playground-and-field.md). The Demo screen stopping at a local log is still by design (no laptop wire).

Everything else in this doc (§2, §3, §5, §6, §7, §9, §10, §11) is either not addressed by the locked spec at all (so no conflict, just new ground) or is consistent with it, and remains an open design item pending its own decision pass.

---

**Core theme running through nearly every item below:** the calibration flow's own screens routinely assume the ability they're trying to measure. A screen that requires reading dense text to know "you can skip this" doesn't help someone who can't read dense text; a screen with three tap-to-select checkboxes doesn't help someone whose whole reason for being here is that tapping small precise targets is unreliable. This isn't a UI-polish list — it's a category of bug specific to this product.

---

## 1. Home screen is too text-heavy / not self-evident

**Reported:** Opening the app shows a header ("Access layer"), a subtitle instructing the user to tap or hold, and a separate "Play recording" button the user has to notice and press themselves — none of it obviously communicates "tap here" to someone who can't read well or doesn't already know the convention.

**Current state** (`code/app/lib/main.dart`, `_HomeScreen`, lines 149–266):
- The header, subtitle, narration widget, and the actual tappable "Tap anywhere to start" block are stacked in one scrolling column — all inside the same `GestureDetector`, so the whole region is tappable, but visually it reads as several separate pieces of UI, not one obvious affordance.
- `RecordedNarration` is instantiated with `autoplay` unset → defaults to `false` (`onboarding/recorded_voice.dart:87-92`), so the welcome audio does **not** play automatically; the user must find and press "Play recording" (`recorded_voice.dart:199-209`).
- High-contrast and language toggles sit as `FilterChip`s in the *lower-middle* of the screen (`main.dart:226-244`), below the "Someone is helping" button.
- "Start from a saved profile" presets are a separate section at the *bottom* of the same scrolling list (`main.dart:246-260`) — mixed into the primary screen rather than separated out.
- High contrast defaults to **off** (`state.highContrast`, no code path sets it true by default).

**Why this matters:** for the target user, "the first screen requires figuring out several things at once" is itself a failure — see the core theme above.

**RESOLVED — see "Decisions" section above for full detail. Summary:**
- A new minimal "start" screen (one button, nothing else) precedes the Setup screen for every user; the recorded welcome autoplays once Setup itself mounts, no separate "Play recording" tap needed as the primary path.
- High contrast: ON by default, opt-out.
- Language: defaults to `'en'`, not device locale (the toggle only affects which narration clip plays, not app-wide text — see Decisions §4).
- Reachable/bottom zone on Setup holds **only** the tap-to-start action; high contrast, language, and "someone is helping" move outside that zone (they don't need to be within the target user's easy reach — see Decisions §4 for why).
- Demo-only saved-profile presets move behind the settings-circle icon (not a new hamburger icon).

**Planned, tracked:** [GH #5 — Add Start gate screen + restructure Setup screen](https://github.com/saranskumar/startathon/issues/5).

---

## 2. Reachability: top vs. bottom half of the screen

**Reported:** Users with limited motor range/reach often have the bottom half of the screen (near the thumbs, one-handed hold) reliably reachable but struggle with the top half. Primary controls (tap-to-start, language, high-contrast, "someone is helping") should be positioned low, not scattered from top to bottom.

**Current state:** the header/subtitle sits at the very top (`main.dart:171-185`); the "someone is helping" button and the contrast/language row sit mid-screen (213-244); presets are at the bottom. No layout in the codebase currently reasons about thumb-reach zones at all — reach is only measured *during* calibration (`ReachStep`, see §4), never used to inform the *pre-calibration* screens' own layout, which is a bit of a chicken-and-egg (the app doesn't know this user's reach profile yet when it draws the home screen).

**What needs deciding:** since the app has no profile yet at this point (that's the whole reason calibration exists), this can't be personalized per-user pre-calibration. What it *can* do is adopt a **conservative default layout** — put the primary tap target and the highest-value secondary actions (language, contrast, "someone is helping") in the bottom two-thirds of the screen by default, on the general accessibility-design assumption that bottom-of-screen one-handed/thumb reach is more commonly viable than top-of-screen reach. This is a layout convention decision, not a per-user personalization — flag as a design-system rule to apply consistently, not just fix on this one screen.

---

## 3. Post-tap "audio controls" screen still text-heavy

**Reported:** After tapping to start, the next screen (calibration entry) is closer to the intended shape but still too text-dense for a user who can't read well; the recorded welcome shows up again; the tap-to-continue affordance should sit within thumb reach, and "someone is helping" should be near the top of *that* screen too.

**Current state:** `_entry()` in `calibration_flow.dart:289-370` (the `_step == -2` state) — this is the screen the survey calls "the entry screen." Uses the same `RecordedNarration` component pattern as the home screen.

**Plan:** apply the same simplification pass as §1 to this screen specifically — fewer simultaneous text blocks, primary action large and low, and confirm whether "someone is helping" needs to appear *again* here (if the user already declared that on the home screen via the `onCalibrate(true)` path — `main.dart:224` — it may already be known and shouldn't need re-asking; check `_startCalibration`'s caregiver-training gate, `calibration_flow.dart:140-164`, to see whether the flag actually persists forward or whether this screen re-shows the control redundantly).

**Planned, tracked:** [GH #6 — Simplify calibration entry screen](https://github.com/saranskumar/startathon/issues/6).

---

## 4. Axis picker (Motor / Speech / Vision) uses checkboxes — the exact ability being tested

**Reported:** The first calibration screen asks the user to tap three checkboxes (Motor/Speech/Vision) to select which axes to test — but if the user has a motor impairment, tapping precise small checkboxes is exactly the thing they may not reliably be able to do. The screen should default to assuming motor difficulty and offer an out-of-reach "skip if you have no motor issues" button, explained aloud via TTS.

**Current state:** `_axisPicker()`, `calibration_flow.dart:375-538`, three `_axisToggle` row-widgets (486-538) — full-width rows with a check-circle icon, larger than a typical checkbox but still a discrete tap-to-toggle-then-continue interaction, and there is no default selection, no TTS explanation, and no "skip if unaffected" shortcut.

**RESOLVED (see Decisions §3 above):** all three axes default **ON**. The "skip this axis" mechanism is a large, low-effort, long-press/hold-to-confirm toggle — not a precise tap. Still open, not yet resolved:
- The exact spoken (TTS) explanation copy for what a long-press does and why it's offered — this item structurally depends on how TTS actually gets wired in project-wide (not yet decided), so the copy itself can be drafted but can't be tested end-to-end until TTS exists.

**Planned, tracked:** [GH #7 — Axis picker: default all axes ON, long-press-to-skip](https://github.com/saranskumar/startathon/issues/7).

---

## 5. Press-calibration ("Reach step"): switch to "tap all you can, in order" instead of sequential single-highlight

**Reported:** Instead of highlighting one target at a time and waiting, ask the user to tap every square they *can* reach, in ascending order (bottom-left = 1, next = 2, second row starts at some N, etc.), so someone who can't hit an early target isn't blocked waiting on it — they move to whichever one they can hit. Confirmation should be a second pass: unselect what was wrongly marked, and use three visibly distinct states — unselected / tentatively-selected / verified.

**Current state:** `ReachStep`, `touch_steps.dart:43-179`. This is a **sequential, one-target-at-a-time** model: one cell in the reach grid is highlighted, the user taps it (or a 3500 ms timer expires and it auto-advances, line ~101), then the next cell highlights. There is no "select everything you can reach, then confirm" pass, and no three-state (unselected/selected/verified) visual model — a tap is recorded as reachable at the time it happens, full stop.

**Why the reported model is different in kind, not just degree:** sequential highlighting means the *test's own pacing* — not the user — decides how long to wait before moving on, and a user who can't act quickly on cue is penalized by the timer instead of being allowed to work through the grid at their own pace across all cells at once.

**RESOLVED — final mechanics:**
- Persistent grid, all cells shown together, spatially ordered ascending from bottom-left, each independently tappable at any time in any order (no per-cell waiting/highlighting).
- Per-cell state machine, not a two-pass UI flow: **stage 0** (untouched) → **stage 1** (first tap, "tentative/possible valid input") → **stage 2** (second tap on an already-stage-1 cell, "locked," final — no further change via tap; correcting a mistaken lock means redoing the whole step, not a per-cell undo).
- Cells left at stage 1 (never reconfirmed) are **kept**, not dropped — the result records two tiers (locked vs. tentative-only), not a single boolean.
- Step completion: **idle-based** — no tap for 2 seconds ends the step and advances on whatever state each cell currently holds, with an overall ~10-second progress countdown shown via timer/haptic/audio feedback (this ties directly into the still-open shared progress-feedback primitive, §6 below).

**Planned, tracked:** [GH #13 — Redesign Reach step](https://github.com/saranskumar/startathon/issues/13).

---

## 6. Progress/timing feedback missing throughout calibration

**Reported:** the user doesn't know how much time is left or when the test will auto-advance. Suggested: an audio tone whose frequency rises as a timer nears its end, plus TTS, plus haptic feedback (e.g. vibration intensity) — and this should apply broadly, not just to one step.

**Current state:** confirmed by the code survey — **no** audio pitch ramp, no TTS countdown, and no haptic feedback anywhere in `lib/calibration/`. A `Haptics` utility already exists (`lib/inputs/haptics.dart`, three calls: `navigate()`/`confirm()`/`error()`) but grep shows it's used only in the **runtime** views (`lib/runtime/discrete_view.dart`, `pointing_view.dart`, `continuous_view.dart`, `lib/inputs/surfaces.dart`, `marker_grid.dart`) — never once inside `lib/calibration/`. Visual-only progress exists: `StepFrame`'s linear progress bar and per-step status text (`step_frame.dart:140-146`).

**RESOLVED:**
- Applies to every timed/auto-advancing step (Reach, Buttons, Hold, Trackpad, Joystick) — not untimed steps like the axis picker or Voice's manual confirmation.
- Audio design: **discrete pulses that speed up** as the window nears its end (not a continuous rising tone).
- Timing: feedback runs **constantly for the full duration** of the window from the moment it starts, not just the final portion.
- Likely dependency-free: `SystemSound.play(SystemSoundType.click)` (Flutter SDK only) called at shrinking intervals can produce the pulse effect without a new audio package, consistent with the project staying dependency-free.

**Planned, tracked:** [GH #14 — Build shared timed-feedback primitive](https://github.com/saranskumar/startathon/issues/14).

---

## 7. "Press the button" / "drag the dot" — copy implies success is required, should imply attempt-only

**Reported:** copy should make clear the user should just *try*, not that they're expected to succeed — the current phrasing reads as "you must do this."

**Current state:**
- Buttons step: instruction `'Press the button.'`, status `'It gets smaller each time. Missing is useful data, not failure. $_feedback'` (`touch_steps.dart:292-294`) — the *headline* is an unqualified imperative; the attempt-based framing only shows up in the secondary status line underneath.
- Trackpad step: instruction `'Drag the dot into the ring, then let go.'` (`touch_steps.dart:821`) — same pattern, no "try to" qualifier in the headline; per the transcript, this one already reads as comparatively more self-evident because the drag-into-a-visible-ring interaction is more physically obvious than "press," so it's flagged as lower priority than the Buttons step's copy.

**Plan:** reword headline instructions to lead with the attempt-only framing ("Try to press the button" / similar) rather than relegating it to secondary status text — a copy change, low implementation cost once the exact wording is agreed, but worth deciding centrally (one copy convention for every step) rather than per-step ad hoc wording.

**Planned, tracked:** [GH #8 — Reword calibration step copy to attempt-based framing](https://github.com/saranskumar/startathon/issues/8).

---

## 8. Hold step ("press anywhere below and hold") — resequence after Buttons, and change what it measures

**Reported:** questioned why the hold-calibration step is positioned where it is. Initial proposal was to move it right after Reach; refined after discussion to run right after **Buttons** instead, specifically so the app can cross-reference which of the buttons proven tappable are *also* holdable (e.g. 5 tappable, 2 of those also holdable → 7 distinct usable inputs, not one undifferentiated number).

**Current state:** step order is Reach → Buttons → Joystick → Trackpad → **Hold** (`_StepKind` sequencing, `calibration_flow.dart:142-148`) — Hold is 5th among the 5 motor steps. The locked wireframe spec (`docs/desgin/ui-ux-phone-flow.md` §4.5) locks this exact order explicitly.

**RESOLVED (see Decisions §2 above):** new order is **Reach → Buttons → Hold → Joystick → Trackpad**, and Hold changes from one generic "press anywhere and hold" test into a **per-button test** run against each button/cell the Buttons step already found tappable — a bigger implementation change than a simple reorder, since `HoldStep` needs to iterate over Buttons' result set rather than run once. This amends the locked spec — `docs/desgin/ui-ux-phone-flow.md` has been updated to match.

**Planned, tracked:** [GH #9 — Reorder Hold step after Buttons and rescope it to per-button testing](https://github.com/saranskumar/startathon/issues/9).

---

## 9. Back navigation during calibration — unresolved, needs discussion

**Reported:** flagged as wanted, but explicitly deferred as "we have to discuss that" — no proposal given.

**Current state:** confirmed **no back-navigation exists anywhere** in the calibration flow. `StepFrame` only exposes a forward-only "Skip this test" button (`step_frame.dart:175-188`); `CalibrationFlow._next()` only advances (`calibration_flow.dart:127-130`); the only way to return to an earlier point is "Redo" from the *results* screen, which restarts entirely from the axis picker (`results.dart:176-179`), not a resume-at-a-specific-step. No design doc currently treats this as an open question either — it isn't mentioned in `09-open-questions.md` or elsewhere.

**RESOLVED:** add a low-effort "back one step" control at the same accessibility level as the existing Skip button (large, low-precision target), placed opposite it, returning to the immediately previous step. Whether stepping back discards or preserves that step's recorded result still needs a rule during implementation.

**Planned, tracked:** [GH #10 — Add accessible back-navigation to calibration steps](https://github.com/saranskumar/startathon/issues/10).

---

## 10. Input method should follow the user's calibrated ability, including in later steps

**Reported:** for steps like Voice calibration, if the user's determined input is swipe-only rather than button-press, the *test itself* should be presented via swipe, not assume buttons are available.

**Current state:** need to verify exactly how much of `sense_steps.dart`'s `VoiceStep` and other later steps assume a specific input widget vs. adapting to what's already been calibrated earlier in the same session — the survey confirmed `VisionStep` specifically is a one-off built from plain `FilledButton`s, **not** reusing the shared calibrated-input surfaces (`TrackpadSurface`, `JoystickPad`, `InputOverlay` from `lib/inputs/`) that Buttons/Joystick/Trackpad steps use.

**Why this matters:** if Motor calibration determines the user can only reliably use swipe/trackpad-style input, but a later step (Voice, Vision) is hardcoded to plain tap-target buttons, that later step is untestable by the same user it's trying to serve — an internal inconsistency within the calibration flow itself.

**What needs deciding:** decide whether every calibration step (not just the touch-method ones) should route its own interaction through whatever input surface the flow has established so far, versus accepting that early steps (Reach/Buttons/Joystick/Trackpad) exist specifically to *determine* the input method and can't yet assume one, while later steps (Voice, Vision, and the axis picker itself per §4) should already respect it. This needs a clear rule, since right now it's inconsistent by omission rather than by design.

---

## 11. Vision calibration: rotate the word set, don't reuse the same words every round

**Reported:** only "pocket" and "candle" ever appear; each round of the vision test should use a different word pair.

**Current state:** `VisionStep`, `sense_steps.dart:269-411` — a fixed 4-word array `['river', 'candle', 'window', 'pocket']` (line 286), paired via `math.Random(3)` (a **fixed seed** — deterministic every run) with a decoy from the other three (lines 303-306), across up to 4 rounds (`_rungs`). So the pool isn't literally two words, but the fixed seed means the *same* run sequence happens every time, and depending on the exact draw order the reported "only pocket and candle ever show up" is plausible over a short run.

**What needs deciding:**
- Expand the word pool well beyond 4 words so repeats are less likely to be perceptually monotonous even with a fixed seed.
- Decide whether the seed should stay fixed (deterministic, testable, but same sequence every session) or become session-randomized (more variety per run, harder to test deterministically) — a real tradeoff to pick, not just a bug.
- Separately: the field-of-vision picker sub-screen currently uses plain Material buttons rather than the shared input-surface widgets (see §10) — worth folding into the same fix if §10's rule ends up requiring it.

---

## 12. Post-calibration playground — partially exists already, needs verification of what's missing

**Reported:** after finishing setup, the user should get a "playground" to try all input modes before/after using the real app — implying the current build ends at calibration with no way to actually use what was set up.

**Current state — this one does NOT match the code as strongly as the other items.** The app already has:
- A **Preview screen** (`lib/runtime/preview_screen.dart`, `InputPreviewScreen`) — "Your controllers" — lets the user try Buttons/Joystick/Trackpad/Switch/Voice live, with "Simpler"/"Level up" controls and a "Start tasks" button forward.
- A **Demo/runtime screen** (`lib/runtime/demo_screen.dart`) — drives a chain of task shapes through whichever input method the profile resolved to, ending in a "Sent"/done screen with "Run it again"/"Recalibrate."

Both are reachable directly from the calibration results screen ("Use this setup" → Preview → "Start tasks" → Demo) — there is no separate hidden route, and no dead end at calibration results as literally described.

**What the report is likely actually pointing at:** the Demo screen's own end-state text says outright: *"In the full system this is where the agent takes over and fills the real form. Here it stops at the log."* (`demo_screen.dart:269-271`) — i.e., the *task-driving simulation exists*, but it stops short of *real* task execution because the phone↔agent transport is unstarted (consistent with [doc 29](29-phone-desktop-integration.md) and `tech/README.md`). If what was meant is "there's no way to actually operate a real page/app with the calibrated setup," that's accurate and is the same gap doc 29 already tracks — not a missing playground screen, but a missing *real* backend behind the playground that exists.

**Resolved for the original report:** the locked spec's own out-of-scope list (`docs/desgin/ui-ux-phone-flow.md` §8) states "Agent filling a real form / laptop wire" is explicitly out of scope for this build. So the Demo screen stopping at a local log is by design — not a missing playground screen.

**New Playground (planned, [app/04](../app/04-clarity-playground-and-field.md)):** a gear-menu mode picker (2-wide cards with picture + name). Each mode offers Calibration (existing step) or Demo (a simple on-screen options list for that method only). This is additive to Preview, not a replacement.

---

## 13. Deferred by the reporter themselves

- **Microphone/speech input** — explicitly deferred: "we'll think about that later when we integrate all the TTS[/STT]s." No action item here yet.

---

## Summary: what this doc is and isn't

This is an **organized, code-cross-checked record of live feedback**. Every item raised in this doc is now **decided and planned** — each with a filed GitHub issue containing its implementation sketch (see the "Planned, tracked" line under each section) — and `docs/desgin/ui-ux-phone-flow.md` has been updated to match the four spec-level decisions (start gate, Hold reorder, axis defaults, reach-zone placement). **Nothing has been implemented yet** — issues are filed, not started. §13's implementation should sequence with or just after §14 (its progress-feedback dependency), and §11 (input-consistency) should land alongside or after §9 (Hold reorder) since its premise depends on the new step order.

## Issue index

| # | Title | Doc section |
|---|---|---|
| [#5](https://github.com/saranskumar/startathon/issues/5) | Add Start gate screen + restructure Setup screen | §1 |
| [#6](https://github.com/saranskumar/startathon/issues/6) | Simplify calibration entry screen | §3 |
| [#7](https://github.com/saranskumar/startathon/issues/7) | Axis picker: default all axes ON, long-press-to-skip | §4 |
| [#8](https://github.com/saranskumar/startathon/issues/8) | Reword calibration step copy to attempt-based framing | §7 |
| [#9](https://github.com/saranskumar/startathon/issues/9) | Reorder Hold step after Buttons, rescope to per-button | §8 |
| [#10](https://github.com/saranskumar/startathon/issues/10) | Add accessible back-navigation to calibration steps | §9 |
| [#11](https://github.com/saranskumar/startathon/issues/11) | Route Voice/Vision through calibrated input method | §10 |
| [#12](https://github.com/saranskumar/startathon/issues/12) | Vision: session-randomized word pool | §11 |
| [#13](https://github.com/saranskumar/startathon/issues/13) | Redesign Reach step (two-stage confirm, idle-timeout) | §5 |
| [#14](https://github.com/saranskumar/startathon/issues/14) | Build shared timed-feedback primitive | §6 |

**Also outstanding:** the teammate's newer user-flow documentation (referenced in the same conversation that produced this doc) was not yet on `origin/main` as of this writing (`git fetch` showed no new commits) — re-check against that once it lands, since it may already cover some of the same ground from a different angle.
