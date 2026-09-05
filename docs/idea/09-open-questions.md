# 9. Open Questions

## Resolved during pitch prep
| Question | Resolution |
|---|---|
| How is the profile represented and switched in the demo? | Shown to judges as a live calibration flow; see the flag below on whether this fully replaces a preset toggle. |
| Do we already have OpenClaw (or equivalent) running, or is agent plumbing itself unbuilt? | Nothing is built yet. Plan is to use existing open-source/third-party pieces (OpenClaw or equivalent, a TTS engine, LLM APIs) rather than building infra from scratch. |
| Should touch method calibration test one method at a time (ordered fallback) or all methods (pick best score)? | Test all three (buttons, joystick, trackpad), pick by normalized score. See [03 — Input & Calibration](03-input-calibration.md) §3.1. |
| Should task-aware input switching be a live agent/LLM decision, or a fixed mapping? | Fixed mapping per task, decided at design time — not live. See [03 — Input & Calibration](03-input-calibration.md) §3.2. |
| Should the multi-input calibration be scripted/staged or genuinely functional? | Team decided: fully functional across all inputs, not staged. Flagged in [05 — Locked Scope](05-scope.md) as a real scope expansion with a scripted fallback available if time runs out. |
| What happens if a user scores low on every touch method and has no usable speech? | A fourth input method, single-switch scanning, is the answer — but it's a prepared pitch answer, not built or demoed. See [03 — Input & Calibration](03-input-calibration.md) §3.5. |
| Should the fallback rule use an absolute score threshold or a relative comparison? | Relative: use the task's ideal method unless a different method scores meaningfully higher for this user. See [03 — Input & Calibration](03-input-calibration.md) §3.3. |
| Should task-to-method mapping account for item count (long lists)? | Yes — large-N discrete choice gets agent-assisted voice/text filtering down to a small N first, then the normal per-method pattern applies. See [03 — Input & Calibration](03-input-calibration.md) §3.2. |
| What does the "sounds" speech-clarity tier actually enable? | Binary confirm/cancel only (presence of vocalization) — not treated as equivalent to `none`. See [03 — Input & Calibration](03-input-calibration.md) §3.1. |
| Is the demo task WhatsApp read/reply, or another single bounded task? | Changed from the original v3 plan: a custom mock UI chaining several interaction patterns (scroll selector, card-grid choice, tab switcher, more TBD) that ends in filling a real Google Form built for the demo — the agent actually submits it. This drops the dependency on a real third-party app + agent integration (a previously flagged top risk) in favor of a self-built surface, while keeping "agent acts on the real world" true via the real form submission. See [05 — Locked Scope](05-scope.md). |
| Is the card-grid step large-N (triggers the voice-filter-first rule) or small-N? | Small-N — plain discrete-choice selection, no filter step needed for the demo. |

## Still open
| Question | Why it matters |
|---|---|
| Are Profile A and Profile B ([06 — User Model](06-user-model.md)) the final two demo points, or different coordinates? | These two points *are* the proof of the spectrum thesis |
| Is the demo task WhatsApp read/reply, or another single bounded task? | Need one task demoable under both profiles; also determines which two interaction patterns from [03 — Input & Calibration](03-input-calibration.md) §3.3 actually need to be built |
| Does "fully functional calibration" replace the preset-toggle plan, or do both coexist (real per-method scoring, but the demo is still steered to land on preset A/B for reliability)? | Affects how much of the calibration engine's *output* actually drives the live demo vs. how much is a reliability safety net |
| Which narration approach for the "no vision" output — TTS of agent summaries, at minimum? | Output composition needs at least one working non-visual mode |
| How exactly is vision calibrated? | [03 — Input & Calibration](03-input-calibration.md) §3.1 flags this as unresolved — direct question vs. shrinking-text test |
| `steadiness` is in the capability profile schema ([02 — Core Model](02-core-model.md) §2.3) but no calibration test currently produces it | Either add a cheap measurement (e.g. count accidental/extra taps during the existing target tests) or drop the field for MVP so the schema doesn't overpromise |
| Exact order and full list of interaction-pattern screens inside the custom mock UI | Determines total build size; user said this can be decided later |
| Exact fields/content of the real Google Form being built for the demo | Needed before the agent's fill+submit step can be built |
