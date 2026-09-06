# 14. Visual Field Loss — Tunnel Vision vs. Peripheral-Only Vision, and What Each Needs

**Research date:** 6 September 2026
**Purpose:** Research brief for [GitHub issue #4](https://github.com/saranskumar/startathon/issues/4) and [docs/idea/27 — Meeting Notes: Visual Field Loss](../../idea/27-meeting-notes-visual-field-loss.md). This is a genuinely new axis — [09 — Vision Calibration](09-vision-calibration.md) covers acuity (can-you-read-this-size-text), not visual *field* shape, and neither [02 — Core Model](../../idea/02-core-model.md) nor [03 — Input & Calibration](../../idea/03-input-calibration.md) currently distinguishes "how much of the screen can this person see at once, and where."

**Headline verdict: real, well-documented, and the two conditions the idea names are opposites of each other with opposite design fixes — this needs to be modeled as two distinct field-loss types, not one "partial blindness" bucket, or the fix for one actively harms the other.** Concrete design guidance exists for both, sourced from W3C's own low-vision accessibility requirements plus academic tunnel-vision-simulation and eccentric-viewing research — this is not a gap requiring invention, it's an under-modeled axis with existing answers to adopt.

---

## 1. The two conditions named in the idea are opposite field-loss shapes, not two names for the same thing

The idea's phrasing ("tunnel vision... or people who can only see in their peripheral vision") names two clinically distinct and functionally *opposite* conditions:

- **Peripheral field loss ("tunnel vision")** — the person retains only the **central** portion of their visual field and has lost peripheral vision. Commonly caused by retinitis pigmentosa or advanced glaucoma. They see a narrow "tunnel" wherever they're looking, and see nothing outside it. ([W3C Low Vision Accessibility Requirements](https://www.w3.org/TR/low-vision-needs/))
- **Central field loss ("peripheral-only vision")** — the person has lost **central** vision (often a scotoma, a blind or blurred spot in the middle of the visual field) and relies on their **peripheral** vision, which remains intact. Commonly caused by age-related macular degeneration (AMD) or juvenile macular dystrophies. ([W3C Low Vision Accessibility Requirements](https://www.w3.org/TR/low-vision-needs/); [Eccentric Viewing — Spectrios Institute for Low Vision](https://spectrios.org/eccentric-viewing/))

**This distinction is the single most important finding in this brief, because the design fixes are opposite, not complementary.** W3C's own guidance states plainly that low-vision user needs vary widely and *sometimes actively conflict* — what helps one field-loss type can actively hurt the other (e.g., tunnel-vision users may prefer *smaller* text to fit more into their narrow visible window, which is the opposite of the large-text instinct that helps most other low-vision users, including central-field-loss users). Any implementation must treat these as two separate calibration outcomes, not one "blur everything a bit" mode.

## 2. Tunnel vision (peripheral field loss): condense, don't spread — this validates the idea's own instinct exactly

The idea proposed: *"instead of making them scan the whole screen for the output, condense the information into one part of the screen."* This is directly validated by existing accessibility guidance, not a novel insight needing separate proof:

- **W3C's concrete recommendations for peripheral field loss**: single-column layout instead of multi-column designs (avoids requiring the eye to scan between separated regions the narrow field can't see simultaneously); shorter line lengths (so more of a line fits inside the visible window at once); flexible text resizing without introducing horizontal scrolling; and keeping related information physically close together rather than spread across the screen. ([W3C Low Vision Accessibility Requirements](https://www.w3.org/TR/low-vision-needs/))
- **A ticket-machine redesign case study** (from an ACM Web4All paper on tunnel-vision simulation in design) found that emphasizing *continuity between required action areas* — i.e. keeping the next thing the user needs to look at spatially close to the last thing, rather than jumping across the screen — produced a measurably more usable interface for peripheral-field-loss users. This is the same "condense into one region" idea, applied to sequential task flow rather than static layout. ([Exploring the Role of Tunnel Vision Simulation in the Design Cycle of Accessible Interfaces — ACM Web4All 2018](https://dl.acm.org/doi/10.1145/3192714.3192822))
- **Gaze-contingent tunnel-vision simulators** exist as a validated *design-testing tool* — letting sighted designers experience a restricted field of view live while using a screen — which is a cheap, real technique worth citing for validating this project's own tunnel-vision UI mode during development, not just building blind to how it feels. ([Eye Movement Training and Suggested Gaze Strategies in Tunnel Vision — PMC](https://www.ncbi.nlm.nih.gov/pmc/articles/PMC4924791/))

**Verdict: Strong feasibility, and a close match to the idea as stated.** Concrete, actionable build target: a display mode that (a) forces single-column layout, (b) caps line/content width to a configured "visible window" size (itself a candidate calibration parameter — see §4), (c) keeps sequential task steps spatially co-located rather than relocating focus across the screen between steps, and (d) does **not** force large text — text size should stay a separate, user-controlled axis, since tunnel-vision users may specifically want it *smaller* to fit more per screenful.

## 3. Central/peripheral-only vision (e.g. macular degeneration): the opposite fix — move content out of the blind center, or exploit an off-center anchor

The idea's instinct here was less specified ("I don't know much about it... maybe high contrast or something") — this is the area needing real research rather than validating an existing instinct, and the answer is a well-established clinical/assistive-tech technique, not high contrast:

- **Eccentric viewing (EV)** is the standard compensatory technique people with central scotomas already use, spontaneously or via training: instead of looking directly at something (which points the blind central scotoma right at it), the person looks *slightly off* from the target so an intact area of peripheral retina — a self-adopted **"preferred retinal locus" (PRL)** — does the seeing instead. This is a *user* technique, not a screen-design technique, but it has a direct UI implication: **content must not require being looked at dead-center to be perceived**, because dead-center is exactly the blind spot for this population. ([What is Eccentric Viewing? — MacularDegeneration.net](https://maculardegeneration.net/living/eccentric-viewing); [Eccentric Viewing — Spectrios Institute](https://spectrios.org/eccentric-viewing/))
- **A concrete shipped design pattern exists and is directly reusable**: apps built specifically for central-field-loss reading (**MD_evReader**, **EV News**) present text as a **single scrolling line** (ticker-style) rather than a static paragraph block. This reduces the eye-movement burden (the reader doesn't need to make large saccades across a paragraph, which is exactly what's hard when the fovea can't anchor scanning) and reduces perceptual crowding, both measurably improving reading performance for this population in published evaluation. This is a far more specific and better-fit answer than generic high contrast, and it's a pattern this project can adopt wholesale for any long-form text output rather than reinventing. ([The value of Tablets as reading aids for individuals with central visual field loss — PMC](https://www.ncbi.nlm.nih.gov/pmc/articles/PMC4999034/))
- **High contrast still helps, but it's a separate, smaller lever here** — it improves legibility of whatever falls on functioning retina, but doesn't address the structural problem (content assumes a working fovea) the way relocating/re-flowing content does. Worth keeping as an additive setting, not the primary fix for this population.

**Verdict: Moderate-to-Strong feasibility, and now well-specified where the idea previously wasn't.** Concrete, actionable build target: a scrolling single-line ("ticker") text-presentation mode for this field-loss type, reusing the MD_evReader/EV News pattern directly, plus avoiding UI patterns that require fixating a small central target (small centered icons/buttons with no larger surrounding hit/visual area) in favor of edge-anchored or full-width elements.

## 4. Calibration: this needs its own test, distinct from acuity ([09](09-vision-calibration.md)) and distinct from the touch axes ([03](../../idea/03-input-calibration.md))

Neither existing vision calibration ([09 — Vision Calibration](09-vision-calibration.md), a shrinking-text acuity check) nor the touch/voice axes measure *field shape* — a user could have perfect acuity in their remaining field and still be fully affected by this axis. This needs a new, small calibration primitive:

- **A field-mapping test, not a size test**: show target content at varying screen positions (e.g. center vs. each of the four screen edges/corners, or a small moving/appearing marker) and ask the user to confirm/tap when they can see it — this is structurally the same "reachable zone" test [03 §3.1](../../idea/03-input-calibration.md) already runs for touch (tap a grid of points, record which register), just measuring *visibility* instead of *reachability*. This reuse is worth calling out explicitly: the grid-point test infrastructure built for touch calibration is directly repurposable for field-of-view calibration with almost no new mechanism, just a different response channel (confirm-you-saw-it vs. successfully-tapped-it).
- **Output should be a field-shape tag plus a size parameter**, not a single score: `field_type: full | tunnel | central_loss`, plus (for `tunnel`) the effective visible-window size to size-constrain layout against, and (for `central_loss`) which off-center direction/PRL the person favors, if it can be cheaply inferred (e.g. from which grid points they confirm fastest/most reliably) — though a simpler v1 can skip PRL-direction personalization and just apply the single-line-scroll pattern uniformly, since that pattern doesn't require knowing the user's specific PRL direction to help.

## 5. How this connects to the rest of the docs

This is new scope, not a restatement of [09 — Vision Calibration](09-vision-calibration.md) (acuity) or [03 — Input & Calibration](../../idea/03-input-calibration.md) (touch/voice). Recommend:

- Adding a **`field_type` axis** to the capability profile alongside the existing `vision.mode` (screen/large/none) from [09](09-vision-calibration.md) — the two are independent (a user can have good acuity and tunnel vision, or poor acuity and a full field).
- Treating **tunnel-vision layout** (single-column, capped content width, spatial continuity between task steps) and **central-loss layout** (single-line scrolling text, avoid small centered-only targets) as two distinct rendering modes, never merged into one "partial vision" mode — per §1, applying one's fix to the other's population actively works against them.
- Reusing the existing grid-point calibration mechanism from [03 §3.1](../../idea/03-input-calibration.md) for the field-mapping test (§4 above), rather than building new calibration UI from scratch.
- Flagging this alongside high contrast and screen-reader support as further items in the accessibility-hardening thread already opened by [24 — Meeting Notes: Onboarding Entry & Accessibility](../../idea/24-meeting-notes-onboarding-entry-and-accessibility.md) / [11 — Accessible Entry, Onboarding, and Contrast](11-accessible-entry-onboarding-and-contrast.md) — same general "the visually-impaired axis is under-built relative to touch/voice" gap the idea's author identified.

**This is genuinely roadmap, not event-build scope** given the two other threads ([24](../../idea/24-meeting-notes-onboarding-entry-and-accessibility.md)/[11](11-accessible-entry-onboarding-and-contrast.md) and [25](../../idea/25-meeting-notes-caregiver-training-mode.md)/[12](12-caregiver-guided-training-mode.md)) already queued ahead of it — but it's now well-specified enough to build from directly whenever it's prioritized, rather than needing further research first.

**App status (Sept 2026):** the current yellow-square / dim-outside overlay is being **removed**. It is not the layout this brief describes. When tunnel vision is implemented later, **all buttons, text, and options live inside that square** (condensed working window), not spread across the full screen with a spotlight on top. Tracked in [app/04](../../app/04-clarity-playground-and-field.md).

---

## Overall verdicts

| Sub-topic | Verdict | Concrete build target |
|---|---|---|
| Tunnel vision / peripheral field loss layout | Strong — validates the idea's own instinct | Single-column layout, capped visible-window width, spatial continuity between sequential steps, text size kept user-adjustable (not forced large) |
| Central field loss / peripheral-only vision layout | Moderate-to-Strong — corrects and sharpens the idea's own uncertainty | Single-line scrolling ("ticker") text presentation (MD_evReader/EV News pattern); avoid small centered-only targets; high contrast as an additive, not primary, lever |
| Treating both as one "partial vision" mode | Explicitly wrong per W3C's own guidance | Must be modeled as two distinct field-loss types with opposite fixes |
| Calibration for field shape | New primitive needed, but reuses existing infrastructure | Reuse the touch axis's grid-point test mechanism, repurposed to test visibility instead of reachability |

---

## Sources

- [Accessibility Requirements for People with Low Vision — W3C](https://www.w3.org/TR/low-vision-needs/)
- [Exploring the Role of Tunnel Vision Simulation in the Design Cycle of Accessible Interfaces — ACM Web4All 2018](https://dl.acm.org/doi/10.1145/3192714.3192822) / [ResearchGate copy](https://www.researchgate.net/publication/326363698_Exploring_the_Role_of_Tunnel_Vision_Simulation_in_the_Design_Cycle_of_Accessible_Interfaces)
- [Eye Movement Training and Suggested Gaze Strategies in Tunnel Vision — A Randomized and Controlled Pilot Study — PMC4924791](https://www.ncbi.nlm.nih.gov/pmc/articles/PMC4924791/)
- [Tunnel vision — Wikipedia](https://en.wikipedia.org/wiki/Tunnel_vision)
- [What is Eccentric Viewing? — MacularDegeneration.net](https://maculardegeneration.net/living/eccentric-viewing)
- [Eccentric Viewing: Powerful Tool for Living with Low Vision — Spectrios Institute for Low Vision](https://spectrios.org/eccentric-viewing/)
- [Eccentric Viewing for Macular Degeneration — WebRN Macular Degeneration](https://www.webrn-maculardegeneration.com/eccentric-viewing.html)
- [The value of Tablets as reading aids for individuals with central visual field loss: an evaluation of eccentric reading with static and scrolling text — PMC4999034](https://www.ncbi.nlm.nih.gov/pmc/articles/PMC4999034/)
- [Cortical Thickness Related to Compensatory Viewing Strategies in Patients With Macular Degeneration — PMC8517450](https://www.ncbi.nlm.nih.gov/pmc/articles/PMC8517450/)
- [09 — Vision Calibration (this project's own thread, cross-referenced throughout)](09-vision-calibration.md)
- [03 — Input & Calibration (this project's own doc, cross-referenced throughout)](../../idea/03-input-calibration.md)
