# 26. Meeting Notes — Sentence-Based Voice Vocabulary Calibration (unverified transcript)

**Source:** voice memo, transcribed and lightly cleaned up, Sept 6 2026. Single speaker, no timestamp on the recording itself. Filed as [GitHub issue #3](https://github.com/saranskumar/startathon/issues/3); researched in [tech/research/13 — Sentence-Based Voice Vocabulary Calibration](../tech/research/13-sentence-based-voice-vocabulary-calibration.md).

---

## What was raised

Voice input already has answers at the two ends of the spectrum, both already discussed elsewhere: someone who can speak clearly has no real difficulty and may not even need this project's fallback methods (the `full`/`partial` free-dictation tier), and someone who can't produce words at all is served by the tone/loudness/timing-based noise system already built for the `sounds` tier ([03 — Input & Calibration](03-input-calibration.md) §3.1). **This idea is specifically about the middle population between those two**: people who can say *some* words reliably — the speech-to-text model understands them — but not others. The high-end solution (full dictation) is too difficult for them; the low-end solution (tone/noise) is too tedious/low-bandwidth for what they're actually capable of.

The proposal: expand the existing voice calibration step from one fixed phrase into **5–10 natural sentences**, structured so that each sentence embeds one or more *specific target words* at varying difficulty (very easy, low-syllable words like "yes" up through harder multisyllabic content words). The sentences read as normal speech ("let's go to the gym," "yes, I want to eat that") rather than a word list, so the calibration itself doesn't feel like a test. Difficulty ordering doesn't have to be action-verb-first — any word type is fair game, ranked by how easy it is to physically say.

From this, calibration produces a **personal vocabulary** — the specific list of words this user can say easily and have reliably recognized — rather than just a single clarity bucket. This vocabulary can be tiny (as small as 2 words for some users) or large (100+ words for others); the mapping mechanism below has to work at either end.

**The payoff — mapped two different ways depending on how many options are on screen:**
- **Small option count (direct mapping):** if a menu has as many or fewer options than the user's vocabulary, map vocabulary words directly to those specific options — e.g. a user whose vocabulary is exactly `{water, tank, yellow}` sees/hears those three words as the three menu choices, tap-and-hold to speak one and select it.
- **Large option count (functional/positional mapping):** if there are more options than vocabulary words, stop trying to match words to option *meanings* and instead map the (small) vocabulary to fixed **navigation functions** — e.g. `water` → next, `tank` → previous, `yellow` → select — regardless of what the options are actually called. This is the piece that makes the scheme work even for a 2-word vocabulary against an arbitrarily long list, since the mapping no longer depends on option labels matching anything the user can say.

## Research findings

See [tech/research/13](../tech/research/13-sentence-based-voice-vocabulary-calibration.md) for the full brief. Short version: this is sound and buildable, not a new subsystem — it sharpens two things already scoped rather than inventing new ones:

- **Sentence-embedded target words instead of isolated words is standard clinical practice**, not just a nicer-feeling test: articulation/dysarthria therapy already progresses target words through carrier phrases and sentences specifically because isolated-word and sentence-embedded accuracy can differ for this population.
- **Difficulty ordering by syllable count/complexity has a direct clinical analogue** (single sound → one-syllable word → phrase → sentence), including a reusable stopping rule: advance difficulty tiers after 3–5 successful trials, which can make the sentence count adaptive rather than a fixed 5–10.
- **The per-word vocabulary output reuses the enrollment-matching approach [tech/research/02](../tech/research/02-speech-recognition.md) already recommends** (few-shot keyword spotting / fuzzy phonetic matching against a small known list) — no new speech technology, just applying that matcher per-word.
- **One correction**: fully free/unconstrained sentences make scoring a specific target word inside them an open alignment problem. Fixed carrier sentences with the target word in a known slot ("I want to go to the ___.") keep scoring simple while preserving the "sentence, not isolated word" elicitation the idea wants.
- **The follow-up clarification (direct mapping for small N, functional next/previous/select mapping for large N) resolves the open gap the initial research brief flagged** — arbitrary free-text option labels no longer need to appear in the user's enrolled vocabulary at all, because for large option counts the vocabulary maps to a fixed, small set of navigation functions instead of to option meanings. This is the same coarse-select/fine-confirm shape already documented across other input modes in [tech/research/10 §7](../tech/research/10-additional-input-modes.md) — next/previous/select is just that pattern's voice-driven form.

## How this connects to the rest of the docs

This extends, rather than replaces, [03 — Input & Calibration](03-input-calibration.md) §3.1's voice calibration step and the `clarity_level` model:

- The new **per-word vocabulary list** sits alongside `clarity_level`, not instead of it — `clarity_level` still gates which *kind* of voice interaction is offered (free dictation / word-select / binary-only / none); the vocabulary is the *content* available once word-level selection is the viable tier.
- This composes with the existing large-N filtering pattern in [03 §3.2](03-input-calibration.md) (voice/text narrows a big list to a small one first) — the functional next/previous/select mapping is essentially an alternative to (or a voice-driven implementation of) that same cycling mechanism, for exactly the population whose vocabulary can't cover arbitrary option labels.
- Task/option design only needs the controlled-vocabulary constraint for the **direct-mapping (small N) case** — option labels there should be drawn from the same word list calibration measures against. The **functional-mapping (large N) case has no such constraint**, since it never depends on option labels at all — this removes the open gap the first draft of this research flagged.

**Caveat: this is a single-speaker voice-memo transcript**, cleaned up for readability but not reviewed by the team as a settled decision. Confirm scope/priority before treating any item here as locked.
