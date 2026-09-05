# 9. Open Questions

## Resolved during pitch prep
| Question | Resolution |
|---|---|
| How is the profile represented and switched in the demo? | Shown to judges as a live calibration flow; see the flag below on whether this fully replaces a preset toggle. |
| Do we already have OpenClaw (or equivalent) running, or is agent plumbing itself unbuilt? | Nothing is built yet. Plan is to use existing open-source/third-party pieces (OpenClaw or equivalent, a TTS engine, LLM APIs) rather than building infra from scratch. |
| Should touch method calibration test one method at a time (ordered fallback) or all methods (pick best score)? | Test all three (buttons, joystick, trackpad), pick by normalized score. See [03 — Input & Calibration](03-input-calibration.md) §3.1. |
| Should task-aware input switching be a live agent/LLM decision, or a fixed mapping? | Fixed mapping per task, decided at design time — not live. See [03 — Input & Calibration](03-input-calibration.md) §3.2. |
| Should the multi-input calibration be scripted/staged or genuinely functional? | Team decided: fully functional across all inputs, not staged. Flagged in [05 — Locked Scope](05-scope.md) as a real scope expansion with a scripted fallback available if time runs out. |

## Still open
| Question | Why it matters |
|---|---|
| Are Profile A and Profile B ([06 — User Model](06-user-model.md)) the final two demo points, or different coordinates? | These two points *are* the proof of the spectrum thesis |
| Is the demo task WhatsApp read/reply, or another single bounded task? | Need one task demoable under both profiles; also determines which two interaction patterns from [03 — Input & Calibration](03-input-calibration.md) §3.3 actually need to be built |
| Does "fully functional calibration" replace the preset-toggle plan, or do both coexist (real per-method scoring, but the demo is still steered to land on preset A/B for reliability)? | Affects how much of the calibration engine's *output* actually drives the live demo vs. how much is a reliability safety net |
| Which narration approach for the "no vision" output — TTS of agent summaries, at minimum? | Output composition needs at least one working non-visual mode |
| How exactly is vision calibrated? | [03 — Input & Calibration](03-input-calibration.md) §3.1 flags this as unresolved — direct question vs. shrinking-text test |
