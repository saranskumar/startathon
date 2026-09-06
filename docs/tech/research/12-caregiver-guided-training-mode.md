# 12. Caregiver-Guided Training Mode (Physical Prompting, Before Calibration)

**Purpose:** Research brief for [GitHub issue #2](https://github.com/saranskumar/startathon/issues/2) and [docs/idea/25 — Meeting Notes: Caregiver Training Mode](../../idea/25-meeting-notes-caregiver-training-mode.md). The proposed idea — a caregiver physically moves the user's hand through a motion, repeated until the user associates the instruction with the motion themselves, before calibration runs — turns out to have a direct, well-established clinical name and a mature technique behind it, not just a plausible-sounding intuition.

**Headline verdict: this is real, named, evidence-backed occupational-therapy technique ("hand-over-hand"/"hand-under-hand" physical prompting, within the broader ABA "prompt hierarchy"). The idea is sound; the one thing worth adding to it is a consent-aware variant and a fading structure, so the training mode has a defined graduation point instead of an open-ended "keep trying."**

---

## 1. The technique already has a name: physical prompting

What was described — a caregiver directly guiding the user's hand through a motion so the user can build the association between an instruction and a movement — is **physical prompting**, a standard technique for teaching new motor, technology, and communication skills, used specifically when a learner can't yet bridge the gap between being told what to do and doing it. ([USSAAC / Speakup](https://www.ussaac.org/speakup/physical-prompting-and-aac/); [The OT Toolbox](https://www.theottoolbox.com/what-is-prompting/))

Two named variants, not one:

- **Hand-over-hand**: the caregiver's hand is placed *on top of* the learner's hand and moves it through the motion directly. ([Autism Little Learners](https://autismlittlelearners.com/hand-over-hand-prompting/))
- **Hand-under-hand**: the caregiver's hand is placed *underneath* the learner's, and the learner is allowed to initiate and control the movement, with the caregiver's hand available as a guide/anchor rather than driving it. This is considered **the less coercive of the two**, particularly for a learner who resists being physically manipulated, because it leaves room for the learner to initiate and lets the caregiver "wait and gradually pull away" rather than imposing the motion. ([Sidekick Therapy Partners](https://www.mysidekicktherapy.com/blog/articles/hand-over-hand-or-hand-under-hand-prompting); [Inclusive Teach](https://inclusiveteach.com/2021/07/10/hand-over-hand-vs-hand-under-hand-support/))

**This matters for the training-mode design, not just terminology.** The original idea as described is pure hand-over-hand ("the caregiver actually moves their finger in that pattern"). The research suggests **offering hand-under-hand as the default or first-tried variant**, with hand-over-hand as a fallback for a learner who can't initiate at all — both because it's gentler, and because a learner who can initiate even slightly gets a more honest signal of what they can actually do versus what's being done to them.

## 2. This sits inside a bigger, already-solved structure: the prompt hierarchy

Physical prompting isn't used in isolation — it's the most-assistance end of a graded scale (ABA's "prompt hierarchy") that's specifically designed to be **faded** over repeated attempts, not repeated identically until it clicks:

- **Most-to-least prompting**: start at full physical prompt (hand-over-hand), reduce to partial physical prompt as the learner improves, then to verbal/visual/gesture prompts, then to independent performance. ([Raven Health](https://ravenhealth.com/blog/least-to-most-prompting-aba); [How To ABA](https://howtoaba.com/the-prompt-hierarchy/))
- **Least-to-most prompting** (the inverse): start independent, and only add prompting (indirect verbal → direct verbal → gesture → model → physical) if the learner doesn't succeed unprompted — used when there's reason to think the learner might already be closer to independent than assumed. ([How To ABA](https://howtoaba.com/the-prompt-hierarchy/))

**Recommendation: use most-to-least for this training mode.** The whole premise of the idea (per [issue #2](https://github.com/saranskumar/startathon/issues/2)) is that the user starts *without* the instruction-to-motion association at all, so starting at full physical guidance and fading down is the matched case, not the inverted one. Concretely, this gives the training mode **a defined structure with a real graduation signal**, rather than the "keep trying until it clicks" framing in the original idea, which has no way to tell the caregiver when to stop:

1. **Full physical** (hand-under-hand preferred, hand-over-hand as fallback) — caregiver and user move together.
2. **Partial physical** — caregiver initiates the motion, lets go partway through, user completes it.
3. **Prompted-independent** — instruction given, user attempts alone; caregiver present but not touching.
4. **Graduate to calibration** once step 3 succeeds a small number of times in a row (no need for calibration's own success-rate math here — this is a binary "did the association form," not a precision measurement).

## 3. There's direct evidence this works for motor-skill acquisition specifically

A controlled study of hand-over-hand physical guidance and tracing on **prewriting skills in preschool-aged children** found real gains in handwriting legibility for the intervention group and no change in the comparison group — direct evidence that hand-over-hand guidance measurably improves acquisition of a new fine-motor skill, not just a plausible-sounding theory. ([ResearchGate](https://www.researchgate.net/publication/240518831_Effects_of_hand-over-hand_physical_guidance_and_tracing_on_prewriting_skills_of_preschool-aged_children); [ERIC](https://files.eric.ed.gov/fulltext/EJ1102382.pdf))

## 4. The consent/dignity caveat is real and documented, not a hypothetical concern

The hand-over-hand vs. hand-under-hand distinction exists in the literature specifically *because* hand-over-hand — physically moving someone's body for them — can be experienced as coercive, especially by a learner who resists it; hand-under-hand exists as the answer to that concern, not as a mere stylistic variant. ([Inclusive Teach](https://inclusiveteach.com/2021/07/10/hand-over-hand-vs-hand-under-hand-support/)) Worth stating plainly in the doc this feeds ([23](../../idea/25-meeting-notes-caregiver-training-mode.md)) rather than leaving implicit: this is a technique applied to another person's body, by a caregiver, inside a demo/product context — the app should surface the gentler variant first and make it easy for the caregiver to see the fading progression (so they know when to back off), rather than only describing "how to hand-over-hand guide someone" without the consent framing that the source literature treats as inseparable from the technique.

---

## Connection to the rest of the docs

This is genuinely new scope, not a restatement of something already covered — [03 — Input & Calibration](../../idea/03-input-calibration.md) measures precision/speed/success once the user already knows what's being asked; this training mode is explicitly upstream of that. Recommend:

- Adding a **pre-calibration training-mode step** to [03 — Input & Calibration](../../idea/03-input-calibration.md), gated on "caregiver present" (from the same solo/assisted entry split as [research 11](11-accessible-entry-onboarding-and-contrast.md) §1–2), using the four-step fade structure in §2 above.
- The **graduation criterion should be per input method**, not global — a user might need full physical prompting for the joystick but go straight to independent on buttons, which fits naturally with calibration already testing methods independently ([03 §3.1](../../idea/03-input-calibration.md)).
- This is pitch-relevant too: it's a second, concrete instance of "the pieces exist separately, nobody combines them" (the defensibility slide's claim, [presentation/slides.html](../../../presentation/slides.html)) — prompt fading is standard OT/ABA practice, but wiring its graduation signal directly into an automated capability-profile calibration flow is the same kind of combination this project already claims for input/output composition.
