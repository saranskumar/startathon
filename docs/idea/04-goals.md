# 4. Goals

## 4.1 Product goals
- Represent each user as a capability profile across touch / speech / vision axes.
- **Compose input**: fuse the user's available partial abilities (touch + voice) into one interaction rather than forcing a single modality.
- **Compose output**: deliver results in the mode the user can perceive — normal screen, large text, or proactive real-time narration.
- Adapt **interface resolution** (control count/size, reachable zone) to the touch profile.
- Adapt **which input method** (buttons/joystick/trackpad) is used per task, constrained by calibration — see [03 — Input & Calibration](03-input-calibration.md).
- Use an AI agent to perform the actual computer actions and to fill inference gaps when input is imprecise, always confirming consequential actions.

## 4.2 What the innovation is (state explicitly in the pitch)
The product is **not the AI agent** — agents that take instructions and act on a computer already exist. The product is the **capability-profile-driven adaptive I/O layer** that composes each user's actual abilities into a usable interaction — per-user (calibration) and per-task (input mapping) — so users are not confined to a fixed interface built for one assumed impairment point.

## 4.3 Non-goals (out of scope for the MVP)
- A fully native on-device accessibility OS shell. The phone is a **remote control / thin client** by design, so the idea can be validated on existing agent infrastructure (e.g. OpenClaw) rather than building a platform first.
- Covering the entire spectrum in the demo. The build proves the model with **two points on the spectrum and a profile switch between them** — not the whole continuum (see [05 — Locked Scope](05-scope.md)).
- Perfect free-form transcription. Coarse, patient intent recognition is enough for v1 when speech is unclear.
- Every app/workflow. One bounded task for the demo.
- The full task-shape × input-method matrix from [03 — Input & Calibration](03-input-calibration.md) §3.4 — only the two interactions the demo actually needs.

## 4.4 Success metric (north star)
The system, **unchanged**, serves **two different capability profiles** on the same task — producing two different composed interfaces, both of which let the user complete the task using only the abilities they actually have.

Secondary (with a representative/proxy user):
- Independent task-completion rate (no external help)
- Time + error count vs. the user's current method (existing tool or caregiver-assisted)
- Whether the composed interface matched what the user could actually operate
