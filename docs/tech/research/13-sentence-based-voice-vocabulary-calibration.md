# 13. Sentence-Based Voice Vocabulary Calibration & Dynamic Word-Choice Input

**Research date:** 6 September 2026
**Purpose:** Research brief for [GitHub issue #3](https://github.com/saranskumar/startathon/issues/3) and [docs/idea/26 — Meeting Notes: Voice Vocabulary Calibration](../../idea/26-meeting-notes-voice-vocabulary-calibration.md). Extends the existing `clarity_level` model in [03 — Input & Calibration](../../idea/03-input-calibration.md) §3.1 and the enrolled-phrase-matching recommendation in [02 — Speech Recognition](02-speech-recognition.md) — the new idea is specifically about *how enrollment is elicited* (multiple full sentences, not one fixed phrase) and *what the resulting per-user vocabulary is used for* (dynamically relabeling on-screen choices to words the user can actually say).

**Headline verdict: sound and directly buildable — it's a natural, well-supported extension of work already scoped, not a new subsystem.** The three pieces (elicit via sentences instead of isolated words, order candidate words by articulatory difficulty, use the resulting personal vocabulary to pick which words appear as selectable options) each have real prior art. The one design correction worth making: elicit with *carrier phrases embedding the target word*, not fully unconstrained free sentences, or scoring individual target words inside a variable sentence becomes an alignment problem the project doesn't need to take on.

---

## 1. What's actually new versus what's already scoped

[03 — Input & Calibration](../../idea/03-input-calibration.md) §3.1 already has a voice calibration step, but it's a single fixed phrase producing one `clarity_level` bucket (`full/partial/sounds/none`). [02 — Speech Recognition](02-speech-recognition.md) already recommends enrollment-based personalization (1–3 samples per phrase, matched via few-shot keyword spotting or fuzzy/phonetic string matching) as the buildable middle ground between full ASR personalization and a flat clarity number.

The idea raised here sits between those two and sharpens both:

1. **Elicitation shape**: instead of one phrase, use **5–10 natural sentences**, each containing one or more *target words* chosen at a range of articulatory difficulty (very easy: "yes" — harder: multisyllabic content words like "yellow", "tank"). The sentences themselves are the enrollment data; the target words inside them are what gets scored individually.
2. **Output**: not just a `clarity_level` bucket, but a **per-word vocabulary list** — which specific words this user can reliably produce and have recognized, ranked/tagged by confidence.
3. **New consumption pattern**: for any discrete-choice task with a small option list, **render the options as whichever words are actually in the user's known vocabulary** (e.g. "water" / "tank" / "yellow" as three on-screen + spoken choices), rather than a fixed vocabulary set every user sees the same way — closing the loop between what calibration measured and what the UI subsequently asks the user to say.

None of this needs a different underlying speech pipeline than what [02](02-speech-recognition.md) already recommends (Google Cloud STT / on-device VAD / fuzzy phonetic matching); it needs a different **calibration elicitation script** and a **vocabulary-to-option mapping step** downstream.

## 2. Multi-sentence elicitation with embedded target words is a known, named technique

This is not a novel elicitation design — it's the standard shape of a **speech-therapy/AAC word list embedded in carrier phrases**, and separately, the standard shape of **voice-enrollment prompt design in ASR/speaker-adaptation research**.

- **Carrier phrases in articulation/speech assessment.** Clinical articulation testing and therapy progressions place target sounds/words inside short natural sentences rather than testing isolated words in a vacuum, specifically because isolated-word production and sentence-embedded production of the same word can differ in accuracy for people with dysarthria — a therapy hierarchy that starts at "establish a single sound," moves to "place it at the start of a one-syllable word," then to "the word inside a short phrase," then to "the word inside a longer sentence." This directly validates the idea's instinct to test words *inside* sentences rather than as a word list, and additionally suggests the calibration should track word-in-isolation vs. word-in-sentence accuracy as potentially different signals, not assume they're interchangeable. ([Dysarthria articulation therapy hierarchy — EatSpeakThink](https://eatspeakthink.com/articulation-therapy-dysarthria-1/); [Adult dysarthria exercise progressions](https://theadultspeechtherapyworkbook.com/dysarthria-exercises-for-adults/))
- **Carrier-phrase / prompt design in ASR enrollment research.** Modern personalized-ASR and target-speaker literature (2025–2026) treats enrollment-phrase design as a real variable: enrollment can be **semi-text-dependent** (a bounded set of candidate phrases rather than one fixed phrase or fully open text), which is exactly the shape of "5–10 designed sentences" rather than either a single fixed phrase or unconstrained free speech. Synthetic-data personalization work also finds that **enrollment text content matters more than speaking style** for how well an adapted model generalizes — supporting the idea's emphasis on choosing *which words* appear in the sentences deliberately, not just collecting more audio. ([Semi-text-dependent enrollment, target-speaker ASR](https://arxiv.org/pdf/2501.15466v1); [Text-content-driven personalization — Apple ML Research](https://machinelearning.apple.com/research/personalizing-asr-models))

**Design correction worth making:** unconstrained "say anything you want, five times" sentences make scoring the *specific target word* inside each sentence an open alignment problem (where in the sentence is "yellow"? did the ASR even attempt it?). The buildable version is **fixed carrier sentences with the target word in a known position** ("I want to go to the [target]." / "Please say [target] now."), which keeps the target-word scoring trivial (look at one slot) while still getting the "natural sentence, not isolated word" elicitation shape the idea and the clinical literature both call for.

## 3. Ordering candidate words by articulatory difficulty is standard, and a concrete ordering exists

The idea's instinct that "yes" is easier to say than an arbitrary noun is correct and matches established speech-development/therapy ordering, not just intuition:

- Standard dysarthria/articulation therapy progressions order material by **phonetic complexity and syllable count**: single target sound → one-syllable word containing that sound → the word in a two-word phrase → the word in a longer sentence — i.e., syllable count and consonant-cluster complexity are the primary difficulty axes already used clinically, which gives a ready-made ordering principle for picking calibration target words (prefer CV/CVC monosyllables like "yes"/"no" first, multisyllabic or consonant-cluster words like "yellow"/"water" later). ("Come" → "Come here" → "Come here now" style progressions — [EatSpeakThink](https://eatspeakthink.com/articulation-therapy-dysarthria-1/))
- Therapy practice also has a concrete stopping rule worth reusing directly: **advance to the next difficulty level only after 3–5 successful trials at the current level**, which maps cleanly onto "how many sentences does calibration need" — the count doesn't have to be a fixed 5–10, it can be adaptive (stop early for a user who's clearly clean on everything; go longer for one who's borderline).

**Verdict: Strong, and cheap to build.** A short curated list of calibration target words, pre-tagged by syllable count/difficulty tier, dropped into fixed carrier sentences, reusing the existing per-utterance ASR-confidence-or-WER scoring [03 §3.1](../../idea/03-input-calibration.md) already specifies. This needs no new speech technology — it's a content-design task (writing ~10 sentences and picking ~10-15 candidate words at 2-3 difficulty tiers) plus a small amount of scoring logic per word instead of per phrase.

## 4. Using the resulting personal vocabulary to choose which words appear as options — real prior art, one gap to flag

This is the part of the idea with the least direct precedent found, but it decomposes into two sub-problems that each have real prior art:

- **Matching a small enrolled vocabulary against live speech** is exactly the few-shot keyword-spotting / fuzzy-phonetic-matching approach [02 — Speech Recognition](02-speech-recognition.md) §2 already recommends and rates "Strong feasibility" — this idea doesn't need new speech tech, it needs that same matcher applied per-word instead of per-contact-name.
- **Mapping a discrete-choice task's option set onto a constrained vocabulary is a content/UX problem, not a speech problem**: given task option `{water tank, filter, pump}` and a user vocabulary of `{yes, no, water, blue}`, the system needs *some* option→word association even for options the user never explicitly rehearsed. Two honest paths, both worth naming rather than picking silently: (a) **design task option labels from a shared small controlled vocabulary up front**, so calibration's target-word list *is* the app's option-label vocabulary (the demo's "water/tank/yellow" example already does this — those read like real task option labels, not generic filler words); or (b) accept that novel option labels outside the enrolled set fall back to spelling/synonym matching or a different input method entirely for that specific option. Path (a) is the buildable one for an event timeline; path (b) is a real roadmap gap worth stating rather than assuming away, the same way [07 — Dasher Integration](07-dasher-integration.md) is flagged as a known gap for free-text entry rather than silently ignored.
- **This composes with, rather than duplicates, the existing large-N filtering pattern** in [03 §3.2](../../idea/03-input-calibration.md) ("when N is large, use voice/text to filter down to small N first") — the vocabulary-matched option labels are what the small-N voice interaction says out loud once filtering has already happened, not a replacement for that step.

**Verdict: Moderate-to-Strong, contingent on the design correction above.** Buildable if task option vocabularies are designed from the same controlled word list calibration targets (recommended), weaker/roadmap if arbitrary free-text option labels are expected to always resolve against an enrolled vocabulary.

## 5. How the resulting tier structure folds into the existing `clarity_level` model

The existing `full / partial / sounds / none` buckets in [03 §3.1](../../idea/03-input-calibration.md) don't disappear — they become **the top and bottom of the same spectrum this idea measures at finer grain**:

- `full` — user's per-word vocabulary is effectively unconstrained (everything attempted scores high); free-text dictation applies as already specified.
- **New middle tier this idea adds**: a **bounded personal vocabulary** — some words score reliably, others don't. This is the population the idea is actually about, and it didn't have a first-class representation before (previously such a user would likely just land in `partial` as an undifferentiated bucket).
- `sounds` — no words score reliably at all; VAD-only presence detection, unchanged from existing spec.
- `none` — unchanged.

Recommend the vocabulary list becomes a **field alongside** `clarity_level`, not a replacement for it: `clarity_level` still gates *what kind of* voice interaction is offered at all (free dictation vs. word-select vs. binary-only vs. none), and the vocabulary list is the *content* available once `clarity_level` says word-level selection is viable.

---

## Overall verdicts

| Piece of the idea | Verdict | Notes |
|---|---|---|
| Multi-sentence elicitation instead of one phrase | Strong | Matches clinical carrier-phrase/sentence-embedding practice and ASR semi-text-dependent enrollment research |
| Ordering target words by articulatory difficulty | Strong | Direct match to established syllable-count/complexity-based therapy progressions; concrete, reusable stopping rule (3-5 successes per tier) |
| Per-word personal vocabulary as calibration output | Strong | Reuses the few-shot/fuzzy-matching approach already recommended in [02](02-speech-recognition.md), just applied per-word |
| Dynamically labeling task options from the personal vocabulary | Moderate | Buildable if task option vocabularies are designed from the same controlled word list; real gap for arbitrary free-text option labels, worth naming not hiding |
| Fixed carrier sentences vs. fully free sentences | Correction recommended | Free sentences make target-word alignment/scoring an open problem; fixed carrier sentences with a known target-word slot keep scoring trivial while preserving the "sentence not isolated word" elicitation shape |

---

## Sources

- [Articulation therapy for dysarthria: Part 1 — EatSpeakThink.com](https://eatspeakthink.com/articulation-therapy-dysarthria-1/)
- [Dysarthria therapy: Part 1 summary PDF](https://eatspeakthink.com/wp-content/uploads/2020/01/Artic-tx-part1-sum.pdf)
- [24 Dysarthria Exercises For Adult Speech Therapy — The Adult Speech Therapy Workbook](https://theadultspeechtherapyworkbook.com/dysarthria-exercises-for-adults/)
- [End-to-End Target Speaker Speech Recognition Using Context-Aware Attention Mechanisms for Challenging Enrollment Scenario — arXiv 2501.15466](https://arxiv.org/html/2501.15466v1)
- [Text is All You Need: Personalizing ASR Models using Controllable Speech Synthesis — Apple Machine Learning Research](https://machinelearning.apple.com/research/personalizing-asr-models)
- [Adaptive Speaker Embedding Self-Augmentation — arXiv 2601.12769](https://arxiv.org/pdf/2601.12769)
- [02 — Speech Recognition (this project's own thread, cross-referenced throughout)](02-speech-recognition.md)
- [03 — Input & Calibration §3.1 (this project's own doc, cross-referenced throughout)](../../idea/03-input-calibration.md)
