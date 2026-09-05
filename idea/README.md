# Adaptive Capability-Profile Access Layer
### Accessibility as a continuous ability spectrum, not a set of disability labels

**Status:** Draft v4 — Startathon submission
**Owner:** [Team name / SCTCE]
**One-line concept:** A system that treats accessibility as a continuous *capability profile* instead of a set of disability labels, and fuses the right combination of input and output modalities for each user's actual abilities — with an AI agent covering the gaps where input is imprecise.

---

## 0. What changed from v2 → v3 → v4

**v1/v2** modeled users by *category* ("motor impaired," "speech impaired," "people with 2+ impairments"). **v3** abandoned categories for two ideas:

1. **Spectrum, not labels.** Every user is a point on a few *continuous ability axes*. Disability labels are a lossy compression of where someone actually sits.
2. **Composition, not selection.** Existing tools force the user to pick *one* accessible input (voice **or** switch **or** touch). We **fuse** whatever partial abilities a user has, because two weak modalities used together beat one weak modality used alone.

**v4** (this split) adds a third idea, worked out during pitch prep:

3. **Composition is two-layered, not one.** Composition happens *per-user* (calibration decides what this person can operate) **and** *per-task* (each task has an ideal input type, constrained by what the user can actually use). See [Input & Calibration](03-input-calibration.md).

The rest of this directory is written around those three ideas. The AI agent is infrastructure; the capability profile and the modality fusion are the product.

---

## Reading order

| Doc | Covers |
|---|---|
| [01 — Problem](01-problem.md) | Why fixed-point tools fail the long tail of ability combinations |
| [02 — Core Model](02-core-model.md) | Ability axes, the capability profile object, precision–inference coupling |
| [03 — Input & Calibration](03-input-calibration.md) | Multi-method touch calibration, confidence scoring, task-aware input switching |
| [04 — Goals](04-goals.md) | Product goals, what the innovation actually is, non-goals |
| [05 — Locked Scope](05-scope.md) | What gets built in the 30-hour event, and what doesn't |
| [06 — User Model](06-user-model.md) | Who this serves, and the example profiles used in the demo |
| [07 — Architecture](07-architecture.md) | End-to-end system diagram |
| [08 — Requirements](08-requirements.md) | Functional / non-functional requirements |
| [09 — Open Questions](09-open-questions.md) | What's resolved, what's still open |
| [10 — Validation Plan](10-validation-plan.md) | What we want to learn and how we'll test it |
| [11 — Risks](11-risks.md) | Risk table incl. the pinned riskiest assumption |
| [12 — Roadmap](12-roadmap.md) | Pitch narrative only — not build scope |
| [13 — Event Submission](13-event-submission.md) | Finalized answers to the event's application questions |
