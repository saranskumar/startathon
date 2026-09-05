# 6. User Model & Example Profiles

**Primary user:** anyone whose ability coordinates don't line up with a single existing fixed-point tool — prominently including people with overlapping motor / speech / visual limitations, but defined by *coordinates*, not diagnosis.

**Explicitly de-emphasized for v1:** users who sit exactly on an axis a mature tool already serves well (e.g. zero vision + full motor + good navigation patience → an ordinary screen reader is fine). Our value is the *combinations* those tools miss.

**Inspiration:** this idea is inspired by a team member's brother, who is affected across all three modeled axes (touch precision, speech clarity, and vision) at once — meaning no single mainstream tool built for one fixed impairment point fits him. See [13 — Event Submission](13-event-submission.md) for how this is framed for judges.

**Illustrative profiles (used as the demo's two points — see [05 — Locked Scope](05-scope.md)):**

*Profile A — "big-zone, no speech":*
```
touch:  { min_target_size: large, max_controls: 2, reachable_zone: bottom-half }
speech: { available: false, clarity_level: none }
vision: { mode: screen }
```
→ Composed interface: 2 large touch zones, no voice input, screen output.

*Profile B — "fused touch + slurred speech, low vision":*
```
touch:  { min_target_size: medium, max_controls: 4, reachable_zone: full }
speech: { available: true, clarity_level: partial }
vision: { mode: large / none }
```
→ Composed interface: more/medium controls for selection **plus** patient voice input for content, **plus** proactive narration output.

The single most important demo moment is switching from Profile A to Profile B and watching the **same system** reshape the interface.
