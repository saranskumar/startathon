# 28. Scope Lock — No AI At All, Demo Task Split, Open-Source Positioning Reaffirmed

**Source:** direct team decision, Sept 6 2026, given while preparing the presentation material. This supersedes the AI-agent framing still written into [07-architecture.md](07-architecture.md) and [docs/tech/README.md](../tech/README.md), and the tier-2 "narrow LLM fallback" answer in [19-open-questions-resolved.md](19-open-questions-resolved.md) §1.

---

## 1. No AI, at all — this goes further than "not unnecessarily agentic"

[16-canvas-submission.md](16-canvas-submission.md) already recorded "decided not to make this unnecessarily AI-powered or agentic," and [19-open-questions-resolved.md](19-open-questions-resolved.md) §1 reconciled that into a two-tier design: mostly-heuristic tree ranking, with a single narrow LLM call reserved for genuinely ambiguous cases. **That reservation is now removed.** The system uses **no AI/LLM anywhere** — not as an orchestrator, not as a narrow tree-simplification fallback, not for intent-matching. Every mechanism is deterministic:

- Tree ranking/simplification: the heuristic scorer alone ([08-feature-ranking-auxiliary-tree.md](../tech/research/08-feature-ranking-auxiliary-tree.md)'s tier 1), with no tier-2 LLM escalation. An ambiguous case (no landmarks, flat scores, an unclassifiable element) resolves by a deterministic rule or a default, not a model call.
- Action dispatch: the confirm-then-dispatch loop ([04-agent-execution-layer.md](../tech/research/04-agent-execution-layer.md)) with the fused touch+voice intent matched to a tree node by deterministic logic (nearest/highest-ranked candidate), not an LLM tool-call.
- Everything already built this way stays as-is: calibration scoring, the ideal/fallback input mapping ([03-input-calibration.md](03-input-calibration.md) §3.2–3.3), the voice vocabulary classifier ([docs/desgin/desgin.md](../desgin/desgin.md)) — none of these ever used AI to begin with.
- Narration (if built): a fixed template/allowlist per screen state, not an LLM-generated summary — the request/response narration path in [03-proactive-narration.md](../tech/research/03-proactive-narration.md) needs re-reading with this constraint; its LLM-summarization step no longer applies as specified.

**Why this doesn't weaken the pitch:** it sharpens it. See [tech/research/15 — Google NAI Comparison](../tech/research/15-google-nai-comparison.md), researched specifically because this decision changes how the project compares to Google's Natively Adaptive Interfaces work — the differentiation is now "deterministic, auditable, free-to-run capability-profile system" versus NAI's "LLM-orchestrated adaptation," a cleaner contrast than the earlier "narrow AI use" framing allowed.

**Action items for the rest of the docs (not yet done, flagged here):**
- [07-architecture.md](07-architecture.md)'s "AI AGENT" box needs relabeling to a deterministic dispatch/ranking component — no LLM inside it.
- [docs/tech/README.md](../tech/README.md)'s "Not yet decided: which LLM provider/model for intent inference" item is now moot — remove or mark resolved as "none."
- [19-open-questions-resolved.md](19-open-questions-resolved.md) §1's tier-2 LLM fallback is superseded by this doc.

## 2. Demo task: mock UI is the primary demo; the real Google Form is a secondary, judge-requested demo

Resolves the still-open question in [09-open-questions.md](09-open-questions.md) and [19-open-questions-resolved.md](19-open-questions-resolved.md) §8 ("is the demo task WhatsApp read/reply, or another single bounded task?"):

- **Primary demo:** the self-built mock UI ([code/mock](../../code/mock/)) chaining several interaction patterns, run under both Profile A and Profile B. This is what's rehearsed and shown by default.
- **Secondary demo, on request:** a separate, real Google Form filled and submitted, shown only if judges specifically ask to see the system act on a real third-party surface. This keeps [05-scope.md](05-scope.md) item 2's "agent takes the final fused/confirmed input... and actually fills and submits the real form" claim available as proof, without making it a required beat of the main run-through.
- This slightly de-risks the primary demo (no dependency on Google Forms' live behavior/network during the main run) while keeping the "acts on a real target, not just our own mock" claim available for a deeper dive.

## 3. Open-source, public-good positioning — reaffirmed, not new

Restated because it came up again while prepping the presentation: this project has **no revenue model** and is being built for public good, intended to stay open source. This isn't a new decision — it's already the recommended positioning throughout [14-market-research.md](14-market-research.md) (§5, §6, §10) and named as an opening beat in [15-brain-dump.md](15-brain-dump.md) §15.1 ("say it plainly at the start: this is being built for public good, open source"). Recorded here only to confirm it stands alongside the two changes above, unchanged.

---

**How this connects to the rest of the docs:** items 1 and 2 are real scope changes and should propagate into [07-architecture.md](07-architecture.md), [docs/tech/README.md](../tech/README.md), and [05-scope.md](05-scope.md) directly (not yet done — flagged above); item 3 requires no doc changes, just confirms existing material. For presentation purposes, the "not an AI product" beat from [21-meeting-notes-presentation-prep.md](21-meeting-notes-presentation-prep.md) gets *stronger* under this decision — it's no longer "AI is narrow," it's "there is no AI," which is a cleaner, more memorable line for the stage.
