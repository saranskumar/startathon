# Sources — where each pitch claim actually lives

Traceability map. Every fact pulled into `outline.md` or `demo-clips.md` is a **copy**, not the original — the file listed under "Source of truth" is the one to edit first. After editing a source, re-check the note file(s) listed under "Used in" and update them to match.

| Claim / material | Source of truth | Used in |
|---|---|---|
| Origin story (Shreevardhan's brother, cerebral palsy, WhatsApp + Google Assistant anecdote) | [docs/idea/15-brain-dump.md](../../docs/idea/15-brain-dump.md) §15.1 | `outline.md` context slide |
| 15-minute total time limit and demo-first running order | [docs/idea/21-meeting-notes-presentation-prep.md](../../docs/idea/21-meeting-notes-presentation-prep.md) | `outline.md` header note and slide order, `demo-clips.md` budget note |
| Hardware analogy for adaptive input (foot trackball, tongue mouse vs. our software-only approach) | [docs/idea/21-meeting-notes-presentation-prep.md](../../docs/idea/21-meeting-notes-presentation-prep.md), cost framing corroborated by [docs/idea/14-market-research.md](../../docs/idea/14-market-research.md) §on dedicated AAC/access hardware | `outline.md` gap slide |
| "Not an AI product" correction (adaptive input is the core; AI only closes narrow inference gaps under confirmation) | [docs/idea/17-meeting-notes-tree-simplification.md](../../docs/idea/17-meeting-notes-tree-simplification.md), restated for the pitch in [docs/idea/21-meeting-notes-presentation-prep.md](../../docs/idea/21-meeting-notes-presentation-prep.md) | `outline.md` defensibility slide |
| "Who's already served" framing (screen reader / Voice Access / general AI agents each assume one clean channel) | [docs/idea/15-brain-dump.md](../../docs/idea/15-brain-dump.md) §15.2 | `outline.md` problem slide |
| Output-side worked examples (WhatsApp proactive narration, Bluetooth settings minimal-choice narration) | [docs/idea/15-brain-dump.md](../../docs/idea/15-brain-dump.md) §15.3 | `outline.md` solution slide |
| "Input is a fixed state machine, not AI" framing | [docs/idea/15-brain-dump.md](../../docs/idea/15-brain-dump.md) §15.4 | `outline.md` how-it-works slide |
| Not-a-revenue-pitch / open-source positioning | [docs/idea/14-market-research.md](../../docs/idea/14-market-research.md) §5, §6, §10 | `outline.md` closing slide |
| India assistive-tech market size (USD 2.5B → 3.6B, IMARC estimate) | [docs/idea/14-market-research.md](../../docs/idea/14-market-research.md) §2/§11 | `outline.md` market slide |
| Differentiation claim ("no one combines profile + fusion + inferring confirmation-gated agent") | [docs/tech/research/06-competitive-deep-dive.md](../../docs/tech/research/06-competitive-deep-dive.md) §5 recommended framing | `outline.md` differentiation slide |
| Dasher as prior art (free-text entry without speech or fine tapping; switch-access precedent) | [docs/tech/research/07-dasher-integration.md](../../docs/tech/research/07-dasher-integration.md) §7.2(b), §7.3 | `outline.md` prior-art slide, `demo-clips.md` Dasher clip |
| Locked demo scope (two profiles + a switch, five task shapes) | [docs/idea/05-scope.md](../../docs/idea/05-scope.md) | `outline.md` demo slide |
| Event-submission answers (problem/evidence/risk, verbatim finalized) | [docs/idea/13-event-submission.md](../../docs/idea/13-event-submission.md), [docs/idea/16-canvas-submission.md](../../docs/idea/16-canvas-submission.md) | `outline.md` throughout, phrasing sanity-check |

## Adding a new pulled claim

1. Add a row here first: claim, source file (with anchor if the doc is long), which note file(s) will use it.
2. Then write the copy into `outline.md` / `demo-clips.md`.
3. Keep the copy short — a sentence or two. If you need the full nuance, link to the source doc instead of duplicating it.
