# 13. Event Submission — Finalized Answers

**1. Target user / customer**
People whose abilities don't line up with any single fixed-point accessibility tool — specifically those with overlapping motor, speech, and vision limitations, where no existing tool (screen reader, switch access, voice access) fits. Inspired by a team member's brother, who is affected across all three axes and falls through every mainstream tool built for one fixed impairment.

**2. Problem being solved**
Accessibility tools are each built for one assumed point on the ability spectrum. The moment someone's real abilities don't match that point — common with overlapping impairments — the tool breaks down, and none of them cooperate with each other. These users either stitch together mismatched tools or depend on a caregiver, losing independence on tasks they should be able to do alone.

**3. Existing alternatives**
Screen readers, switch/scanning access, voice/speech-to-text — each solves one axis of ability well, but none compose with each other or adapt to someone sitting between or across their assumed points.

**4. Evidence collected before the event**
Personal/family experience only, no formal research: direct observation of a team member's brother unable to use any single existing tool because his limitations span touch, speech, and vision at once.

**5. Riskiest assumption**
That when input is imprecise and the AI has to fill in the gaps, it guesses right often enough that the user still trusts it — instead of confirmation prompts becoming constant, annoying interruptions. We'll sanity-check this early by running a handful of realistic unclear-speech samples through the intent parser before building UI around it, and if guesses aren't reliable enough, the fallback is to lean on the confirmation step itself as the safety net — nothing consequential happens without a yes, so the system stays trustworthy even if it's not always right on the first guess.

**6. Current solution hypothesis**
A capability-profile-driven I/O layer that fuses touch and voice input and delivers output in whatever mode the user can perceive, with an AI agent executing actions and confirming before anything consequential.

**7. What already exists at kickoff**
Nothing.

**8. What you intend to build, test, or learn**
Build one working adaptive UI for a single profile first, then a second profile plus a switch between them, to learn whether switching actually generalizes or needs per-profile special-casing. Core question: does touch+voice fusion beat either alone, and does the profile switch hold up as one real system rather than two disguised screens.

---

*See [09 — Open Questions](09-open-questions.md) for what's still unresolved (demo task choice, vision calibration method, narration approach) — worth locking before the event's kickoff form asks for specifics.*
