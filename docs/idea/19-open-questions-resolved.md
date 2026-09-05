# 19. Open Questions — Research Findings & Reasoned Answers

Consolidates every open question raised across [09-open-questions.md](09-open-questions.md), [16-canvas-submission.md](16-canvas-submission.md), [17](17-meeting-notes-tree-simplification.md), and [18](18-meeting-notes-feature-ranking.md). Two questions (feature ranking/auxiliary-tree construction, vision calibration) had real external research done — see [docs/tech/research/08-feature-ranking-auxiliary-tree.md](../tech/research/08-feature-ranking-auxiliary-tree.md) and [09-vision-calibration.md](../tech/research/09-vision-calibration.md). The rest are internal design decisions, reasoned through directly below rather than researched externally, since no outside literature answers "what should *this* team's Google Form contain."

---

## 1. How is "important" decided, and how AI-powered does it need to be? (RESOLVED — direction set)

This was the most-repeated open question across three separate conversations ([16](16-canvas-submission.md), [17](17-meeting-notes-tree-simplification.md), [18](18-meeting-notes-feature-ranking.md)) — worth settling once here.

**Answer: a two-tier system, mostly not AI.**
- **Tier 1 (default, no LLM):** score every accessibility-tree node with a small heuristic formula — ARIA landmark role, heading level, interactivity, accessible-name presence, text length, link density (penalizing nav-heavy blocks), visibility. This is the exact technique that already powers Firefox Reader View / Chromium's DOM Distiller (Readability.js, Boilerpipe-lineage), and it doubles as the same signal real screen-reader users already navigate by — per WebAIM's survey, ~72% of screen-reader users navigate via headings. See [08-feature-ranking-auxiliary-tree.md](../tech/research/08-feature-ranking-auxiliary-tree.md) §1 for the full formula.
- **Tier 2 (fallback only):** a single, narrowly-scoped LLM call, triggered only when tier 1 is genuinely ambiguous — no landmarks/headings present at all, top candidates score within a small delta of each other, or an interacted-with element can't be classified as navigation/info/ignore by role alone (the "unknown element" case from doc 18). This directly resolves the "decided not to make this unnecessarily AI-powered or agentic" line in [16-canvas-submission.md](16-canvas-submission.md) and the reasoning trail in [17](17-meeting-notes-tree-simplification.md): AI is used narrowly, for tree simplification when heuristics fail, not as the interaction loop's orchestrator.

**Action item:** [07-architecture.md](07-architecture.md) and [docs/tech/README.md](../tech/README.md) still describe a single "AI Agent" box interpreting all fused intent. Split it into two distinct, honestly-scoped components: (a) the mostly-heuristic auxiliary-tree builder above, and (b) the thin, confirmation-gated action-dispatch loop already recommended in [docs/tech/research/04-agent-execution-layer.md](../tech/research/04-agent-execution-layer.md) (no OpenClaw; a small custom loop; LLM only for matching a specific fused-intent to a specific tree node when tier 1's heuristics leave more than one plausible candidate). Neither component is "an agent" in the JARVIS sense the canvas answers explicitly disclaim.

---

## 2. Vision calibration method (RESOLVED — was genuinely undecided since v1)

**Answer:** run it *after* touch calibration, 2–3 shrinking-text steps (not a full clinical-style test), each confirmed via a full-width tap-anywhere zone (or the `sounds` speech tier if speech calibration already ran) rather than a small button — this sidesteps the exact problem that likely stalled this decision originally: a naive shrinking-text test's own confirm-tap can fail for touch-precision reasons, contaminating the vision measurement. First failed/skipped step assigns the bucket (`screen`/`large`/`none`) directly — no need for finer resolution since the output is 3 buckets, not a numeric acuity score. Full reasoning and sourcing in [09-vision-calibration.md](../tech/research/09-vision-calibration.md).

**Why not simpler alternatives:** a pure direct question ("can you read this? yes/no") is faster to build but breaks the project's own established pattern — touch and speech are both *measured*, and an unmeasured vision axis would visibly stick out as the one guessed-at axis in a pitch whose entire thesis is measured, composed capability profiles. A full clinical-grade test (5+ steps, sentence-length stimuli) is more time than this project's other two calibration tests spend and isn't needed for a 3-bucket output.

---

## 3. Reconciling the two statements of the riskiest assumption (RESOLVED — one unified statement proposed)

Two versions currently exist:
- [11-risks.md](11-risks.md): "the AI guesses right often enough [about what to *do*] that confirmation doesn't become annoying."
- [16-canvas-submission.md](16-canvas-submission.md): "that we can parse the user's input even if it has gaps."

**These are the same risk, viewed from the two ends of one pipeline** — input-side (can ambiguous/partial multi-modal input be correctly interpreted into intent) and output-side (does the resulting proposed action match what the user meant, confirmed before it executes). Splitting them risks testing only one half and believing the whole risk is covered.

**Proposed single statement, to replace both:**
> The system can correctly interpret user intent from imprecise, partial, multi-modal input often enough — and, when it can't, surface a proposal the user can recognize as wrong and correct or cancel — that the user trusts the result without the interaction becoming a constant confirm-loop.

This keeps [11-risks.md](11-risks.md)'s original fallback intact (confirmation is the safety net even when the first guess is wrong) while folding in the canvas's "gaps in input" framing as the *cause* of wrong guesses, not a separate risk. **Test plan is now stronger than either original version alone**, since [16-canvas-submission.md](16-canvas-submission.md) upgrades the test subject from a labeled proxy to the actual real user (the brother) — this single statement is exactly what that beta test should be measured against.

---

## 4. "Smallest useful thing to build" vs. the locked demo scope (FLAGGED — real tension, needs a team call)

[16-canvas-submission.md](16-canvas-submission.md) names the smallest useful thing as *just* the adaptive input layer on the phone. [05-scope.md](05-scope.md) still locks in agent-driven Google Form submission and narration as required demo elements. [docs/tech/README.md](../tech/README.md)'s stated build order makes this concrete: **step 1 is browser/agent automation, step 2 is the phone calibration UI** — the opposite order from what "smallest useful thing" implies if the real-user beta test (input layer only) is actually the highest-value validation step.

**Reasoning, not a unilateral decision:** these don't have to conflict if read as two different artifacts with two different audiences — "smallest useful thing to run the validation test" (input layer, tested with the brother) doesn't have to equal "what's demoed to judges" (the fuller pipeline, per 05-scope.md). But the *build order* in tech/README.md currently optimizes for the judge-facing demo first, which delays the actual riskiest-assumption test (§3 above) until late in the build. **Recommend flipping the build order** — get the input/calibration layer working and in front of the brother as early as possible, since that's both the smallest useful thing *and* the fastest path to real evidence on the pinned riskiest assumption — and treat the agent/narration/form-submission pipeline as building on top of validated input, not gating it.

---

## 5. `steadiness` field has no calibration test (RESOLVED — derive it for free, don't add a new test)

[09-open-questions.md](09-open-questions.md) already flagged this as unresolved, with two options: add a cheap measurement, or drop the field. **Recommend adding it for free rather than dropping it**: the touch calibration tests (per [03-input-calibration.md](03-input-calibration.md) §3.1) already capture per-attempt time-series data (success/fail, time-to-target, error distance) — `steadiness` doesn't need its own test, it can be derived from the *variance* already present in that captured data: jitter in a trackpad drag path, accidental extra taps during a button test, position variance while holding a joystick on-target. This is a metric computed from existing calibration data, not a new interaction to design, build, or timebox.

---

## 6. Navigation/information split vs. the existing 3-shape task taxonomy (RESOLVED — orthogonal, not competing)

[18-meeting-notes-feature-ranking.md](18-meeting-notes-feature-ranking.md) proposes splitting the display into "navigation" and "information" sets. [03-input-calibration.md](03-input-calibration.md) §3.2 already has a task-shape taxonomy (discrete choice / continuous-directional / free pointing) governing *which input pattern* handles a given interaction. **These answer different questions and both stay:**
- **Navigation/information** decides *what gets surfaced to the user at all*, and in which of two buckets (something to act on, vs. something to just be told).
- **Task-shape taxonomy** decides *how the user interacts with* whatever's in the navigation bucket, once selected (buttons/joystick/trackpad, ideal-or-fallback per [03-input-calibration.md](03-input-calibration.md) §3.3).
- The **information** bucket doesn't need a task-shape assignment at all — it's narration-only, no input pattern attached, which is a simplification worth stating explicitly rather than leaving implicit.
- **Scroll**, flagged as a special case in doc 18 because it "isn't in the DOM," is already the continuous/directional task shape — same problem, arrived at from the output/tree side rather than the input side. No new mechanism needed; just connect the two docs' vocabulary.

---

## 7. "Unknown" elements that don't classify as navigation or information (RESOLVED — watch the effect, not the element)

Doc 18 flagged elements the ranking process can't confidently classify, suggesting a fresh tree-generation call might be needed. [08-feature-ranking-auxiliary-tree.md](../tech/research/08-feature-ranking-auxiliary-tree.md) §4 has the concrete, zero-classification answer: **don't try to classify the element itself — watch what happens after it's interacted with.** If the URL changes, or a large fraction of the currently-tracked tree's nodes disappear/get replaced, that's a "new page" event regardless of what kind of element triggered it. This is the standard technique production SPA-tracking tools already use (`pushState`/`replaceState`/`popstate` interception, with a `MutationObserver`-based DOM-delta check as a fallback for router-less state changes) — no bespoke classifier needed, and it doubles as the tier-2 LLM trigger condition from §1 above (only call the LLM if the post-interaction effect *itself* is ambiguous, e.g. a partial DOM update that's neither clearly "nothing happened" nor clearly "new page").

---

## 8. Remaining open items — genuinely just team decisions, not research questions

These don't have an external answer to look up; they're choices the team needs to make directly, flagged here so they don't get lost:

- **Are Profile A and Profile B ([06-user-model.md](06-user-model.md)) the final two demo points?** — still open per [09-open-questions.md](09-open-questions.md).
- **Exact order/full list of interaction-pattern screens inside the custom mock UI** — still open; the mock UI (`code/mock`) exists but the specific screen sequence isn't locked.
- **Exact fields of the real Google Form** — needed before the agent's fill+submit step can be built; blocked on nothing except a team decision.
- **Does "fully functional calibration" fully replace the preset-toggle safety net, or do both coexist for demo reliability?** — [09-open-questions.md](09-open-questions.md) already frames this correctly; still unresolved.
- **Narration approach for the "no vision" output** — [docs/tech/research/03-proactive-narration.md](../tech/research/03-proactive-narration.md) already recommends Google Cloud TTS as the default with `flutter_tts` as an offline fallback; this is now more "pick one and build it" than "open question."

---

## Summary table

| # | Question | Status | Answer / recommendation |
|---|---|---|---|
| 1 | How AI-powered should importance-ranking be? | **Resolved** | Two-tier: heuristic scorer first, single narrow LLM call only when ambiguous |
| 2 | How is vision calibrated? | **Resolved** | 2–3 shrinking-text steps, after touch calibration, full-width/voice confirm |
| 3 | Which riskiest-assumption statement is current? | **Resolved** | Unified statement proposed (§3) — replaces both existing versions |
| 4 | Smallest useful thing vs. locked scope | **Flagged, needs team call** | Consider flipping build order to input-layer-first |
| 5 | `steadiness` field, no test | **Resolved** | Derive from variance already in touch-calibration data — no new test |
| 6 | Navigation/info split vs. task-shape taxonomy | **Resolved** | Orthogonal — both stay, vocabulary reconciled |
| 7 | "Unknown" element handling | **Resolved** | Watch post-interaction effect (URL/DOM delta), not the element itself |
| 8 | Demo points, screen order, form fields, preset-toggle coexistence | **Open — team decision** | No external answer; needs to be picked, not researched |
