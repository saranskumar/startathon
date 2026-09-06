# 26. Meeting Notes — Sentence-Based Voice Vocabulary Calibration (unverified transcript)

**Source:** voice memo, transcribed and lightly cleaned up, Sept 6 2026. Single speaker, no timestamp on the recording itself. Filed as [GitHub issue #3](https://github.com/saranskumar/startathon/issues/3); researched in [tech/research/13 — Sentence-Based Voice Vocabulary Calibration](../tech/research/13-sentence-based-voice-vocabulary-calibration.md).

---

## What was raised

Voice input needs to work across the full range of speaking ability, not just the two ends already named in [03 — Input & Calibration](03-input-calibration.md) §3.1 (`full`/`partial` free dictation, and `sounds` binary presence detection). Between those extremes is a large population who can say *some* words reliably — the speech-to-text model understands them — but not others.

The proposal: expand the existing voice calibration step from one fixed phrase into **5–10 natural sentences**, structured so that each sentence embeds one or more *specific target words* at varying difficulty (very easy, low-syllable words like "yes" up through harder multisyllabic content words). The sentences read as normal speech ("let's go to the gym," "yes, I want to eat that") rather than a word list, so the calibration itself doesn't feel like a test. Difficulty ordering doesn't have to be action-verb-first — any word type is fair game, ranked by how easy it is to physically say.

From this, calibration produces a **personal vocabulary** — the specific list of words this user can say and have reliably recognized — rather than just a single clarity bucket.

**The payoff**: once a task needs the user to pick one of a small number of options (e.g. a service with four choices), render those options using words drawn from the user's own known vocabulary — spoken and/or shown on screen as "say water" / "say tank" / "say yellow" — so the user can select via tap-and-hold voice input using words they're actually able to produce, instead of a fixed vocabulary that may not include anything they can say.

## Research findings

See [tech/research/13](../tech/research/13-sentence-based-voice-vocabulary-calibration.md) for the full brief. Short version: this is sound and buildable, not a new subsystem — it sharpens two things already scoped rather than inventing new ones:

- **Sentence-embedded target words instead of isolated words is standard clinical practice**, not just a nicer-feeling test: articulation/dysarthria therapy already progresses target words through carrier phrases and sentences specifically because isolated-word and sentence-embedded accuracy can differ for this population.
- **Difficulty ordering by syllable count/complexity has a direct clinical analogue** (single sound → one-syllable word → phrase → sentence), including a reusable stopping rule: advance difficulty tiers after 3–5 successful trials, which can make the sentence count adaptive rather than a fixed 5–10.
- **The per-word vocabulary output reuses the enrollment-matching approach [tech/research/02](../tech/research/02-speech-recognition.md) already recommends** (few-shot keyword spotting / fuzzy phonetic matching against a small known list) — no new speech technology, just applying that matcher per-word.
- **One correction**: fully free/unconstrained sentences make scoring a specific target word inside them an open alignment problem. Fixed carrier sentences with the target word in a known slot ("I want to go to the ___.") keep scoring simple while preserving the "sentence, not isolated word" elicitation the idea wants.
- **The dynamic option-labeling idea is real but has one open gap**: it works cleanly if task option vocabularies are designed from the same controlled word list calibration targets (which the water/tank/yellow example already looks like); it's weaker for arbitrary free-text option labels that were never part of the enrolled vocabulary — worth naming as a known limitation, similar to how [07 — Dasher Integration](../tech/research/07-dasher-integration.md) names free-text entry as a known gap rather than assuming it away.

## How this connects to the rest of the docs

This extends, rather than replaces, [03 — Input & Calibration](03-input-calibration.md) §3.1's voice calibration step and the `clarity_level` model:

- The new **per-word vocabulary list** sits alongside `clarity_level`, not instead of it — `clarity_level` still gates which *kind* of voice interaction is offered (free dictation / word-select / binary-only / none); the vocabulary is the *content* available once word-level selection is the viable tier.
- This composes with the existing large-N filtering pattern in [03 §3.2](03-input-calibration.md) (voice/text narrows a big list to a small one first) — vocabulary-matched option labels are what gets spoken/shown once filtering has already happened, not a replacement for that step.
- Task/option design becomes a small new constraint worth stating explicitly: option labels for voice-selectable tasks should be drawn from a shared controlled vocabulary (the same list calibration measures against), not invented per-screen, or the dynamic-labeling payoff doesn't reach those screens.

**Caveat: this is a single-speaker voice-memo transcript**, cleaned up for readability but not reviewed by the team as a settled decision. Confirm scope/priority before treating any item here as locked.
