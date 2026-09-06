# 11. Accessible Entry, Onboarding, and Contrast

**Purpose:** Research brief for [GitHub issue #1](https://github.com/saranskumar/startathon/issues/1) and [docs/idea/24 — Meeting Notes: Onboarding Entry & Accessibility](../../idea/24-meeting-notes-onboarding-entry-and-accessibility.md). Covers four of that issue's five items: the calibration-entry bootstrapping problem, high-contrast theming, screen-reader announcement, and recorded-voice-vs-TTS onboarding. Item 5 (progressive input levels) is addressed separately in the connection notes at the end, since it turns out to be an architecture question about this project's own capability profile rather than an external research question.

**Headline verdict: the entry problem has a proven, cheap answer already shipped by both mobile OSes; the other three items are each "strong, build it" with one caveat apiece (don't require it, measure it honestly, and don't oversell it).**

---

## 1. The bootstrapping problem: how does a limited user trigger the app before it's configured for them?

This is a real, named problem, not a novel one: any accessible system has to be reachable *before* it knows anything about the user reaching for it. Both Android and iOS solve it the same way, and it's worth copying the pattern exactly rather than re-deriving it:

- **Android's accessibility shortcut**: holding both volume keys for a few seconds opens an accessibility-feature switcher, regardless of what's on screen or what app is running. ([support.google.com](https://support.google.com/accessibility/android/answer/7650693?hl=en))
- **iOS's Accessibility Shortcut**: triple-clicking the side button (or home button on older devices) toggles a configured accessibility feature (commonly VoiceOver) the same way, everywhere in the OS. ([support.apple.com](https://support.apple.com/en-us/111771))

The shared design principle: **the trigger is a fixed, content-independent physical action** (a hold, a multi-click), not a precisely-targeted on-screen button. A small "Start" or "I can do this myself" button reproduces the exact problem it's trying to solve — it's still a precision-gated target, just a differently-labeled one.

**Recommendation for this project:** the phone app's entry screen should offer a **large, full-screen (or near-full-screen) hold-anywhere / tap-anywhere gesture** as the self-start trigger, not a small button — consistent with the project's own existing rule in [code/app/README.md](../../../code/app/README.md) ("no calibration step can trap anyone... every test has a full-width skip"). A full-screen target is already the right shape; what's missing is applying that shape to the *entry point itself*, not just the steps after it.

**Caregiver path:** the two OS precedents above are single-purpose (turn on one thing). This project needs a second, distinct trigger for "someone else is setting this up for them" — since a caregiver doesn't need the forgiving full-screen gesture (they have full motor/vision control), a normal small button/link is fine for that path specifically. The two entry points should be visually simultaneous on the same first screen, not sequential (don't make the caregiver path *itself* gated behind the accessible one).

## 2. Caregiver involvement is a documented, under-served gap

A 2024 qualitative study on self-management apps for spinal cord injury found that **caregiver involvement in app setup and ongoing use is a real, currently-missing piece of accessible app design** — not a nice-to-have. ("Enhancing Self-Management Support Apps for Spinal Cord Injury: The Missing Role of Caregivers" — [PMC](https://pmc.ncbi.nlm.nih.gov/articles/PMC12011278/)) A broader usability study of an adaptive mobile-health system for people with disabilities reached the same conclusion from a different angle: caregiver presence during use, not just setup, materially affects whether the app gets used at all. ([PMC](https://pmc.ncbi.nlm.nih.gov/articles/PMC6658284/))

This directly supports building a first-class caregiver-triggered setup path (item 1 above) rather than treating "solo vs. assisted" as a checkbox inside a flow the solo user has to reach first.

## 3. High-contrast theme

WCAG's actual numeric bar: **4.5:1 contrast for normal text, 3:1 for large text (≥18pt, or ≥14pt bold), and 3:1 for non-text UI components/graphics** needed to operate the interface (WCAG 2.1 extended contrast rules beyond text). ([webability.io](https://www.webability.io/blog/color-contrast-for-accessibility); [levelaccess.com](https://www.levelaccess.com/blog/wcag-for-mobile-apps/))

Two things worth getting right, not just "add a dark theme":
- **A dark theme alone does not satisfy WCAG contrast** — contrast ratio is what's measured, not lightness direction; a poorly-chosen dark palette can fail the same 4.5:1/3:1 bar a light one does. ([boia.org](https://www.boia.org/blog/offering-a-dark-mode-doesnt-satisfy-wcag-color-contrast-requirements))
- **Support the OS-level setting, but don't require it.** iOS ("Increase Contrast") and Android ("High Contrast Text") both expose a system toggle apps can read and respect — but many users don't know the OS setting exists, so the app needs its own in-app high-contrast option too, not just a listener on the system flag. ([boia.org](https://www.boia.org/blog/accessibility-tips-using-accessible-colors-in-mobile-apps))

**Recommendation:** add a high-contrast palette as a peer to the existing "haiku" ability-blended theme ([code/app/lib/theme/haiku_theme.dart](../../../code/app/lib/theme/haiku_theme.dart)) — these answer different questions (haiku theme reflects *who the measured user is*; high-contrast is a *legibility floor* anyone can opt into) and shouldn't be merged into one theme axis. Verify the chosen palette against the 4.5:1/3:1 numbers directly rather than eyeballing "looks high contrast."

## 4. Screen-reader announcement (the "TalkBack thing")

The web-accessibility version of this is ARIA live regions: a `aria-live="polite"` region announces a change without interrupting the user, `assertive` interrupts immediately, and `aria-atomic` ensures the whole updated region is read rather than just the diff. ([sarasoueidan.com](https://www.sarasoueidan.com/blog/accessible-notifications-with-aria-live-regions-part-1/); [uxpin.com](https://www.uxpin.com/studio/blog/aria-live-regions-for-dynamic-content/)) That's the mechanism [code/desktop](../../../code/desktop/README.md) would use if its browser-facing UI ever needs it — but **this project's phone app is Flutter, not a web page, so the actual implementation surface is Flutter's own accessibility API, not ARIA**:

- `Semantics(liveRegion: true, ...)` around a widget makes screen readers (TalkBack/VoiceOver, since Flutter's semantics tree maps to both) announce changes to its descendants automatically — the direct Flutter analogue of `aria-live`. ([itnext.io](https://itnext.io/a-practical-guide-to-flutter-accessibility-part-1-the-basics-98f553be00bc); gskinner blog on Flutter screen-reader UX)
- The `selected` semantic flag is what should be set on whichever option is currently highlighted, so a screen reader announces "selected" as part of reading that item — this is the direct implementation of the issue's "say what the selected option is."
- `SemanticsService.announce` covers one-off announcements (e.g. on-load state) that don't map cleanly to a persistent live-region widget.

**Recommendation:** wrap the option lists already built in [code/app/lib/runtime](../../../code/app/lib/runtime) with `Semantics(selected: ...)` per item and a `liveRegion: true` wrapper around whichever container's current-selection changes during scanning/cycling (this matters most for the joystick/switch-scan interaction patterns, where the "current" item changes without a new screen being built). This is additive to what's already built — none of the existing input mechanics change, only what a screen reader is told about state that's already tracked internally.

## 5. Recorded human voice vs. text-to-speech for onboarding

The research here is genuinely mixed, not a clean win for either side — worth stating honestly rather than picking whichever citation supports the request:

- Older multimedia-learning research found a real "voice effect": human narration produced better retention and transfer scores than synthetic voice, and was rated as requiring less listening effort. ([files.eric.ed.gov](https://files.eric.ed.gov/fulltext/EJ1341358.pdf))
- But **practical accommodation studies comparing human read-aloud to TTS found no significant difference in actual task/assessment performance** — the comprehension-effort advantage didn't reliably translate into better outcomes. ([publications.ici.umn.edu](https://publications.ici.umn.edu/nceo/accommodations-toolkit-archives/text-to-speech-research))
- Modern TTS specifically narrows this gap: recent evaluations found **no significant difference between current realistic TTS and human voice**, where older studies (using older, more robotic TTS) did find a gap. ([files.eric.ed.gov](https://files.eric.ed.gov/fulltext/EJ1403866.pdf))

**Recommendation:** recorded voice for onboarding specifically is a defensible choice, not because TTS is proven worse in general, but because onboarding is small, fixed, high-stakes-to-get-right-the-first-time content (a handful of screens, said once, low volume) — exactly the case where the now-narrower "human voice is a bit easier to parse" edge is worth taking, and where the cost (one recording session) is trivial. **Don't extend this reasoning to open-ended or dynamic content** (agent narration, task results) — that's unbounded text a recording can't cover, and modern TTS's near-parity finding applies there instead. This keeps onboarding-audio and runtime-narration as two different, independently-justified decisions rather than one blanket "always use recordings" policy.

**Localization caveat, stated plainly because it's easy to skip past:** recorded audio does not localize for free — every language needs its own recording session, while TTS scales to a new language with (mostly) no new recording work. If "publish and implement the language feature" ([issue #1](https://github.com/saranskumar/startathon/issues/1)) means more than one or two launch languages, budget for re-recording as a real, recurring cost, not a one-time task.

---

## Connection to the rest of the docs

None of items 1–4 require new build infrastructure — they're additive to [code/app](../../../code/app/README.md)'s existing screens (entry screen, theme system, option lists, runtime views). Item 5 needs one asset decision (who records, in which languages, hosted how) rather than a new mechanism.

**Item 5 from the original issue — progressive input levels ("start at single tap, level up")** doesn't have an external research answer the way the other four do; it's a fit question against this project's own architecture, not a gap in the outside world. Today, [03 — Input & Calibration](../../idea/03-input-calibration.md) measures a capability profile **once**, at calibration time, and that profile is fixed for the session. "Start simple, offer to level up" implies the profile needs to be **revisited and re-scored over time**, with the option list defaulting to the fewest-choice starting method (single button / single switch — already the floor case per [03 §3.5](../../idea/03-input-calibration.md)) and only offering more complex methods once the user (or the data) shows readiness. That's a genuinely new idea not yet in [09 — Open Questions](../../idea/09-open-questions.md) or [19 — Open Questions: Resolved](../../idea/19-open-questions-resolved.md) — recommend adding it there as a scope question (does the profile stay a one-shot measurement, or become a thing that's revisited?) rather than deciding it here.
