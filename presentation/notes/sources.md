# Sources — where each pitch claim actually lives

Traceability map. Every fact in `outline.md` / `demo-clips.md` / `slides.html` is a **copy**. Edit the source of truth first, then re-sync.

**On-slide / spoken name:** KAI — Capability Awareness Interface (team, this pass). Refer to the person as **the user**.

| Claim / material | Source of truth | Used in |
|---|---|---|
| Event format: 5 min slides + 5 min demo + 5 min Q&A; max 5 slides | Event “Final Demo – Presentation Template” | `outline.md` header, `demo-clips.md`, `README.md` |
| Product name: KAI — Capability Awareness Interface | Team (this pass) | all slides, `outline.md` |
| User: a person with cerebral palsy; observed directly | [15](../../docs/idea/15-brain-dump.md) §15.1; [06](../../docs/idea/06-user-model.md), [13](../../docs/idea/13-event-submission.md) §1, [16](../../docs/idea/16-canvas-submission.md) — spoken as “the user,” not “he/brother” | slides 1–2 |
| WhatsApp island; one tap region; voice notes | [15](../../docs/idea/15-brain-dump.md) §15.1 | slide 1 |
| Assistant + “call amma”; caregiver for the rest | [15](../../docs/idea/15-brain-dump.md) §15.1; [01](../../docs/idea/01-problem.md) §1.3; [13](../../docs/idea/13-event-submission.md) §2 | slide 1 |
| Existing tools each need one complete ability | [01](../../docs/idea/01-problem.md) §1.1; [15](../../docs/idea/15-brain-dump.md) §15.2; [16](../../docs/idea/16-canvas-submission.md) | slides 1, 3 |
| Independence confined to one app | [01](../../docs/idea/01-problem.md) §1.3; [13](../../docs/idea/13-event-submission.md) §4 | slide 1 |
| Vision of this user — do not claim | Conflict: [15](../../docs/idea/15-brain-dump.md) vs [06](../../docs/idea/06-user-model.md)/[13](../../docs/idea/13-event-submission.md)/[16](../../docs/idea/16-canvas-submission.md) | `outline.md` only |
| Evidence: the user + community, observed | [16](../../docs/idea/16-canvas-submission.md); [13](../../docs/idea/13-event-submission.md) §4 | slide 2 |
| Assumption: we require AI / an AI agent would solve the user’s problem | Team; [11](../../docs/idea/11-risks.md), [07](../../docs/idea/07-architecture.md), [13](../../docs/idea/13-event-submission.md) §5–6, [16](../../docs/idea/16-canvas-submission.md) | slides 2, 5 |
| Dropped OpenClaw: overhead, security, latency | Team; [04 research](../../docs/tech/research/04-agent-execution-layer.md) §2; [17](../../docs/idea/17-meeting-notes-tree-simplification.md) | slides 2, 4 |
| Zero AI; heuristic DOM engine | [28](../../docs/idea/28-meeting-notes-scope-lock-no-ai.md); [08 research](../../docs/tech/research/08-feature-ranking-auxiliary-tree.md); [code/desktop/README.md](../../code/desktop/README.md) | slides 2–4 |
| Solution: profile + primitives runtime (not a screen per person) | [docs/app/README.md](../../docs/app/README.md); [02](../../docs/idea/02-core-model.md); [03](../../docs/idea/03-input-calibration.md) | slide 3 |
| Phone: tap/hold setup, caregiver training, axis-gated calibration, vocab, visual field, contrast | [docs/app/01-feature-inventory.md](../../docs/app/01-feature-inventory.md); [ui-ux-phone-flow](../../docs/desgin/ui-ux-phone-flow.md); idea 24–27 | slides 3–4 |
| Desktop: Playwright + ranking + act + zooming navigator; no LLM | [code/desktop/README.md](../../code/desktop/README.md) | slide 4 |
| Primary demo = mocks; Google Form secondary | [28](../../docs/idea/28-meeting-notes-scope-lock-no-ai.md) §2 | slide 4, demo notes |
| Speech simulated; phone unwired | [code/app/README.md](../../code/app/README.md); [docs/app/01-feature-inventory.md](../../docs/app/01-feature-inventory.md) | slides 4–5, demo |
| Formal user-beta of the built app is planned, not done | [16](../../docs/idea/16-canvas-submission.md) | slide 5 |
| Confirmation must not become constant interruption | [11](../../docs/idea/11-risks.md) | slide 5 |

Parked (not in this 5-slide deck): market size, open-source pitch, hardware analogy, competitor matrices.
