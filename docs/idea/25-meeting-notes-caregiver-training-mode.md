# 25. Meeting Notes — Caregiver-Guided Training Mode (unverified transcript)

**Source:** voice memo, transcribed and lightly cleaned up, Sept 6 2026. Single speaker, no timestamp on the recording itself. Filed as [GitHub issue #2](https://github.com/saranskumar/startathon/issues/2); researched in [tech/research/12 — Caregiver-Guided Training Mode](../tech/research/12-caregiver-guided-training-mode.md).

---

## What was raised

A user with more significant motor impairment, onboarding with a caregiver's help, may not be able to translate a verbal/abstract instruction ("go left, then up") into an actual physical motion — the gap described isn't motor ability itself, it's not knowing how to turn an instruction into a movement at all. The proposed fix: the caregiver physically moves the user's hand/finger through the actual motion (left, then up), and repeating that lets the user associate *that instruction* with *that motion* themselves — only once that association exists can the user act on the instruction independently.

The proposal: a **training mode**, done with caregiver help, where the user can try one single action repeatedly, with no pressure to get it right immediately — just repetition until it clicks. This would run **before** calibration, not instead of it.

## Research findings

See [tech/research/12](../tech/research/12-caregiver-guided-training-mode.md) for the full brief. Short version: this is not a novel idea needing invention — it's a **named, established occupational-therapy/ABA technique**, with two things worth folding back into the design:

- **The technique is "physical prompting,"** specifically **hand-over-hand** (caregiver's hand on top, driving the motion, as originally described) or **hand-under-hand** (caregiver's hand underneath, letting the user initiate). Hand-under-hand is documented as the gentler, less coercive variant and is worth offering as the default, with hand-over-hand as a fallback for a user who can't initiate at all.
- **Physical prompting is normally used as part of a graded, fading sequence** (ABA's "prompt hierarchy"), not repeated identically until it clicks. Recommend structuring the training mode as **full physical → partial physical → prompted-independent → graduate to calibration**, which gives the caregiver a defined stopping point instead of an open-ended "keep trying."
- **There's direct evidence this works**: a controlled study found hand-over-hand guidance measurably improved handwriting-legibility acquisition in preschoolers versus a comparison group, for a comparable "build the motor association" case.
- **There's a real consent/dignity caveat** in the literature — hand-over-hand physically moves someone else's body, and hand-under-hand exists specifically as the answer for a learner who might experience that as coercive. Worth surfacing to the caregiver in the app itself (offer the gentler variant first, make the fading progression visible), not just building the mechanic.

## How this connects to the rest of the docs

This is genuinely new scope, not something [03 — Input & Calibration](03-input-calibration.md) already covers — calibration measures precision/speed/success assuming the user already understands the instruction; this training mode is explicitly upstream of that, and skipping it would make "doesn't understand the instruction yet" look identical to "can't perform the motion" in calibration's own scoring. Recommend:

- Adding a pre-calibration training-mode step to [03 — Input & Calibration](03-input-calibration.md), gated on caregiver presence (the same solo/assisted split raised in [24 — Onboarding Entry & Accessibility](24-meeting-notes-onboarding-entry-and-accessibility.md)), using the four-step fade structure above.
- Making the graduation criterion **per input method**, not global — a user might need physical prompting for the joystick but go straight to independent attempts on buttons, consistent with calibration already testing each method separately.
- This is also a usable pitch point: prompt fading is standard clinical practice, but wiring its graduation signal directly into an automated capability-profile calibration flow is the same "pieces exist separately, nobody combines them live" claim the deck already makes for input/output composition — see [tech/research/12](../tech/research/12-caregiver-guided-training-mode.md)'s closing note.

**Caveat: this is a single-speaker voice-memo transcript**, cleaned up for readability but not reviewed by the team as a settled decision. Confirm scope/priority — and in particular the consent framing above — before building this as described.
