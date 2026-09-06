# Sources — where each pitch claim actually lives

Traceability map. Every fact in `outline.md` / `demo-clips.md` / `slides.html` is a **copy**. Edit the source of truth first, then re-sync.

| Claim / material | Source of truth | Used in |
|---|---|---|
| Event format: 5 min slides + 5 min demo + 5 min Q&A; max 5 slides | Event “Final Demo – Presentation Template” (this pass) | `outline.md` header, `demo-clips.md`, `README.md` |
| Specific user: family member / Shreevardhan's brother, cerebral palsy | [docs/idea/15-brain-dump.md](../../docs/idea/15-brain-dump.md) §15.1; [06](../../docs/idea/06-user-model.md), [13](../../docs/idea/13-event-submission.md) §1, [16](../../docs/idea/16-canvas-submission.md) | slides 1–2 |
| WhatsApp island; one tap region; voice notes | [15](../../docs/idea/15-brain-dump.md) §15.1 | slide 1 |
| Assistant + “call amma”; caregiver for the rest | [15](../../docs/idea/15-brain-dump.md) §15.1; [01](../../docs/idea/01-problem.md) §1.3; [13](../../docs/idea/13-event-submission.md) §2 | slide 1 |
| Existing tools each need one complete ability | [01](../../docs/idea/01-problem.md) §1.1; [15](../../docs/idea/15-brain-dump.md) §15.2; [16](../../docs/idea/16-canvas-submission.md) | slides 1, 3 |
| Independence confined to one app | [01](../../docs/idea/01-problem.md) §1.3; [13](../../docs/idea/13-event-submission.md) §4 | slide 1 |
| Vision of this user — do not claim | Conflict: [15](../../docs/idea/15-brain-dump.md) “can see fine” vs [06](../../docs/idea/06-user-model.md)/[13](../../docs/idea/13-event-submission.md)/[16](../../docs/idea/16-canvas-submission.md) | `outline.md` only |
| Evidence: brother + others, observed | [16](../../docs/idea/16-canvas-submission.md); [13](../../docs/idea/13-event-submission.md) §4 | slide 2 |
| Assumption tested: that we require AI / an AI agent would solve his problem | Team (this pass); earlier framing in [11](../../docs/idea/11-risks.md), [07](../../docs/idea/07-architecture.md), [13](../../docs/idea/13-event-submission.md) §5–6, [16](../../docs/idea/16-canvas-submission.md) | slides 2, 5 |
| Observation: specific inputs work; Assistant (an AI) already fails; mapping is the bottleneck | [16](../../docs/idea/16-canvas-submission.md); [15](../../docs/idea/15-brain-dump.md) §15.1 | slide 2 |
| Dropped OpenClaw for performance overhead, security issues, and latency — not cost alone | Team (this pass); [04 research](../../docs/tech/research/04-agent-execution-layer.md) §2 (capability surface, CVEs, confirmation-gating); [17](../../docs/idea/17-meeting-notes-tree-simplification.md) (latency); [16](../../docs/idea/16-canvas-submission.md) | slides 2, 4 |
| No AI; heuristic DOM engine instead | [08 research](../../docs/tech/research/08-feature-ranking-auxiliary-tree.md); [docs/tech/README.md](../../docs/tech/README.md); [code/desktop/README.md](../../code/desktop/README.md); origin idea/28 | slides 2, 3, 4 |
| Brother-beta of the built app is planned, not done | [16](../../docs/idea/16-canvas-submission.md) “How will you test it?” | slide 2 honesty; slide 5 next week |
| Solution: measure, compose residual abilities, touch selects / voice fills | [02](../../docs/idea/02-core-model.md); [03](../../docs/idea/03-input-calibration.md); [04](../../docs/idea/04-goals.md) §4.2 | slide 3 |
| Phone input layer is the product / smallest useful thing | [04](../../docs/idea/04-goals.md) §4.2; [16](../../docs/idea/16-canvas-submission.md) | slides 3–4 |
| Phone build: 7-step calibration, 4×4 matrix, fusion; speech stubbed; intents stop on strip | [code/app/README.md](../../code/app/README.md) | slide 4, demo notes |
| Desktop: Playwright + heuristic ranking + act; no LLM; phone unwired | [code/desktop/README.md](../../code/desktop/README.md); [docs/tech/README.md](../../docs/tech/README.md) | slide 4 |
| Browser tree only; mocks (Aperture Daily) | [docs/tech/README.md](../../docs/tech/README.md); [code/mock](../../code/mock/) | slide 4 |
| STT/TTS need a package; not decided | [docs/tech/README.md](../../docs/tech/README.md); [22 methods](../../docs/idea/22-input-methods-scope.md) | slides 4–5 |
| Success = same system, two profiles / more independent function | [04](../../docs/idea/04-goals.md) §4.4; [16](../../docs/idea/16-canvas-submission.md) support/weaken | slide 5 |
| Confirmation must not become constant interruption | [11](../../docs/idea/11-risks.md) | slide 5 |

Parked (not in this 5-slide deck): market size, open-source pitch, hardware analogy, Dasher citation, NAI comparison tables, competitor matrices.
