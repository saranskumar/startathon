# 09. Vision Calibration — Research

Resolves the open question in [09-open-questions.md](../../idea/09-open-questions.md): "How exactly is vision calibrated?" — for the `vision.mode: screen | large | none` field in the capability profile ([02-core-model.md](../../idea/02-core-model.md) §2.3), following the pattern set by the touch (§3.1) and speech (§3.1) calibration tests in [03-input-calibration.md](../../idea/03-input-calibration.md).

---

## 1. Existing quick digital vision-screening tests

Real clinical/consumer tools do this on a bare phone screen, no extra hardware:

- **Peek Acuity** (Android) — tumbling-E optotype test. User points which way the E's arms face; the tester (or, in self-test variants, the user) swipes to answer; letter shrinks each correct answer until threshold is found. Validated against physical Snellen charts in a Kenyan field trial (233 people, home + clinic) — accuracy statistically equivalent, ~77s average vs. 82s for a paper chart.
- **WHOeyes / V@home** — uses the front camera to measure face-to-screen distance in real time (automatic distance calibration) so optotype size can be converted to a true visual-acuity value regardless of how far the phone is held. Also auto-maxes screen brightness and checks contrast before starting.
- **K-CS / PeekCS / Aston contrast sensitivity app** — smartphone contrast-sensitivity tests (distinct from acuity: tests ability to distinguish low-contrast patterns, relevant for functional vision, ~44.6s test time). Existence proves the pattern generalizes to more than sharpness.
- **OS-level onboarding (iOS/Android):** neither runs a diagnostic test during first-run setup. iOS's Quick Start / Accessibility setup screen just lets the user *toggle on* known features (VoiceOver, Zoom, larger text) by name — it presumes the user (or a person setting up the phone for them) already knows they need it. Android's Accessibility Suite is the same: TalkBack/Switch Access are opted into via Settings, not diagnosed. **No major OS asks a functional "can you see this" screening question at all** — they all delegate to explicit feature selection.

**Verdict: Moderate feasibility.** The clinical apps prove a real threshold test is fast (well under 90s) and accurate, but they lean on camera-based distance calibration and multi-step optotype protocols that are overkill for a 30-hour build — and reproduce diagnostic acuity (20/20 etc.), not the 3-bucket functional output this project needs. The OS precedent is actually a point *against* building an active test: real shipped products settle for self-selection, not measurement.

---

## 2. Shrinking-text / minimum-readable-size test — prior art and implementation

Direct academic prior art: the **MNRead test** (Minnesota Low Vision Reading Test) — sentences of controlled length shown at progressively smaller sizes to find "critical print size," the smallest size at which maximum reading speed is sustained. This is exactly the shrinking-text pattern the project's docs already gesture at, just formalized. Key finding relevant to this project: **acuity threshold (smallest size the user can technically resolve) is not the same as functional/comfortable reading size** — a user can *read* an 8pt letter under test conditions but not sustain real use at that size. This matters because the project wants a UI-sizing decision, not a lab measurement.

Standards note: the American Printing House for the Blind's 18pt-minimum guidance and the common "16px/12pt digital floor" both suggest reasonable anchor points for a step range.

**Reasonable implementation for this project:**
- Show one short word or a 3–4 word phrase (not a full sentence — keeps it a 10-second interaction), starting large (~48–56px, unambiguously readable at arm's length) and stepping down (e.g. ~40px → 32px → 24px → 18px → 14px) — 4–5 steps.
- At each step ask the user to confirm they can read it — but **this is exactly where it collides with the touch-calibration problem the docs already flag**: if the confirm action is a tap, a user with poor touch precision might fail to hit "yes" not because they can't read the text, but because they can't hit the button. Mitigations:
  1. Run vision calibration *after* touch calibration so the confirm control can already be sized to the user's calibrated `min_target_size` — reuse the touch profile rather than assume a fresh target size.
  2. Use a single full-width tap-anywhere-to-confirm zone (largest possible target, effectively immune to precision issues) rather than a small button.
  3. Offer the `sounds` speech tier (binary vocalization-as-confirm, per §3.1) as an alternate confirm channel if speech calibration already ran and produced a usable tier.
- Stop stepping down at the first size the user fails to confirm (or times out on); map the last successfully-confirmed size to a bucket (see §4/§5 below for the 3-tier mapping).
- Must be timeboxed and skippable per the project's own non-functional requirement (08-requirements.md §8.2) — a hard timeout per step (e.g. 5s) with a "next" auto-advance handles a non-responsive step without hanging the flow.

**Verdict: Strong feasibility** for a stripped-down version (word-level, few steps, reusing already-calibrated touch target size), **Weak feasibility** for a faithful MNRead-style implementation (needs controlled sentence sets, more steps, more time than a hackathon calibration flow should spend).

---

## 3. Simpler proxy signals

**Direct question ("can you read normal-size text on this screen? yes / no / not sure")** — essentially what the OS-level flows above actually do (feature self-selection). Tradeoffs:
- Much faster (~2 seconds vs ~10–20 seconds for a shrinking-text run).
- No dependency on the confirm-input precision problem — though it *still* requires the user to be able to operate whatever selects yes/no/not sure, i.e. it doesn't fully dodge the touch-calibration interaction, just reduces how many times it happens (1 confirm instead of 4-5).
- Self-report is known to be unreliable for functional vision specifically because people compensate/adapt and misjudge their own reading ability (this is exactly why MNRead-style critical-print-size testing exists in the clinical literature instead of just asking patients) — but for a 3-bucket coarse decision (not a diagnostic acuity number), self-report is plausibly "good enough."
- A "not sure" bucket is useful precisely because it gives a legitimate escape hatch into a fallback (default to `large`, or trigger the active test as a tiebreaker only when the user picks "not sure") — hybrid design, see §5.

**Passive observation during touch calibration** (does the user hesitate on dense screens, ask for targets to be described, etc.) — theoretically appealing (zero extra calibration time) but:
- Requires building signal-detection logic (hesitation timing thresholds, dense-vs-sparse screen variants) that doesn't exist anywhere else in the calibration design — this is *more* engineering than either of the other two options, not less.
- Confounds vision with motor/cognitive hesitation — the touch test is deliberately measuring precision/speed of *targeting*, and reusing its timing data to infer vision risks polluting both measurements' interpretability at demo time (bad for a live judged demo where the presenter needs to explain *why* a bucket was assigned).

**Tradeoff summary for a hackathon build:** an active measured test buys credibility ("we don't just self-report vision" mirrors the pitch's own touch/speech design ethos) and a small amount of real signal beyond self-report, at a cost of ~10-20s more calibration time and one more screen to build/debug/timebox. A direct question is faster and lower-risk to build but is inconsistent with the project's own stated design principle that vision, like touch and speech, should be *measured* — the project's docs (03-input-calibration.md) explicitly frame touch and speech as measured tests and only flag vision as unresolved *because* a pure self-report felt like it broke that pattern.

**Verdict: Strong feasibility** for either simpler proxy individually; **Weak feasibility** for the passive-observation idea specifically (real signal-engineering cost with no existing infra to reuse).

---

## 4. How real accessibility tools bucket vision (for comparison / credibility)

- **WHO ICD-11** uses a formal multi-tier scale by best-corrected visual acuity: no impairment (≥20/40) → mild (20/40–20/70) → moderate (20/70–20/200) → severe (20/200–20/400) → blindness (further sub-tiers down to no light perception). This is a 4–6 tier clinical scale, more granular than what this project needs, and requires an actual acuity measurement (a real optotype test) to place someone on it.
- **iOS/Android** do not bucket at all in a formal sense during setup — they expose named feature toggles (VoiceOver/TalkBack for no usable vision, Larger Text/Zoom/Magnifier for low vision, standard for normal), which functionally *is* a 3-tier system (full screen / enlarged / non-visual) even though no test produces it — the user or a caregiver self-selects the tier directly by choosing which feature to turn on.
- **Takeaway for alignment:** the project's own 3-tier `screen | large | none` is directly analogous to the *de facto* 3-tier structure implied by real OS accessibility feature sets (standard display / enlarged display+magnification / screen-reader-only), even though those OSes arrive at the tier via self-selection, not measurement. So the project can credibly claim its 3-tier bucket "matches how iOS/Android accessibility settings are structured" while going one step further by measuring rather than asking outright — that's a legitimate, defensible differentiator for a pitch.

**Verdict: Strong feasibility** — the 3-tier scheme has clear real-world precedent (informally in OS accessibility categories) and a formal analogue (WHO ICD, collapsed from 6 tiers to 3) worth citing for pitch credibility.

---

## 5. Recommendation for the 30-hour build

**Hybrid, weighted toward the direct question, with the shrinking-text test as the credibility-building measured step — not a full active test with its own confirm-precision risk in isolation.**

Concretely:
1. Run vision calibration **after** touch calibration (so a confirm target sized to the user's real `min_target_size` already exists — solves the precision-collision problem raised in §2 for free).
2. Show 2–3 shrinking-text steps only (not 4–5) at fixed sizes roughly aligned to the three target buckets — e.g. a size clearly readable as normal (`screen`), a size clearly only readable if enlarged (`large`), and no legible step (`none`) — each confirmed with a full-width tap-anywhere zone (or the `sounds` voice signal as an alternate channel per §3.1's existing binary-confirm design). This keeps it a true measured test (on-brand with touch/speech) while capping it at ~3 quick confirmations, each ≤5s timeboxed with auto-advance/skip per the non-functional requirements.
3. First non-confirm (or skip/timeout) at a step directly assigns the bucket at that level — no need for finer step-down resolution since the output is 3 buckets, not a numeric acuity score.
4. Skip entirely (jump straight to a default of `screen`, adjustable later) is always available, consistent with "every test step should be timeboxed and skippable."

**Why not pure shrinking-text (5+ steps) or pure direct question alone:**
- Pure fine-grained shrinking text (§2's MNRead-style) is more steps/time than this project's other two calibration tests use, and risks looking like it's testing acuity rather than functional bucket — disproportionate build and demo time for a 3-way output.
- Pure direct question alone breaks the project's own established pattern (touch and speech are both *measured*, not asked) and would visibly stick out during a judged demo as the one axis that's "just a question" when the pitch's whole thesis is measured, composed capability profiles.
- The 3-step hybrid is small enough to build in the time available (it reuses the touch profile's confirm-target sizing and the speech profile's `sounds` tier — no new input infrastructure), while still being a real measured test that produces the bucket directly, matching the rest of the system's design philosophy and giving the pitch a stronger answer than "we just asked."

---

## Sources

- [Peek Acuity — Calibrating your device](https://peekvision.org/solutions/peek-acuity/peek-acuity-calibration/)
- [Peek Acuity app works as well as charts — Peek Vision](https://peekvision.org/resources/news/peek-acuity-app-works-as-well-as-charts/)
- [Peek eye testing app shown to work as well as charts for visual acuity — LSHTM](https://www.lshtm.ac.uk/newsevents/news/2015/peek_visual_acuity_app_study.html)
- [Vision test validation: the Peek Acuity app — Peek Vision](https://peekvision.org/resources/research/validating-our-vision-test/)
- [Peek Acuity update, July 2021 (PDF)](https://peekvision.org/wp-content/uploads/2023/11/July2021_PeekAcuity_remote_healthcare.pdf)
- [Real-world application of a smartphone-based visual acuity test (WHOeyes) with automatic distance calibration](https://www.researchgate.net/publication/379176594_Real-world_application_of_a_smartphone-based_visual_acuity_test_WHOeyes_with_automatic_distance_calibration)
- [Clinical validation of a novel smartphone application for measuring best corrected visual acuity — Journal of Optometry](https://www.journalofoptometry.org/en-clinical-validation-novel-smartphone-application-articulo-resumen-S1888429623000018)
- [Validity and Reliability of Vis-Screen Application — PMC](https://www.ncbi.nlm.nih.gov/pmc/articles/PMC10224196/)
- [Development and Validation of a Digital (Peek) Near Visual Acuity Test — PMC](https://www.ncbi.nlm.nih.gov/pmc/articles/PMC9807182/)
- [Smartphone-based screening for visual impairment in Kenyan school children — PMC](https://www.ncbi.nlm.nih.gov/pmc/articles/PMC6057135/)
- [Evaluation of contrast sensitivity using K-CS test — PMC](https://pmc.ncbi.nlm.nih.gov/articles/PMC10852338/)
- [Development and Validation of a Smartphone-based Contrast Sensitivity Test — PMC](https://www.ncbi.nlm.nih.gov/pmc/articles/PMC6743644/)
- [Mobile app Aston contrast sensitivity test — PubMed](https://pubmed.ncbi.nlm.nih.gov/27291146/)
- [Use accessibility features during iPhone setup — Apple Support](https://support.apple.com/guide/iphone/use-accessibility-features-during-setup-iph2f623a095/ios)
- [Turn on and practice VoiceOver on iPhone — Apple Support](https://support.apple.com/guide/iphone/turn-on-and-practice-voiceover-iph3e2e415f/ios)
- [Get started on Android with TalkBack — Android Accessibility Help](https://support.google.com/accessibility/android/answer/6283677?hl=en)
- [Android accessibility overview — Android Accessibility Help](https://support.google.com/accessibility/android/answer/6006564?hl=en)
- [Text Too Small Accessibility: Choose Accessible Font Sizes — Equalize Digital](https://equalizedigital.com/accessibility-checker/text-too-small/)
- [Understanding Accessible Fonts and Typography for Section 508 Compliance — Section508.gov](https://www.section508.gov/develop/fonts-typography/)
- [Text size and impairment categories — Why Cambridge](https://www.cedc.tools/size.html)
- [Understanding the WHO vision impairment categories — Why Cambridge](https://www.cedc.tools/WHOcategories.html)
- [Vision impairment including blindness — ICD-11 MMS](https://www.findacode.com/icd-11/block-1103667651.html)
- [Technical Definitions — IAPB Vision Atlas](http://atlas.iapb.org/discover/technical-definitions/)
- [Apple Vision Accessibility: The 2025 AppleVis Report Card](https://www.applevis.com/blog/apple-vision-accessibility-2025-applevis-report-card)
