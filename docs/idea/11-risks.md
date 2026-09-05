# 11. Risks

## Pinned riskiest assumption
> When input is imprecise and the AI has to fill in the gaps, it guesses right often enough that the user still trusts it — instead of confirmation prompts becoming constant, annoying interruptions.

This underlies the whole precision–inference coupling ([02 — Core Model](02-core-model.md) §2.4): if the AI guesses badly, Profile B (the partial-ability, fusion-heavy profile) becomes the *worse* experience — backwards, since it's supposed to be the one that benefits most from the system.

**Cheapest test:** before building UI around it, run a handful of realistic slurred/unclear voice samples through the intent parser and count how often the first guess is right vs. needs a second confirmation round.

**Fallback if it's shakier than hoped:** frame the confirmation step itself as the safety net in the pitch — nothing consequential happens without a yes, so the system stays trustworthy even if it's not always right on the first guess.

## Full risk table
| Risk | Mitigation |
|---|---|
| Spectrum framing reads as vague if the demo shows only one slice | Demo **two** profiles + the switch; state plainly "this is the validated slice, the profile engine is the extensible part" |
| Scope creep back toward "cover the whole spectrum / all axes" | [05 — Locked Scope](05-scope.md) is the locked contract |
| Fusion (Thesis B) gets dropped under time pressure, leaving only adaptivity | FR4 is P0 — a demo without fusion under-sells the actual innovation |
| Agent/automation layer (OpenClaw or equivalent) unstable under time pressure | Reduced since the interactive surface is now a self-built mock UI rather than a third-party app ([05 — Locked Scope](05-scope.md), [09 — Open Questions](09-open-questions.md)) — the agent's real-world-execution job narrows to filling + submitting one real Google Form. Still timebox this integration early and keep a manually-triggered fallback path for the live demo. |
| Patient voice input is hard to show convincingly in a short pitch | Pair the live demo with a recorded example of slow/unclear speech being accepted |
| No representative user found in time | Clearly-labeled proxy constrained to a profile's exact coordinates |
| Profile switch demo fails live | Have a recorded backup of the A→B reshape |
| Full multi-input calibration (buttons/joystick/trackpad/reach-zone/voice) is a real scope expansion over the original locked build | If it runs out of time, fall back to a scripted/staged calibration with a preset toggle underneath — still a coherent, honest demo |
| Task-aware input switching adds a second dynamic layer on top of profile switching | Only build the two interaction patterns (ideal + fallback) the chosen demo task actually needs, not the full task-shape × method matrix |
