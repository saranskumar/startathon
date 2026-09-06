# 24. Meeting Notes — Onboarding Entry & Accessibility Hardening (unverified transcript)

**Source:** voice memo, transcribed and lightly cleaned up, Sept 6 2026. Single speaker, no timestamp on the recording itself. Filed as [GitHub issue #1](https://github.com/saranskumar/startathon/issues/1); researched in [tech/research/11 — Accessible Entry, Onboarding, and Contrast](../tech/research/11-accessible-entry-onboarding-and-contrast.md).

---

## What was raised

**The calibration entry flow doesn't work for the user it's for.** Today, starting calibration means pressing a "start"/"calibrate me" button and choosing whether the user is doing it alone or with a caregiver. The problem: a user limited enough to need this app may not be able to reliably press that specific button either — the entry point itself can be harder to operate than anything calibration goes on to measure. Two things are needed instead: a way for the user to trigger "I can do this myself" regardless of how limited they are at that exact moment, and a separate, faster way for a caregiver/helper to trigger setup on the user's behalf. Calibration itself was called out as already working — this is specifically about the *starting* part.

**No high-contrast theme.** Raised as a straightforward gap to close.

**No screen-reader support ("the TalkBack thing").** Each option in a list should be read out; whichever option is currently highlighted/selected should be spoken as such, not just visually indicated.

**Onboarding narration should be recorded voice, not TTS**, specifically for the initial onboarding — the reasoning given was that recorded speech is easier to understand than a text-to-speech model. Alongside this, publishing and supporting a language feature (localization) was raised as something to figure out.

**Progressive input complexity.** Rather than every user going through the same onboarding path immediately, start everyone at the simplest possible method (e.g. single-tap/one button), then give them the choice to keep using that or level up to more advanced input (one button → two buttons → multi-choice, etc.) — described as "that's the path," i.e. a progression, not a one-shot classification.

## Research findings

See [tech/research/11](../tech/research/11-accessible-entry-onboarding-and-contrast.md) for the full brief. Short version:

- **Entry/bootstrapping** has a proven answer already shipped by both mobile OSes: a fixed, content-independent physical gesture (Android's hold-both-volume-keys accessibility shortcut, iOS's triple-click accessibility shortcut) rather than a precisely-targeted button. Recommend a full-screen hold/tap-anywhere gesture for the self-start path, and a normal small control for the caregiver path, shown simultaneously rather than sequentially.
- **Caregiver involvement in setup is a documented, under-served gap** in accessible self-management apps generally, per a 2024 SCI-focused usability study — not a niche request.
- **High contrast** has concrete WCAG numbers to build against (4.5:1 normal text, 3:1 large text/UI components) and should be an in-app option, not just a listener on the OS-level toggle most users won't know exists.
- **Screen-reader support** on this project's actual Flutter phone app means `Semantics(liveRegion: true)` and the `selected` semantic flag — the direct analogue of ARIA live regions, but implemented in Flutter's own accessibility API rather than ARIA (ARIA applies to [code/desktop](../../code/desktop/README.md)'s browser-facing UI, not the phone app).
- **Recorded voice vs. TTS** research is genuinely mixed, not a clean win either way — but recorded voice is a defensible choice specifically for onboarding (small, fixed, high-stakes-once content), while dynamic/open-ended narration should stay TTS. Localization of recorded audio is a real recurring cost (re-recording per language), not free the way TTS scaling is.
- **Progressive input levels** isn't an external research question — it's a fit question against this project's own architecture, since the capability profile is currently measured once and treated as fixed. Flagged as a new open question below rather than decided here.

## Open question this surfaces, not yet in [09](09-open-questions.md) or [19](19-open-questions-resolved.md)

**Does the capability profile stay a one-shot measurement, or become something revisited over time?** "Start simple, offer to level up" only works if the profile/method assignment can be re-scored later, not just measured once at calibration and fixed for the session. This needs a team decision, not research — see [tech/research/11](../tech/research/11-accessible-entry-onboarding-and-contrast.md)'s closing section.

## How this connects to the rest of the docs

None of items 2–4 (contrast, screen-reader support, onboarding audio) require new architecture — they're additive to [code/app](../../code/app/README.md)'s existing entry screen, theme system, and option-list widgets. Item 1 (entry flow) and item 5 (progressive levels) are real design changes: item 1 to the entry screen specifically (not calibration itself, which was confirmed working), and item 5 to whether the profile is a single measurement or a living one. Recommend folding the entry-flow fix and the high-contrast/screen-reader items into [code/app/README.md](../../code/app/README.md)'s "deliberate design decisions" list once built, the same way earlier decisions there were recorded.

**Caveat: this is a single-speaker voice-memo transcript**, cleaned up for readability but not reviewed by the team as a settled decision. Confirm scope/priority before treating any item here as locked.
