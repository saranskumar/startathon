# 10. Validation Plan

**What we want to learn:**
- Does profile-driven composition let a user complete the task more independently / faster than their current method?
- Does modality **fusion** (touch + voice together) outperform either modality alone for a partial-ability user? (Directly tests Thesis B.)
- Does proactive narration reduce missed information vs. requiring navigation to find it?
- Does task-aware input switching (Thesis C) actually hold up as one coherent system, or does it feel like disguised separate screens per task? (See [03 — Input & Calibration](03-input-calibration.md).)
- Does the agent's inference stay trustworthy when input is imprecise — i.e. does confirmation stay a light check rather than becoming constant, annoying interruptions? (This is the currently pinned riskiest assumption — see [11 — Risks](11-risks.md).)

**How we'll test:**
- Baseline: same user/task with their current method (existing tool or caregiver-assisted) — record time, completion, errors.
- System: same user/task through the composed interface for their profile — record the same.
- If possible, also test the fusion condition against a single-modality condition for the same partial-ability user.
- For the riskiest assumption specifically: before building UI around it, run a handful of realistic unclear-speech samples through the intent parser and count how often the first guess is right vs. needs a second confirmation round.

**Representative user is the highest-leverage non-coding action.** Even a clearly-labeled proxy (a teammate constrained to the exact coordinates of Profile A or B — e.g. one large touch zone only, or forced-slow speech) strengthens the submission far more than arguing the need in the abstract. Label proxies honestly as proxies.
