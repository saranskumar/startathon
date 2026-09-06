# KAI — Scope for judges

**Product:** KAI (Capability Awareness Interface).  
**What it is:** a phone that *measures* a person (not a disability label) and then operates a task using only the residual abilities that measurement found.  
**What it is not:** an AI assistant, a screen reader replacement, or a finished product that already runs on WhatsApp / IRCTC / a live third-party app.

This file is the honest contract for the demo and Q&A. Older docs in `docs/` still contain superseded plans (OpenClaw, an LLM fallback, “phone is not wired,” a required Google Form). **This file wins** when they disagree.

---

## How to read this

| Label | Meaning |
|---|---|
| **Real** | Built, runs in the demo, and does what we say it does. |
| **Mock / simulated** | Built enough to show the interaction, with a stand-in behind it. Say this out loud; do not imply the stand-in is the real thing. |
| **Working half, not yet connected** | Real on its own machine; not what the phone is driving today. |
| **Planned** | Next work after this event. Do not demo as shipped. |
| **Out of scope** | We are not building this, and we will not claim it. |

---

## The one-sentence claim we can stand behind

KAI can **measure** a capability profile and **reshape the same task** around it — including fusing imprecise touch with partial voice — with **no AI/LLM in the path**. A phone can then **drive a self-built mock website** (RailLink) through a live WebSocket. A separate desktop engine can **rank a real webpage’s accessibility tree** and click it. Those two desktop paths are **not the same path**.

---

## What judges will actually see

Three pieces, two of which can be live:

1. **Flutter phone app** (`code/app`) — calibration → profile → adaptive controllers → tasks. This is the product.
2. **Aperture Daily / RailLink** (`code/mock`) — self-built everyday websites. **RailLink is the live phone target.** The phone’s Live screen sends `focus` / `act`; the laptop page really fills fields and clicks buttons.
3. **Desktop inspector** (`code/desktop`, `npm run ui`) — Playwright + a heuristic DOM ranker + a Dasher-style zooming navigator. Shown on request as the “page reduction” half. **The phone does not drive this.**

**Primary demo:** phone calibration (or a named preset) → one complete task, then (if time) Live → RailLink booking.  
**Secondary, if asked:** open the inspector on a mock (or any URL) and show ranking + one Playwright click.  
**Not in the demo:** a real Google Form, WhatsApp, IRCTC, or any live third-party login.

---

## Real — built and working

### Phone: measurement and runtime

- **Start gate** — first action is tap or hold anywhere. Nothing harder than that.
- **Setup** — helper path, high contrast, language chip, and demo presets live *outside* the thumb-reach start block.
- **Caregiver training** — prompt fading (together → start-together-finish-alone → from the words alone). No scores. Skip-all always available.
- **Axis-gated calibration** — Motor / Speech / Vision. Order when all on: reach → buttons → joystick → trackpad → hold → voice → vision. Every step is skippable (**skip = untested, never failed**). Idle auto-skip; three idle skips jump to a forgiving leftover setup.
- **Live draft** — after each test the partial profile already sizes/themes the next screen.
- **Capability profile as a runtime object** — method scores, reach zone, target size, stick home, output row, option cap, dwell, text scale, visual field, voice clarity, personal vocabulary, contrast, locale. **There is no `ProfileAScreen`.** Presets A / B / Floor skip measurement on purpose for the room; live calibration produces the same object.
- **Score formula** — `0.5·success + 0.3·(1−time) + 0.2·(1−error)`. Relative fallback: use the task’s ideal method unless another scores ≥ **0.12** higher, then use that method’s *own* pattern (not a shrunken copy of the ideal widget).
- **Full 4 task shapes × 4 methods** — discrete / continuous / pointing / text × buttons / joystick / trackpad / switch-scan. Switch-scan is first-class (the floor case), not a slide.
- **Touch + voice fusion on text** (Thesis B) — touch selects the field; voice fills or confirms. Partial speech always confirms. `sounds` is still a vocabulary (one pulse = yes, two = next), not “no voice.”
- **Confirmation + interrupt** — no consequential send without confirm, using the user’s measured method. Interrupt resets **this step**, not the profile.
- **Vision** — shrinking-word forced choice (not “can you see this?”); field = full / tunnel / peripheral is **recorded** in the profile. Tunnel/peripheral overlay is **removed for now**; real tunnel layout (all controls inside one square) is further scope. See [docs/app/04](docs/app/04-clarity-playground-and-field.md).
- **High contrast** — a peer palette (black / white / yellow), not a dark-mode skin. Also follows the OS high-contrast flag. Default on.
- **Output strip** — lives on the least-reachable row. Named haptics (navigate / confirm / error).
- **Flutter semantics** — live regions and announcements so TalkBack / VoiceOver hear selection changes.

### Phone → laptop (the *authored* path)

- **WebSocket relay** (`code/desktop` `npm run relay`, or the Cloudflare Worker for `wss://`) — two clients join a room: mock page and phone.
- **Live screen on the phone** — renders the page’s current interaction list through the *same* calibrated surfaces (buttons / joystick / trackpad / switch / voice). Confirm-before-pay is enforced on the phone *and* refused by the page if `confirm` is missing.
- **Real DOM mutations on RailLink** — `act` sets input values or calls `element.click()`. The ticket flow on screen is not a screenshot.

### Desktop: page ranking (the *parsed* path)

- Playwright Chromium reads the **accessibility tree**.
- **`domTreeEngine.js`** ranks navigation vs information with a hand-tuned heuristic. No LLM. Every score expands into the terms that produced it. Every dropped node has a `prunedBecause`. Ambiguous pages get a banner instead of a silent guess.
- Overflow packs into groups; page chrome is penalised; usage counts boost previously picked features (a frequency table, not a trained model).
- **`/api/act`** dispatches a real Playwright click / fill / check / select.
- **Dasher-style zooming navigator** — one continuous axis; box size is predicted probability; confirm is a second box. Text fields open an order-0 letter-frequency alphabet.
- **Rescan only when the page actually changed** (History API + MutationObserver fingerprint).

### Positioning that is locked, not aspirational

- **Zero AI / LLM anywhere** — calibration, mapping, vocal classifier, ranking, and dispatch are all deterministic.
- **Browser pages only** for this event — not native OS apps.
- **Open source, no revenue model** — public-good positioning. Not a pitch-slide beat; true if asked.

---

## Mock / simulated — say this out loud

| Piece | What is real | What is the stand-in |
|---|---|---|
| **Speech recognition** | Hold-to-speak timing, burst counting, clarity tiers, confirm gate, vocab mapping | `SimulatedSpeechSource`. The voice step has a **SIMULATED RECOGNISER** panel so any tier can be forced on stage. We do **not** claim a dysarthria-tuned model. |
| **Onboarding audio** | Timed transcript + screen-reader announcement in English and Malayalam | No WAV files yet. Catalog only. Locale does **not** translate the rest of the UI. |
| **Aperture Daily** | Real local HTML/JS sites with dense, awkward chores (trains, pay, civic, clinic, shop, mail) | Self-built. Not IRCTC, not GPay, not WhatsApp. Hub copy says so: “Mock · nothing is sent anywhere.” |
| **RailLink live demo** | Phone really drives the page; clicks and fills really happen | The **list of interactions is hand-authored** (`code/mock/interactions.js`). The demo does **not** parse the page to discover controls. Regions (“top bar” / “main”) are authored, not derived from ARIA landmarks. |
| **In-app task chain** (Preview → tasks, no Live) | Full 4×4 matrix, fusion, confirm, interrupt | Intents stop at the on-screen output strip. This path never leaves the phone. |
| **Demo presets A / B / Floor** | Same `CapabilityProfile` object the live tests produce | They **skip measurement** so the room is not hostage to a two-minute calibration. Say that if you use them. |
| **Text suggestions** | Fusion UI, confirm, `sounds` yes/next | Fixed phrase list, not next-word prediction. |
| **Dasher letter model** | Zooming + confirm-box + fill via `/api/act` | Order-0 English letter frequencies, not Dasher’s full language model. |
| **Usage-count ranking boost** | Real file, real increment on pick | Frequency standing in for “an ML model, not an LLM.” No training data. |
| **`form.html`** | A dense equal-importance form for the ranker | Stand-in for a Google Form. **Not** a live Google Form. |

---

## Working halves that are not yet the same system

This is the most important distinction in Q&A.

| Path | What it does | Phone attached? |
|---|---|---|
| **Relay + authored map** (`npm run relay`, RailLink + overlay) | Demo the calibrated input layer on a known chore | **Yes** |
| **Inspector + DOM engine** (`npm run ui`) | Demo that a *generic* page can be reduced without AI | **No.** Backend WebSocket (`/phone`) and `scanTree` / `regions` exist on the desktop; the Flutter client of *that* contract is not what Live uses. |

Do **not** say “the phone ranks the live accessibility tree.”  
Do **say** “the phone drives a page we authored a map for; the ranker is a separate, working engine we can show on the laptop.”

Also not connected yet:

- Phone intents → Playwright `session.act`
- Grid-based voice / switch-scan over a *live* ranked feature list (`scanTree.js` is desktop-only)
- Landmark-derived region highlighting on the phone
- TTS of `describeRegions()` / `scanTree.describe()`

---

## Planned — after this event, not this demo

**Next tests (highest leverage)**

- Put KAI in front of the person who inspired it. Observational evidence already changed the architecture (drop AI). Formal beta of the *built* app has **not** been done.
- Swap `SimulatedSpeechSource` for a hosted recognizer behind the existing `SpeechSource` interface. That needs a Flutter plugin; this build stayed almost SDK-only. We will not train a personal ASR in this event.
- Wire the phone to the **parsed** path (Playwright + `domTreeEngine`), so authored maps are no longer required.

**Product / input (researched, not built)**

- Real TTS / proactive narration for `vision = none` (large text + field masks *are* built).
- Profile persistence across app kill (session-only today; relay host/room *are* remembered).
- Local predictive keyboard (n-gram / frequency — **not** an LLM).
- Distinct tone/hum vocabulary (today `sounds` is burst-*count* only).
- Grid-spoken numbers (Android Voice Access already ships this pattern).
- Pattern swipes, flicks, double-tap as a distinct gesture.
- Camera head-tracking, sip-and-puff, gaze, EMG, non-invasive BCI — phone doesn’t have that hardware; the *meaning* of a short yes-pulse is already the `sounds` nod.
- Full Malayalam UI (clips only).
- More mock worlds on the Live wire (only RailLink authors an interaction map today).
- Expo/React Native port of the input layer (`docs/app/03-expo-port.md`) — Flutter remains the running demo.

**Surfaces**

- Ordinary third-party websites as the phone’s target (not only our mocks).
- A real Google Form as a judge-requested secondary — **specified, not built.**
- Native OS app control (Windows UI Automation / macOS AX / Linux AT-SPI) — explicit non-goal for this event.
- Phone as a standalone accessibility shell (not a remote to a laptop).

---

## Out of scope — do not claim

| Claim | Reality |
|---|---|
| “This is an AI product” / “an LLM picks the UI” | **No AI.** Task-to-ideal mapping is fixed at design time (FR17). Ranking is a heuristic. We dropped OpenClaw (overhead, security, latency). |
| “It already works on WhatsApp / the user’s real apps” | Mocks only. Independence beyond WhatsApp is the *hypothesis*, not the measured result. |
| “Speech recognition works for dysarthria” | Interaction is real; the recognizer is simulated. |
| “We narrate the screen like a smarter TalkBack” | Not built. |
| “Phone and desktop ranking are one live loop” | Two halves. Authored RailLink loop is live; parsed loop is laptop-only. |
| “We control native desktop apps” | Browser tree only. |
| “We tested this with the user” | Direct observation informed the problem. Formal use of the built app is planned, not done. |
| “Skip means they failed the test” | Skip means untested. |
| “Profile Floor is unsupported” | Switch-scan + sounds is implemented. Tunnel overlay deferred (not shown). |
| “High contrast is the haiku theme” | Haiku is identity (yellow/blue/pink blend). High contrast is the legibility floor. |
| “Nods are camera head-tracking” | Duration + burst count on hold-to-speak. |

Screen-reader users with **full motor** are **de-emphasized on purpose**. A mature screen reader already serves that point. Value is **combinations** those tools miss.

---

## What this event is meant to prove vs. what is still unproven

| Thesis | Status |
|---|---|
| **A — Spectrum.** Measure coordinates, don’t pick a disability bucket. | **Shown.** Live calibration + presets land on the same profile object; A → B → Floor reshape the same task. |
| **B — Fusion.** Imprecise touch + partial voice beat either alone. | **Shown as UI.** Text task fuses them. Recognizer is simulated, so we have not proven recognition quality. |
| **C — Task-aware method.** Ideal input unless a better-scoring method wins, then that method’s native pattern. | **Shown.** Ribbon on every task states *why this method*. Full matrix is built, not just the demo cells. |
| **Page reduction without an agent.** | **Shown on the laptop.** Not yet the phone’s live target. |
| **The user completes more real-world tasks independently.** | **Unproven.** That is the next-week test. |

---

## Safe answers (short)

**“Is the speech real?”**  
The hold, the bursts, the confirm, and the vocabulary mapping are real. The transcript is simulated so the room’s microphone is not the demo.

**“Can they use their WhatsApp?”**  
Not yet. RailLink is our mock of a dense everyday chore. The ranking engine can already open a real URL on the laptop; the phone is not pointed at that engine yet.

**“Why not an LLM?”**  
We assumed we would need one. The bottleneck is mapping a large app onto a small reliable input set. Assistant is already an AI and already fails this user. Deterministic ranking is auditable and free to run.

**“What about someone who can’t use buttons, stick, or pad?”**  
Single-switch scanning is in the same matrix (Profile Floor). Dwell comes from measured steadiness.

**“Isn’t this just big buttons / Voice Access / TalkBack?”**  
Those each need **one complete channel**. We compose residuals, including a floor that is still an answer.

---

## Code map (if a judge asks where it lives)

| Path | Role |
|---|---|
| `code/app/` | Phone: calibration, profile, runtime, Live client |
| `code/mock/` | Aperture Daily. Only `rail.html` loads the Live overlay |
| `code/desktop/src/relay.js` | Phone ↔ mock WebSocket (demo path) |
| `code/desktop/relay-cf/` | Hosted `wss://` relay (Vercel cannot hold the socket) |
| `code/desktop/src/domTreeEngine.js` | Heuristic ranker (inspector path) |
| `code/desktop/src/phoneTransport.js` | Unused-by-Flutter `/phone` socket for the *parsed* path |
| `docs/` | Product record. This file is the judges’ overlay on top of it |

The spoken demo script and “say this on screen” one-liners live in `presentation/notes/demo-clips.md` and `features-for-judges.md`. They must stay consistent with **this** file, not with older idea docs.
