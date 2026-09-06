# 27. Meeting Notes — Visual Field Loss: Tunnel Vision & Peripheral-Only Vision (unverified transcript)

**Source:** voice memo, transcribed and lightly cleaned up, Sept 6 2026. Single speaker, no timestamp on the recording itself. Filed as [GitHub issue #4](https://github.com/saranskumar/startathon/issues/4); researched in [tech/research/14 — Visual Field Loss](../tech/research/14-visual-field-loss-tunnel-and-peripheral-vision.md).

---

## What was raised

The vision axis is under-built relative to touch and voice — high contrast is planned but not yet a distinct area of real design work. Two specific populations named, both under "partial blindness" but described with different needs:

1. **Tunnel vision** — someone who can only see a narrow area of the screen at a time, no matter where they look. Proposed fix: instead of a normal "condensed" screen layout, let input happen anywhere on the screen, but **condense the output into one part of the screen** rather than requiring the user to scan the whole thing.
2. **Peripheral-only vision** — someone who can only see using their peripheral vision (implying a central vision loss). Less developed as an idea — flagged as an area to research rather than a proposed fix, beyond a passing mention that high contrast might be part of the answer. Acknowledged as likely already well-researched territory worth pulling from existing work rather than reinventing.

## Research findings

See [tech/research/14](../tech/research/14-visual-field-loss-tunnel-and-peripheral-vision.md) for the full brief. Short version:

- **These are two clinically opposite conditions, not two names for one thing** — tunnel vision means retained *central* vision with lost *peripheral* vision; "peripheral-only vision" (as in macular degeneration) means the reverse, retained peripheral vision with a *central* blind spot (a scotoma). Per W3C's own low-vision accessibility guidance, the design fixes for the two can actively conflict (e.g. tunnel-vision users may want *smaller* text to fit more into their narrow window — the opposite of the usual low-vision "make it bigger" instinct) — so this has to be modeled as two distinct modes, never merged into one "partial vision" bucket.
- **The tunnel-vision instinct in the memo is exactly right and already has concrete guidance behind it**: single-column layout, shorter line lengths, keeping related content spatially close together, and (in a published case study) keeping sequential task steps in continuous, nearby screen regions rather than jumping focus around the screen — all validated design patterns for this population, not a novel idea needing invention.
- **The peripheral-only-vision case has a concrete, better-fitting answer than high contrast**: the standard compensatory technique for central vision loss is *eccentric viewing* (looking slightly off-target so an intact area of peripheral retina does the seeing), and existing reading apps built for this population (MD_evReader, EV News) present text as a **single scrolling line** rather than a static paragraph block, specifically because it reduces the eye-movement/scanning burden a damaged fovea can't support. This is a directly reusable, shipped pattern. High contrast still helps but is a secondary lever here, not the primary fix.
- **Calibration needs a new, small test** — a field-of-view map, not an acuity test (already covered separately by [09 — Vision Calibration](../tech/research/09-vision-calibration.md)). This reuses the touch axis's existing grid-point reachability test almost directly, just testing *visibility* instead of *reachability*.

## How this connects to the rest of the docs

This is new scope, not a restatement of the existing vision or touch calibration work:

- Add a `field_type` axis (`full | tunnel | central_loss`) to the capability profile, independent of the existing acuity-based `vision.mode` from [09 — Vision Calibration](../tech/research/09-vision-calibration.md) — a user can have good acuity and tunnel vision, or poor acuity and a full field; they're separate measurements.
- Build **two distinct rendering modes**, not one: tunnel-vision layout (single-column, capped visible-window width, spatially continuous task flow, text size left user-adjustable) and central-loss layout (single-line scrolling text, avoid small centered-only tap targets).
- Reuse the grid-point calibration mechanism already built for touch reachability ([03 — Input & Calibration](03-input-calibration.md) §3.1) for the new field-mapping test, rather than building new calibration UI from scratch.
- This sits in the same "vision axis is under-built" gap the memo itself named, alongside the high-contrast and screen-reader work already raised in [24 — Meeting Notes: Onboarding Entry & Accessibility](24-meeting-notes-onboarding-entry-and-accessibility.md) — worth planning together rather than as unrelated line items.
- Given two other voice-memo-raised threads ([24](24-meeting-notes-onboarding-entry-and-accessibility.md)/[11](../tech/research/11-accessible-entry-onboarding-and-contrast.md) and [25](25-meeting-notes-caregiver-training-mode.md)/[12](../tech/research/12-caregiver-guided-training-mode.md)) are already queued, this is realistically **roadmap, not event-build scope** — but it's now specified concretely enough to build directly whenever it is prioritized.

**Caveat: this is a single-speaker voice-memo transcript**, cleaned up for readability but not reviewed by the team as a settled decision, and the source idea was explicitly less developed than the voice-calibration idea in [26](26-meeting-notes-voice-vocabulary-calibration.md) — confirm scope/priority before treating any item here as locked.
