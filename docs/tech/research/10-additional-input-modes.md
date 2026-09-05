# 10. Additional Input Modes — Beyond Touch/Speech/Switch-Scanning

**Research date:** 5 September 2026
**Scope:** Requested after [20 — Meeting Notes: Input Modes for User Interface](../../idea/20-meeting-notes-input-modes.md), which named finer-grained touch/voice sub-modes (touch-and-hold, pattern swipes, grid-based voice selection, context-predictive text) and asked for wider web research into what other input modes exist. Threads [01](01-input-methods.md) and [02](02-speech-recognition.md) already cover buttons/joystick/trackpad/switch-scanning and speech in depth — this brief covers what's genuinely **not yet researched**: gaze/eye-tracking, head-tracking, sip-and-puff, EMG/muscle sensing, non-invasive BCI, and validates two of the meeting's specific ideas (grid-based voice, sound-count voice vocabulary) against shipped products.

---

## 1. Eye-tracking / gaze input

**State of the art (2025–2026).** Dedicated eye-tracking hardware (Tobii, EyeGaze) has been the AAC/motor-impairment gold standard for years, but the live research frontier is **smartphone-camera-only gaze estimation** — no extra hardware. Recent work (2026) demonstrates on-device gaze estimation from the front camera plus facial-landmark ML models, with compact edge-oriented models feasible on commodity phone hardware. A related line (**GazeSwipe**, arXiv 2503.21094) combines gaze with finger-swipe to extend one-handed touchscreen reach — gaze picks the general region, a swipe refines it, which is structurally the same "coarse channel picks region, fine channel confirms" pattern already used in this project's own coarse-to-fine button fallback (§3.3 of [03 — Input & Calibration](../../idea/03-input-calibration.md)). Dwell-based gaze selection (look-and-wait-to-select, no separate confirm input needed) remains the standard interaction pattern for users with no reliable limb/voice control at all.

**Verdict: Moderate feasibility for this project's scope.** Front-camera gaze tracking without extra hardware is now a credible 2026 research direction, not science fiction, but it needs a calibration step of its own (map gaze to screen coordinates per-user, per-device, per-lighting-condition) and is meaningfully more implementation work than the button/joystick/trackpad trio already scoped. Reasonable as a **fifth candidate input method** for the roadmap (alongside single-switch scanning, §3.5 of the input-calibration doc) rather than event-scope — flag it next to the scanning floor-case as "another answer for the same floor population," since gaze and single-switch scanning target overlapping users (severe motor impairment, no reliable speech).

Sources: [GazeSwipe (arXiv 2503.21094)](https://arxiv.org/pdf/2503.21094); [Bio-Inspired Gaze and Neural Command Fusion for Assistive Smartphone Interaction](https://doi.org/10.3390/biomimetics11070514); [Accelerating eye movement research via accurate and affordable smartphone eye tracking (PMC)](https://pmc.ncbi.nlm.nih.gov/articles/PMC7486382/); [Mind the Gaze: dwell input usability (arXiv 2512.16366)](https://arxiv.org/pdf/2512.16366); [Eye-Tracking Technology for Accessibility and Independence](https://know-the-ada.com/eye-tracking-technology-opening-new-doors-for-accessibility/)

---

## 2. Head-tracking / camera-based head mouse

**State of the art.** Camera Mouse (free, long-established) tracks a facial feature via webcam to move a cursor, used clinically with cerebral palsy and ALS populations. The 2024 successor **CameraMouseAI** (ACM SIGACCESS 2024) adds real-time facial-feature detection and maps additional facial movements (mouth open, eyebrow raise) to discrete click events — i.e. head position for continuous pointing, a second facial gesture for discrete "select," which is the same two-channel split (continuous pointer + discrete confirm) as this project's trackpad-fallback pattern. Both able-bodied and severely motor-impaired adults completed target-selection and web-browsing tasks with it. **GlassOuse** is a shipped commercial hands-free head-mouse (wearable, IR-based) cited as a current product in this space (2025).

**Verdict: Moderate feasibility.** Technically closer to buildable than gaze tracking (head pose from front-camera facial landmarks is a more forgiving/robust signal than pupil-level gaze estimation, and several open computer-vision packages exist for face-landmark tracking), but still a new calibration surface distinct from the three already scoped. Same roadmap placement recommendation as gaze (§1) — a strong **prior-art citation** for "we know what the next input methods to add are and they're validated in the literature," not a build target for the current event scope.

Sources: [CameraMouseAI (ACM SIGACCESS 2024)](https://doi.org/10.1145/3663548.3688499); [Design recommendations for camera-based head-controlled interfaces (Universal Access in the Information Society)](https://link.springer.com/article/10.1007/s10209-013-0326-z); [GlassOuse Hands-Free Mouse — IXD@Pratt](https://ixd.prattsi.org/2025/02/assistive-technology-glassouse-hands-free-mouse/); [Evaluating Camera Mouse for AAC in cerebral palsy — case study PDF](https://aburlab.web.rug.nl/wp-content/uploads/2023/09/Evaluating-Camera-Mouse-as-a-computer-access-system-for-augmentative-and-alternative-communication-in-cerebral-palsy-a-case-study.pdf)

---

## 3. Grid-based voice selection — this already ships in Android Voice Access

This directly validates the meeting's "grid-based voice input" idea ([20 — Meeting Notes](../../idea/20-meeting-notes-input-modes.md)): **Android's built-in Voice Access accessibility service already does exactly this, today, as a shipped OS feature:**

- Say **"show numbers"** → every interactable element on screen gets a numbered overlay; say the number to select it.
- Say **"show grid"** → a numbered grid overlays the whole screen for coarse region selection; say a number to zoom into that region, then a second numbered grid appears over just that sub-region for fine selection (a two-level coarse→fine voice-driven pointing scheme). Say "more squares"/"less squares" to change grid density.

**Verdict: Strong feasibility, and low build risk — because it's not novel.** This isn't a new input mode to invent; it's a well-documented, mainstream, currently-shipping interaction pattern that can be **cited directly as prior art** and cloned conceptually: numbered-element-overlay for discrete-target voice selection, numbered-grid-with-drill-down for free 2D voice pointing without any coordinate math the user has to speak. Recommend treating this as the concrete reference implementation if grid-based voice selection is ever prioritized — no need to design the interaction from scratch.

Sources: [Use Voice Access commands — Android Accessibility Help](https://support.google.com/accessibility/android/answer/6151854?hl=en); [How to use voice control in Android 16 — My Computer My Way](https://mcmw.abilitynet.org.uk/how-to-use-voice-control-in-android-16); [Change Voice Access settings — Android Accessibility Help](https://support.google.com/accessibility/android/answer/6151843?hl=en)

---

## 4. Sip-and-puff switches

**State of the art.** Sip-and-puff (breath-in/breath-out through a tube, translated to switch closures) is decades-old, commercially available AT (Link Assistive, Orin, Rehabmart all sell current 2025 units), standard for high-level spinal-cord-injury and ALS users who retain reliable breath control but no reliable limb movement. Recent research (arXiv 2010.07449) applies sequence-matching algorithms to sip-and-puff streams to extract more than a binary signal — e.g. distinguishing hard-puff vs. soft-puff vs. sip as 3–4 distinguishable "sounds," directly analogous to the meeting's "one sound = yes, two consecutive sounds = no" idea, just on a breath channel instead of a voice channel.

**Verdict: Weak feasibility for this project specifically** — sip-and-puff needs a physical tube/hardware accessory, which is out of scope for a phone-only software build (no hardware attaches to a stock smartphone for this). Worth citing narrowly as **prior art for the general pattern** ("a low-bandwidth binary/ternary physical channel, decoded via sequence/pattern matching, is a validated AAC technique") which directly supports the meeting's proposed voice sound-count vocabulary — same decoding idea, different channel. Not a build candidate; the phone's microphone (voice/VAD) is this project's equivalent low-bandwidth channel already.

Sources: [Sip/Puff Switch — Link Assistive](https://www.linkassistive.com/product/sip-puff-switch/); [Sip and Puff Switch Solutions — Orin](https://www.orin.com/access/sip_puff/); [Intuitive sequence matching algorithm applied to sip-and-puff control (arXiv 2010.07449)](https://arxiv.org/pdf/2010.07449)

---

## 5. EMG (muscle-signal) switches

**State of the art.** A May 2025 feasibility study (Disability and Rehabilitation: Assistive Technology) tested a **dry-sensor EMG switch** against conventional mechanical switches: 5 of 8 participants had *faster reaction times* with the EMG switch than with conventional switches, suggesting EMG is a genuinely competitive, not just alternative, channel for some users. A parallel research thread explores **auricular-muscle EMG** (vestigial ear muscles, separately controllable from facial-nerve-affected muscles) specifically for users with tetraplegia who've lost more common muscle-control sites — evidence the field is actively searching for *any* residual reliably-controllable muscle site, not just hands/face. High-density EMG (arXiv 2312.07745, arXiv 2602.02773) goes further, extracting multiple distinguishable gestures (not just a binary switch) from forearm muscle activity for users with quadriplegia to control robotic manipulators.

**Verdict: Weak feasibility for this project** — needs external EMG sensor hardware (electrodes on skin), not something a stock smartphone provides. Same status as sip-and-puff (§4): a valid roadmap citation ("residual-muscle-signal switches are an active, evidence-backed AT category, in case a future hardware partnership is relevant") but not phone-software buildable. Note for completeness: consumer EMG wristbands (e.g. Meta's Orion/CTRL-labs-derived wristband research, not directly searched here but publicly known) are trending toward consumer hardware, which could change this verdict in a 1–2 year roadmap horizon, not for this event.

Sources: [Exploring electromyography for assistive technology: dry sensor EMG switch feasibility study (Disability and Rehabilitation: AT, 2025)](https://www.tandfonline.com/doi/full/10.1080/17483107.2025.2501746); [High-density EMG for gesture-based control of assistive manipulators (arXiv 2312.07745)](https://arxiv.org/pdf/2312.07745); [Bimanual High-Density EMG Control for In-Home Mobile Manipulation (arXiv 2602.02773)](https://arxiv.org/pdf/2602.02773)

---

## 6. Non-invasive brain-computer interfaces (BCI)

**State of the art (2026).** Non-invasive BCI is a real and fast-growing market ($19.6B neurotechnology market projected for 2026, BCI segment growing >16%/year) but still squarely **research/clinical-trial territory for actual device control**, not consumer-shippable input for a general app. Consumer EEG headsets (Emotiv, Muse, $300–3,000) reliably detect coarse states — attention, relaxation, cognitive load — via skull-surface EEG, which is a much lower-bandwidth, noisier signal than the discrete-command-level control this project's task shapes need (discrete choice / continuous adjust / free pointing). Two active `clinicaltrials.gov` studies (NCT05183152, NCT02071485) confirm non-invasive BCI-controlled assistive devices and virtual-object control are active research, not shipped consumer products. One 2026 paper (§1's "Bio-Inspired Gaze and Neural Command Fusion") specifically fuses EEG-based BCI commands *with* gaze tracking on a smartphone — i.e. even the research combining BCI with phone-based interaction treats BCI as a coarse secondary signal fused with a primary channel (gaze), not a standalone precise input method.

**Verdict: Weak feasibility, correctly excluded from build scope.** BCI is the right thing to name in a pitch as "the direction the whole field is heading, and our capability-profile architecture is built to accommodate a new input channel like this without a redesign" — i.e. cite it as validating the *extensibility* of the profile-driven approach (any new modality just becomes another calibratable axis with a score), not as something to attempt this event. No consumer-grade, phone-compatible, discrete-command BCI product exists to integrate against today.

Sources: [Non-invasive BCI-controlled Assistive Devices — ClinicalTrials.gov NCT05183152](https://clinicaltrials.gov/study/NCT05183152); [Non-Invasive Brain-Computer Interface for Virtual Object Control — ClinicalTrials.gov NCT02071485](https://clinicaltrials.gov/study/NCT02071485); [Bio-Inspired Gaze and Neural Command Fusion for Assistive Smartphone Interaction](https://doi.org/10.3390/biomimetics11070514); [BCI 2026: Non-Invasive Revolution](https://arslanemre.com/blog/bci-2026-non-invasive-revolution)

---

## 7. Cross-cutting pattern: coarse-channel-picks-region, fine-channel-confirms

Nearly every input mode surveyed here and in [thread 01](01-input-methods.md) converges on the same two-stage shape once precision is limited:

| Mode | Coarse stage | Fine/confirm stage |
|---|---|---|
| Android Voice Access grid (§3) | Say a grid-square number | A sub-grid appears; say the sub-square number |
| GazeSwipe (§1) | Gaze picks general region | Finger swipe refines exact target |
| CameraMouseAI (§2) | Head position moves cursor | Facial gesture (mouth/eyebrow) confirms click |
| This project's button fallback (§3.3, [03 — Input & Calibration](../../idea/03-input-calibration.md)) | Pick a quadrant | Pick a sub-zone, then confirm |
| Sip-and-puff sequence matching (§4) | A puff/sip pattern | Matched against a known sequence library |

This is worth stating explicitly as a design principle in whichever doc ends up owning the interaction-pattern catalog: **any new input mode added to this project's calibration system should be decomposed into a coarse-selection signal plus a discrete-confirm signal**, matching the pattern every one of these prior-art systems independently converged on. It's also exactly what the existing §3.3 fallback matrix already does for buttons/joystick/trackpad — this cross-cutting research confirms that design choice generalizes cleanly to gaze, head-tracking, and grid-voice if any are added later.

---

## 8. Follow-up: the four calibration-primitive gaps flagged as "not yet researched" in [20 — Meeting Notes](../../idea/20-meeting-notes-input-modes.md)

The meeting named four specific additions to §3.1's calibration test set that weren't covered by threads 01/02 or §1–7 above. Researched here individually.

**Touch-and-hold as a distinct calibration primitive.** Both Apple ("Touch Accommodations" → Hold Duration) and Android ("Touch & hold delay," Settings → Accessibility) already ship this as a **user-adjustable timing threshold** (0.25s–5s on iOS), because a fixed system default can't reliably distinguish a motor-impaired user's tap from a hold. This directly validates adding touch-and-hold to calibration: the test is simply measuring how long a user needs to hold before a press registers as "held" rather than "tapped," the same shape as the existing button/joystick/trackpad reach-a-target tests. WCAG 2.2 and general mobile-accessibility guidance also converge on the opposite lesson: **every long-press/hold action should have a non-hold alternative** (a visible button doing the same thing) — so touch-and-hold, if added, should be treated as an optional accelerator for users who can reliably produce it, never the only path to an action. **Verdict: Strong feasibility** — a per-user hold-duration threshold is a one-parameter calibration (find the shortest hold time the user can reliably produce above the false-positive floor), consistent with how both major mobile OSes already solve this.

**Pattern swipes / gesture sequences, and per-axis (X-only/Y-only) swipe capability.** Academic research (Wobbrock et al., "Stroke-Gesture Input for People with Motor Impairments," ~9,600 gestures across 70 participants) finds **stroke-gestures (drawn shapes/sequences) are a viable input modality for motor-impaired touchscreen users** — real, if niche, empirical support for the meeting's "left-then-up, left-then-down" pattern-swipe idea. The far stronger and more consistently repeated signal across sources, though, is the opposite caution: **WCAG 2.2's path-based/multipoint gesture success criterion requires every such gesture to have a single-point equivalent**, because path-based and multi-touch gestures are named repeatedly (Access Guide, TestParty, EZUD) as one of the most common motor-accessibility failures in real apps — precisely because they demand the compound fine-motor control (direction + timing + path shape) that this project's whole capability-profile premise says can't be assumed uniform across users. No source found treats *per-axis-limited* swiping (X-only vs. Y-only capability) as a named, pre-built calibration test anywhere — it's a reasonable, novel-but-small extension of the existing trackpad calibration (§3.1), not something to adopt from prior art. **Verdict: Moderate feasibility, framing matters** — pattern swipes are legitimate as an *optional, high-bandwidth accelerator* for users who test well on them, exactly mirroring this project's own ideal/fallback design (§3.3), but should never be a task's *only* path, per WCAG's repeated point; per-axis swipe scoring is buildable (just tag calibration attempts by which axis moved) but has no existing implementation to crib from.

**Sound-count voice vocabulary (upgrading the `sounds` tier from binary presence to "one sound = X, two sounds = Y").** This searched weakly — no accessibility-specific product or paper was found using this exact scheme. What *does* exist, and is directly reusable, is standard **VAD burst-counting**: production voice-activity-detection engines already track a running "burst count" of consecutive speech-active frames as part of their normal hangover/debounce logic (i.e., counting how many separate vocalization events occur in a window is a solved, already-implemented sub-problem inside the same VAD libraries thread 02 already recommends — `vad`/Silero, WebRTC VAD — not a new capability to build). The gap is purely on the *interpretation* side (mapping "1 burst" → yes, "2 bursts" → no), which is simple sequential logic on top of existing burst-count output, not new signal-processing. **Verdict: Strong feasibility** — this is a small enrichment of the VAD pipeline already scoped in [02 — Speech Recognition](02-speech-recognition.md) §4, not a new research area; the main design risk is tuning the inter-burst gap window so two quick sounds aren't merged into one, which is the same debounce-tuning problem switch-scanning already has (§1 of this doc's companion thread 01).

**Context-predictive text with minimal (yes/no-equivalent) confirmation.** This is a well-established AAC technique, not a novel idea: word-prediction in AAC systems is decades-studied (predictive scanning input systems date to patents from the 1990s), and current commercial AAC apps (e.g. **Predictable**) already combine word prediction with switch/scan-based selection and auditory preview — i.e. the exact "predict, then confirm via the lowest-bandwidth channel available" pattern the meeting described. The literature also flags a real tradeoff worth carrying into any design: prediction can *increase* rather than decrease interaction time, because scanning/reviewing a prediction list has its own overhead — savings aren't automatic just because fewer characters are typed. This is the same shape of problem already flagged as a Dasher-adjacent gap in [07 — Dasher Integration](07-dasher-integration.md) (free-text entry for users with neither reliable speech nor reliable tapping) — the two should be read together rather than researched as separate features. **Verdict: Strong feasibility as a concept** (decades of AAC prior art), **Moderate feasibility for this project's scope** (the prediction-list-scanning-overhead tradeoff needs to be designed around, not just assumed away) — roadmap item, consistent with Dasher's existing roadmap placement, not new build scope.

---

## Summary verdicts

| Input mode | Buildable this event? | Recommended treatment |
|---|---|---|
| Eye-tracking / gaze (front camera) | No | Roadmap — 5th/6th calibratable input method, cite GazeSwipe/dwell-input research |
| Head-tracking (front camera) | No | Roadmap — same tier as gaze, cite CameraMouseAI |
| Grid-based voice selection | Maybe, if voice-filter UI is extended | **Clone Android Voice Access's shipped pattern directly** rather than designing from scratch |
| Context-predictive text + minimal confirm | No (already flagged as Dasher-adjacent gap) | Roadmap, see [07 — Dasher Integration](07-dasher-integration.md) |
| Sound-count voice vocabulary ("sounds" tier upgrade) | Possibly small — reuses existing VAD pipeline | Cheap extension of [02 — Speech Recognition](02-speech-recognition.md) §4's VAD work: count vocalization bursts instead of just detecting presence |
| Sip-and-puff | No — needs external hardware | Citation only |
| EMG switches | No — needs external hardware | Citation only |
| Non-invasive BCI | No — not consumer-shippable yet | Citation only, validates architecture extensibility |
| Touch-and-hold calibration | Yes — one-parameter threshold test | Cheap addition to §3.1, mirrors iOS/Android's own hold-duration settings |
| Pattern swipes / per-axis swipe | Optional accelerator only | Never the sole path to a task (WCAG path-gesture caution); per-axis scoring is a small tag added to existing trackpad calibration |
| Sound-count voice vocabulary | Yes — reuses existing VAD burst-count | Small enrichment of [02](02-speech-recognition.md) §4's VAD pipeline, not new research |
| Context-predictive text + confirm | No — real prediction-overhead tradeoff to design around | Roadmap, read alongside [07 — Dasher Integration](07-dasher-integration.md) |

---

## Sources

- [GazeSwipe: Enhancing Mobile Touchscreen Reachability through Seamless Gaze and Finger-Swipe Integration — arXiv 2503.21094](https://arxiv.org/pdf/2503.21094)
- [Bio-Inspired Gaze and Neural Command Fusion for Assistive Smartphone Interaction — Biomimetics](https://doi.org/10.3390/biomimetics11070514)
- [Accelerating eye movement research via accurate and affordable smartphone eye tracking — PMC7486382](https://pmc.ncbi.nlm.nih.gov/articles/PMC7486382/)
- [Mind the Gaze: Improving the Usability of Dwell Input — arXiv 2512.16366](https://arxiv.org/pdf/2512.16366)
- [Eye-Tracking Technology for Accessibility and Independence — Know the ADA](https://know-the-ada.com/eye-tracking-technology-opening-new-doors-for-accessibility/)
- [Demonstration of CameraMouseAI — ACM SIGACCESS 2024](https://doi.org/10.1145/3663548.3688499)
- [Design recommendations for camera-based head-controlled interfaces — Universal Access in the Information Society](https://link.springer.com/article/10.1007/s10209-013-0326-z)
- [GlassOuse Hands-Free Mouse — IXD@Pratt](https://ixd.prattsi.org/2025/02/assistive-technology-glassouse-hands-free-mouse/)
- [Evaluating Camera Mouse as a computer access system for AAC in cerebral palsy — case study PDF](https://aburlab.web.rug.nl/wp-content/uploads/2023/09/Evaluating-Camera-Mouse-as-a-computer-access-system-for-augmentative-and-alternative-communication-in-cerebral-palsy-a-case-study.pdf)
- [Use Voice Access commands — Android Accessibility Help](https://support.google.com/accessibility/android/answer/6151854?hl=en)
- [Change Voice Access settings — Android Accessibility Help](https://support.google.com/accessibility/android/answer/6151843?hl=en)
- [How to use voice control in Android 16 — My Computer My Way](https://mcmw.abilitynet.org.uk/how-to-use-voice-control-in-android-16)
- [Sip/Puff Switch — Link Assistive](https://www.linkassistive.com/product/sip-puff-switch/)
- [Sip and Puff Switch Solutions — Orin](https://www.orin.com/access/sip_puff/)
- [Intuitive sequence matching algorithm applied to a sip-and-puff control interface — arXiv 2010.07449](https://arxiv.org/pdf/2010.07449)
- [Exploring electromyography for assistive technology: dry sensor EMG switch — Disability and Rehabilitation: AT (2025)](https://www.tandfonline.com/doi/full/10.1080/17483107.2025.2501746)
- [High-density Electromyography for Effective Gesture-based Control of Assistive Manipulators — arXiv 2312.07745](https://arxiv.org/pdf/2312.07745)
- [Bimanual High-Density EMG Control for In-Home Mobile Manipulation — arXiv 2602.02773](https://arxiv.org/pdf/2602.02773)
- [Non-invasive BCI-controlled Assistive Devices — ClinicalTrials.gov NCT05183152](https://clinicaltrials.gov/study/NCT05183152)
- [Non-Invasive Brain-Computer Interface for Virtual Object Control — ClinicalTrials.gov NCT02071485](https://clinicaltrials.gov/study/NCT02071485)
- [BCI 2026: Non-Invasive Revolution — Arslan Emre](https://arslanemre.com/blog/bci-2026-non-invasive-revolution)
- [Use Touch Accommodations with your iPhone, iPad, iPod touch, or Apple Watch — Apple Support](https://support.apple.com/en-us/102222)
- [Touch & hold delay — Android Accessibility Help](https://support.google.com/accessibility/android/answer/6006989?hl=en)
- [Designing for Motor Impairments — EZUD](https://ezud.com/designing-for-motor-impairments/)
- [Use single-pointer gestures (instead of path-based gestures) — Access Guide](https://www.accessguide.io/guide/single-pointer-gestures)
- [Stroke-Gesture Input for People with Motor Impairments: Empirical Results & Research Roadmap — ACM](https://dl.acm.org/doi/fullHtml/10.1145/3290605.3300445)
- [Mobile Patterns that Break (and Make) Accessibility — TestParty](https://testparty.ai/blog/mobile-accessibility-patterns)
- [Word prediction and communication rate in AAC — ResearchGate](https://www.researchgate.net/publication/228915903_Word_prediction_and_communication_rate_in_AAC)
- [User Interaction with Word Prediction: The Effects of Prediction Quality — ACM TACCESS](https://dl.acm.org/doi/abs/10.1145/1497302.1497307)
- [Predictable — AAC app with word prediction + scanning](https://mwm.ai/apps/predictable-dansk/491326737)
