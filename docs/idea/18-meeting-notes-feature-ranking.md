# 18. Meeting Notes — Feature Ranking, Auxiliary Trees, and New-Page Handling (unverified transcript)

**Source:** auto-generated meeting summary (Essential Space), Sept 5 2026 19:02–19:08, four unnamed speakers. Same caveat as [17 — Meeting Notes: Tree Simplification](17-meeting-notes-tree-simplification.md): **not verified against a recording, speaker numbers are placeholders, treat as a rough transcript, not a locked decision.** This is a direct continuation of that meeting (starts 6 minutes after it ends) — read 17 first; this doc assumes the "auxiliary tree" term it introduces.

---

## What was discussed

This session goes one layer deeper than [17](17-meeting-notes-tree-simplification.md): given that a simplified "auxiliary tree" gets produced from the DOM/accessibility tree, what actually happens with it — how it's ranked, shown to the user, and regenerated as the user navigates.

**The pipeline as described, in order:**
1. **DOM extraction** — parse the page's DOM.
2. **Important-feature identification** — pull out the features that matter (this is the "auxiliary tree" from doc 17).
3. **Ranking** — assign each identified feature a rank (Rank 1, Rank 2, ...).
4. **Present to user, ranked** — the system asks the user, in effect, "is this what you want?" by surfacing features in ranked order rather than dumping the whole set at once.
5. **User input → loop back** — after the user responds, the system loops back to step 1/2 territory, refining the tree/ranking with the new context.

**How ranking would be produced:** explicitly left open — "a machine or AI/ML would be used to figure this out," described at one point as "currently a black box that takes input and provides feature rankings." No specific ranking method (heuristic scoring, an ML classifier, or an LLM call) was settled — this is a real open question, not a decision, consistent with [16-canvas-submission.md](16-canvas-submission.md)'s "still uncertain: how we'll determine what's important" and [17](17-meeting-notes-tree-simplification.md)'s open tasks.

**Handling new pages / navigation:**
- When the user navigates to a new page, the system loops back to DOM extraction and generates a **new auxiliary tree with new rankings** for that page — the auxiliary tree is per-page/per-state, not a single static structure for the whole app.
- Certain elements get marked as **"new page" triggers** — navigating into one of those calls a fresh auxiliary-tree-generation step.
- **"Unknown" elements** — ones the system can't classify as navigation, info, or otherwise — were flagged as a case that may still need to trigger a fresh tree-generation tool call, i.e. an explicit fallback path for elements the ranking process doesn't have a confident answer for.

**Splitting the user-facing display into two sets:**
- **"Navigation"** set and **"information"** set, proposed as two separate categories for what gets shown to the user, rather than one undifferentiated ranked list — implicitly, "here's where you can go" vs. "here's what's on this screen," handled/presented differently.
- **Scroll** was flagged as a special case: scrolling isn't itself a DOM element, so it needs handling outside the normal DOM-extraction → feature → rank pipeline (this is the same problem [03-input-calibration.md](03-input-calibration.md) §3.2 already treats as its own task shape — "continuous/directional" — worth connecting the two rather than re-solving it here).

---

## How this connects to the rest of the docs

- **"Auxiliary tree"** is now the working term for what [17-meeting-notes-tree-simplification.md](17-meeting-notes-tree-simplification.md) called "map a complex tree to a simpler one" and what [docs/tech/research/03-proactive-narration.md](../tech/research/03-proactive-narration.md) proposed as an LLM-summarized minimal choice-set. All three are converging on the same shape from different angles — worth using one consistent name (**auxiliary tree**) across the docs once this gets reconciled.
- **Per-page/per-navigation regeneration of the auxiliary tree** is a concrete mechanism that the earlier research thread's "diff snapshots over time" approach (03-proactive-narration.md §2) didn't fully specify — this meeting adds the missing piece: a *new-page trigger* is the event that causes regeneration, not just a generic polling interval. Worth folding into that research doc's pipeline description.
- **The navigation/information split** maps naturally onto [03-input-calibration.md](03-input-calibration.md)'s task-shape taxonomy (discrete choice / continuous-directional / free pointing) — "navigation" items are candidates for the discrete-choice or continuous-directional shapes, "information" items are narration-only, no input action attached. Worth checking whether this two-way split is meant to replace or sit alongside that existing three-shape taxonomy.
- **Ranking method is still an open black box** — same open question as [16-canvas-submission.md](16-canvas-submission.md) ("uncertain... how much of this will have to use LLMs to understand what's on screen") and [17](17-meeting-notes-tree-simplification.md)'s unresolved tasks. Nothing here resolves it; it's the same open question restated with more pipeline detail around it.
- **Scroll-as-special-case** is already implicitly handled by [03-input-calibration.md](03-input-calibration.md)'s continuous/directional task shape (joystick ideal, button-stepper or trackpad-drag fallback) — this meeting arrives at the same problem from the output/tree side ("scroll isn't in the DOM") rather than the input side. Worth explicitly cross-referencing rather than treating as a new problem.

**Caveat again: unverified auto-transcript**, same as doc 17 — confirm with whoever was in the room before treating any specific claim as locked, especially the ranking-method black box, which sounds unresolved even within the meeting itself.
