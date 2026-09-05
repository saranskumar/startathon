# Speech Recognition Research — Dysarthric/Atypical Speech, Personalization, and the "sounds" Tier

**Research date:** 5 September 2026
**Scope:** Supports [02 — Core Model](../../idea/02-core-model.md) §2.3 (`speech.clarity_level`), [03 — Input & Calibration](../../idea/03-input-calibration.md) §3.1 (voice calibration), and the open question raised in [15 — Brain Dump](../../idea/15-brain-dump.md) §15.5/§15.7: is voice calibration a one-shot clarity test, or does it need a per-phrase/per-word learning loop, given that the real-world inspiration case ("call amma") required manual training against Google Assistant's general-purpose recognizer?

**Bottom line up front:** the brain-dump's instinct is correct and is backed by the literature — general-purpose ASR (including Google Assistant/Voice Access) is measurably worse on dysarthric/atypical speech, and the entire research field's answer to that gap is *personalization*, not a better generic model. But full personalized-ASR retraining (Euphonia/Voiceitt-style) is a multi-hundred-utterance, offline-training-loop undertaking — not a 30-hour build. The buildable version of "the learning loop" for this event is a **small personal phrase/vocabulary classifier** (few-shot keyword spotting or a fixed personal phrase list matched by fuzzy/phonetic distance), not a fine-tuned general ASR model.

---

## 1. State of the art in dysarthric/atypical speech recognition (2024–2026)

**Google Project Euphonia.** Google's research project collects disordered-speech recordings (ALS, cerebral palsy, stroke, Down syndrome, etc.) and trains *personalized* ASR models per speaker. Personalized models trained on a speaker's own data achieve dramatically lower word-error-rate (WER) than generic models — reported improvements of up to ~85% relative WER reduction in some domains versus out-of-the-box models trained on typical speech, and in some cases personalized models "outperform human transcribers" on that speaker's own speech. As of Feb 2025 the underlying dataset covers >1.5M utterances from ~3,000 speakers, and Google has said it is expanding to non-English languages including Hindi. Consumer-facing products building on this line of work are **Project Relate** (an Android app letting users with atypical speech create their own personal speech profile) — worth citing as a real analog to what the pitch wants.

**Voiceitt.** A commercial (not open) product built specifically for non-standard speech (cerebral palsy, ALS, stroke, Parkinson's, accented speech). Users **record a set of training phrases** to build a personal voice profile; after that, the app translates non-standard speech into standard text/speech and can feed into assistants like ChatGPT. This is close to a validated version of exactly the "call amma" training loop described in the brain-dump — evidence the enrollment-based personalization pattern is the field-accepted solution, not a hackathon invention.

**Open datasets.** TORGO and UASpeech remain the two standard public dysarthric-speech corpora used across 2025–2026 papers. Representative recent results (severity-aware wav2vec2 fine-tuning, published ~Feb 2026): WER of **40.5% (TORGO)** and **51.8% (UASpeech)** even after fine-tuning — i.e., speaker-*independent* dysarthric ASR is still far from reliable (compare: healthy-speech WER on clean audio is typically <10% for these model classes). Whisper has also been fine-tuned/probed on TORGO and UASpeech in 2025 papers (e.g. "CBA-Whisper", "Probing Whisper for Dysarthric Speech"), generally with the same conclusion: fine-tuned checkpoints help but general-purpose accuracy on unseen dysarthric speakers remains materially worse than typical speech, and results vary a lot by severity level.

**What it takes to build a personalized recognizer.** Across this literature and Euphonia/Voiceitt's public descriptions: personalization needs the *individual* speaker's own recordings (tens of minutes to a few hundred utterances), an offline fine-tuning step (not real-time), and is done cloud-side or on a beefy workstation — not learned instantly on a phone. This is a data-collection-and-training pipeline measured in hours-to-days of engineering + an enrollment session from the user, not something spun up mid-demo.

**Verdict: Weak feasibility for a 30-hour build.** Full personalized-ASR fine-tuning (Euphonia/Voiceitt/TORGO-fine-tune style) is real, proven, and the correct long-term roadmap answer — but it is not implementable as *general free-text dictation* inside a hackathon. It validates the *product thesis* (personalization is the true fix for the "call amma" problem) without being buildable this weekend.

---

## 2. Personalized/few-shot voice command recognition for a small vocabulary

This is the buildable core of the brain-dump's "per-phrase learning loop" idea, and the news here is good.

**Few-shot keyword spotting (KWS).** Recent research (2023–2026) specifically targets exactly this shape of problem: recognizing a **small set of user-chosen words/phrases** from only a handful of examples per word, running on-device. Representative results: one approach lifts 10-shot classification accuracy from 33.4% to 74.1% across 11 classes on Google Speech Commands; another reports ~76% accuracy in a 10-shot setting. These systems use a pretrained feature encoder (sometimes wav2vec2-based) plus a lightweight per-user classifier (prototypical networks / triplet-loss embeddings) trained in seconds on-device — "Few-Shot Open-Set Learning for On-Device Customization of KeyWord Spotting Systems" (Interspeech 2023) is the canonical reference. This is a much closer match to "10–30 contact names/commands trained in minutes" than fine-tuning a full ASR model.

**Custom wake-word tooling as a proof of pattern (Picovoice Porcupine).** Not directly usable for atypical/dysarthric speech (it's tuned for clearly-articulated wake phrases), but structurally exactly the workflow the brain-dump is describing: type/record a target phrase, the console trains a phrase-specific detector via transfer learning **in seconds**, and it runs entirely on-device. It's evidence that "per-phrase enrollment → fast personal model → runs offline" is a well-trodden, productized pattern, and a reasonable structural template even if Porcupine itself isn't the dysarthric-speech answer.

**Practical hackathon design implication:** rather than "one flat speech-clarity number," build a **small closed vocabulary matcher**: the user (or a caregiver) enrolls each contact name / command phrase with 1–3 recordings; a lightweight per-user embedding classifier (or even fuzzy/phonetic string matching over ASR's rough transcription, e.g. Soundex/Metaphone/edit-distance against the known phrase list) picks the closest match rather than requiring free transcription. This is a legitimate, buildable middle ground between "one-shot generic clarity test" and "full personalized ASR."

**Verdict: Strong feasibility.** This is the realistic technical shape of "the learning loop" — a small personal vocabulary matched by a lightweight classifier or fuzzy match against known phrases, not full ASR retraining. It is buildable in a hackathon timeframe if enrollment (1–3 samples per phrase) happens during calibration.

---

## 3. Indian-language / code-switched speech: which APIs are actually usable in 30 hours

| Option | Usable via API today? | Notes |
|---|---|---|
| **Google Cloud Speech-to-Text** | Yes — mature REST/streaming API | 125+ languages/variants including Hindi; pay-as-you-go ($0.016/min standard, volume discounts to $0.004/min); well-documented SDKs (including Flutter/Dart via REST or gRPC). Safe, boring, fast-to-integrate default. No special dysarthric-speech handling. |
| **OpenAI Whisper API** | Yes — simple REST API | $0.006/min flat across 57+ languages, decent Hindi support, but **no native streaming**, ~2.1s median latency for short clips, and no built-in code-switch handling (mixed Hindi-English in one utterance degrades). whisper.cpp/on-device quantized variants exist for offline fallback in Flutter via FFI, at the cost of integration complexity. |
| **Sarvam AI (Saaras v3)** | Yes — India-focused commercial API | Purpose-built for Indian languages: Hindi + 21 others, **native code-mixing support**, real-time streaming via WebSocket, <150ms time-to-first-token in fast mode, speaker diarization. Paid (~₹1.5/min after free credits). Strongest single option if code-switched Hindi/English is a demo requirement, but it's a newer/less-hackathon-battle-tested vendor than Google. |
| **BHASHINI (Govt. of India, ULCA)** | Marginal — API exists but is thin/rough | Free tier + API keys available via bhashini.gov.in / ULCA portal; ASR models exist per language (multiple model IDs per language from different contributing institutes), but documentation, uptime, and per-model quality are uneven — appropriate to cite in the pitch as the strategic/localization story (§14 market research), risky as the *only* live-demo dependency. |
| **AI4Bharat (IndicWhisper / IndicConformer / IndicWav2Vec)** | Research-grade, self-hosted only | MIT-licensed checkpoints on HuggingFace/GitHub with a runnable API backend (`indic-asr-api-backend`, port 4992), but you must stand up and host it yourself — not a hosted SaaS endpoint. Feasible as a weekend project only if a team member is comfortable spinning up a GPU inference server; not a "sign up and call an endpoint" option. |

**Verdict: Moderate-to-Strong feasibility**, contingent on which vendor: **Google Cloud Speech-to-Text is the safe Strong choice** for Hindi ASR reachable in minutes. **Sarvam AI is Strong-and-better-fit** if code-switching matters and the team is willing to onboard a newer vendor. BHASHINI/AI4Bharat are the right *narrative* citation for "why this matters for India" but Weak as the live demo's only dependency — self-hosting AI4Bharat models or depending solely on BHASHINI's live uptime is a real event-day risk.

---

## 4. The "sounds" tier: is VAD/amplitude detection realistic for a yes/no-equivalent signal?

Yes — this is the easiest of the five areas by a wide margin, and it does not need ASR at all.

**WebRTC VAD** is the standard, decades-battle-tested technique: it splits audio into short frames and classifies each as speech/non-speech using frame energy plus spectral features, with an "aggressiveness" mode (0–3) controlling the strictness of the speech/non-speech boundary. It requires no model training, no cloud call, and runs in milliseconds on-device.

**Ready-made libraries:**
- **Python:** `py-webrtcvad` (thin wrapper on Google's WebRTC VAD engine), `libfvad` (C library, same engine).
- **Android:** `android-vad` (Kotlin/Java) supports three interchangeable engines — WebRTC VAD (GMM), Silero VAD (DNN), and Yamnet VAD (DNN) — selectable by accuracy/cost tradeoff.
- **Flutter/Dart:** the `vad` package (pub.dev) wraps Silero VAD via ONNX Runtime across iOS/Android/Web/desktop with a simple start/stop-listening event API (speech-start, speech-end, misfire) — this is the most directly pluggable option for this project's Flutter phone client.

For the specific "sounds" tier use case (binary vocalization-presence, not word content), a VAD library is arguably *better suited* than any ASR call: it doesn't care whether the sound is intelligible, only whether vocalization occurred, which is precisely the signal spec in [03 — Input & Calibration](../../idea/03-input-calibration.md) ("presence of any vocalization... a binary confirm/cancel signal"). A simple amplitude-threshold-over-time approach is an even lower-effort fallback if a VAD library proves hard to wire up in time, at the cost of more false positives from ambient noise.

**Verdict: Strong feasibility.** This is a solved, off-the-shelf, on-device problem with a Flutter-native package (`vad` on pub.dev) already available — the lowest-risk piece of the entire speech pipeline.

---

## 5. Concrete implementation recommendation for the 30-hour build

**Primary stack:**
1. **`full`/`partial` clarity tier (free-text dictation):** Google Cloud Speech-to-Text streaming API, Hindi + English. Reasons: mature Flutter/Dart integration path (REST or gRPC), acceptable latency, predictable pricing, and it is the option most likely to "just work" without vendor-specific surprises during a live judged demo. If code-switched Hindi/English is a stated demo requirement and there's engineering time to spare, swap in **Sarvam AI (Saaras v3)** — its native code-mixing support and sub-150ms latency are a better technical fit for this exact userbase, at the cost of being a less-tested vendor for the team.
2. **`sounds` tier (binary vocalization signal):** the `vad` Flutter package (Silero VAD via ONNX) or `android-vad`'s WebRTC-VAD mode, run fully on-device, no network call, no cost, near-zero latency. This should be built regardless of which ASR vendor is chosen — it's cheap insurance and directly implements the spec in 03-input-calibration.md.
3. **The "per-phrase learning loop" (if in scope):** do **not** attempt personalized ASR fine-tuning. Instead implement a lightweight enrollment step during calibration — record 1–3 samples of each of a small set of phrases (contact names, "yes"/"no", a handful of commands) — and match live utterances against that personal list via (a) a few-shot keyword-spotting embedding classifier if time allows, or (b) the much cheaper fallback of running the chosen ASR's rough transcription through fuzzy/phonetic string matching (Levenshtein/Soundex) against the known phrase list, picking closest match above a confidence floor. This is the buildable, honest version of what "call amma" needs.

**Live-demo fallback plan:** cloud ASR is the single most likely point of live-demo failure (network flakiness, an unfamiliar judge's room noise, the demo user's speech not matching what was tested). Concrete mitigations:
- Pre-record and locally cache a known-good sample of the demo user's calibration phrase so the calibration step itself is not the failure point.
- Treat `clarity_level` calibration as gating which UI shows up, and design Profile B's demoed task so that if voice recognition returns nothing usable, touch alone can still complete the task (per Thesis B's "fused, not voice-mandatory" framing) — i.e. voice augments, never gates, the one demoed task.
- Keep VAD-only ("sounds" tier) as the guaranteed-to-work minimum voice interaction to fall back to live if ASR confidence is low, since it needs no network and cannot "fail to recognize" in the way word-level ASR can.

**Overall verdicts:**
| Area | Verdict |
|---|---|
| 1. Dysarthric/atypical ASR state of the art (full personalization) | Weak feasibility for 30-hr build (real, but not buildable at this scope) |
| 2. Personalized/few-shot small-vocabulary voice commands | Strong feasibility |
| 3. Indian-language/code-switched ASR APIs | Moderate–Strong (Google STT: Strong/safe; Sarvam: Strong/better-fit; BHASHINI/AI4Bharat: Weak as sole live dependency, good narrative citation) |
| 4. VAD/amplitude "sounds" tier | Strong feasibility |
| 5. Concrete implementation path | Google Cloud STT (or Sarvam) + on-device VAD + fuzzy-match personal phrase list is buildable and demo-safe |

---

## Sources

- [Project Euphonia's Personalized Speech Recognition for Non-Standard Speech — Google Research Blog](https://research.google/blog/project-euphonias-personalized-speech-recognition-for-non-standard-speech/)
- [Personalized ASR Models from a Large and Diverse Disordered Speech Dataset — Google Research](https://research.google/blog/personalized-asr-models-from-a-large-and-diverse-disordered-speech-dataset/)
- [Project Euphonia: advancing inclusive speech recognition through expanded data collection and evaluation — Frontiers in Language Sciences (2025)](https://www.frontiersin.org/journals/language-sciences/articles/10.3389/flang.2025.1569448/full)
- [Google's Project Euphonia — Team Gleason](https://teamgleason.org/projecteuphonia/)
- [Google Research: Project Euphonia and Project Relate — Broca AI Speech](https://www.brocaaispeech.com/blog/google-research-project-euphonia-and-project-relate)
- [Voiceitt — Inclusive Voice AI](https://www.voiceitt.com/)
- [Voiceitt Launches Accessible and Inclusive Voice-Enabled Experience App — Futurum Group](https://futurumgroup.com/insights/voiceitt-launches-accessible-and-inclusive-voice-enabled-experience-app/)
- [New app called Voiceitt helps folks with non-standard speech communicate — MobiHealthNews](https://www.mobihealthnews.com/news/new-app-called-voiceitt-helps-folks-non-standard-speech-communicate)
- [Addressing Dysarthric Speech Variability with Severity-Aware Fine-Tuning of Transformer-Based Wav2vec2 ASR Models — Circuits, Systems, and Signal Processing (2026)](https://link.springer.com/article/10.1007/s00034-026-03515-4)
- [Probing Whisper for Dysarthric Speech in Detection and Assessment — arXiv 2510.04219](https://arxiv.org/html/2510.04219)
- [CBA-Whisper: Curriculum Learning-Based AdaLoRA Fine-Tuning — Interspeech 2025](https://www.isca-archive.org/interspeech_2025/tan25b_interspeech.pdf)
- [Zero- and One-Shot Data Augmentation for Sentence-Level Dysarthric Speech Recognition — arXiv 2510.16700](https://arxiv.org/pdf/2510.16700)
- [Few-Shot Open-Set Learning for On-Device Customization of KeyWord Spotting Systems — arXiv 2306.02161 / Interspeech 2023](https://arxiv.org/abs/2306.02161)
- [Enhancing Few-shot Keyword Spotting Performance through Pre-Trained Self-supervised Speech Models — arXiv 2506.17686](https://arxiv.org/html/2506.17686v1)
- [Few-Shot Keyword Spotting With Prototypical Networks — ACM](https://dl.acm.org/doi/fullHtml/10.1145/3529399.3529443)
- [Add Personalized Secure Wake Words to Any Application — Picovoice Cookbook](https://picovoice.ai/cookbook/personalized-wake-word/)
- [Porcupine Wake Word SDK Introduction — Picovoice Docs](https://picovoice.ai/docs/porcupine/)
- [Creating a Custom Wake Word with Porcupine — Picovoice Blog](https://picovoice.ai/blog/console-tutorial-custom-wake-word/)
- [Bhashini APIs — GitBook](https://bhashini.gitbook.io/bhashini-apis)
- [Bhashini — Wikipedia](https://en.wikipedia.org/wiki/Bhashini)
- [Bhashini 2026 — Digital India Language AI Platform](https://schemesinindia.in/central/bhashini-digital-india-language-ai-platform)
- [AI4Bharat/indic-asr-api-backend — GitHub](https://github.com/AI4Bharat/indic-asr-api-backend)
- [AI4Bharat/IndicWav2Vec — GitHub](https://github.com/AI4Bharat/IndicWav2Vec)
- [AI4Bharat/vistaar — GitHub](https://github.com/AI4Bharat/vistaar)
- [IndicWhisper — AI4Bharat](https://ai4bharat.iitm.ac.in/areas/model/ASR/IndicWhisper)
- [Open-Source Voice AI India 2026 — Sarvam, AI4Bharat, Bhasini, IndicTTS — Caller Digital](https://caller.digital/blog/open-source-voice-ai-india-sarvam-ai4bharat-bhasini-2026)
- [Speech to Text & Voice to Text Converter for Indian Languages — Sarvam AI](https://www.sarvam.ai/speech-to-text)
- [Sarvam AI Pricing — Transparent Rates for Indian Language AI APIs](https://docs.sarvam.ai/api-reference-docs/pricing)
- [Real Time Speech Processing with Sarvam AI for Indian Languages — CloudThat](https://www.cloudthat.com/resources/blog/real-time-speech-processing-with-sarvam-ai-for-indian-languages)
- [Speech-to-Text API Pricing — Google Cloud](https://cloud.google.com/speech-to-text/pricing)
- [Google Cloud Speech-to-Text: 2026 Review — Smallest.ai](https://smallest.ai/blog/is-google-cloud-speech-to-text-still-the-right-choice)
- [Whisper API Pricing 2026 — TokenMix Blog](https://tokenmix.ai/blog/whisper-api-pricing)
- [Integrating OpenAI Whisper for On-Device Transcription in Flutter — Vibe Studio](https://vibe-studio.ai/insights/integrating-openai-whisper-for-on-device-transcription-in-flutter)
- [Gladia - Best Whisper alternatives for 2026](https://www.gladia.io/blog/best-whisper-alternatives-2026)
- [WebRTC Voice Activity Detection: Real-Time Speech Detection in 2025 — VideoSDK](https://www.videosdk.live/developer-hub/webrtc/webrtc-voice-activity-detection)
- [vad — Dart API docs (pub.dev)](https://pub.dev/documentation/vad/latest/)
- [vad — Flutter package (pub.dev)](https://pub.dev/packages/vad)
- [wiseman/py-webrtcvad — GitHub](https://github.com/wiseman/py-webrtcvad)
- [dpirch/libfvad — GitHub](https://github.com/dpirch/libfvad)
- [gkonovalov/android-vad — GitHub](https://github.com/gkonovalov/android-vad)
- [14 — India Market Reality & Userbase Context (internal, §7 Multilingual and Impaired-Speech Reality)](../../idea/14-market-research.md)
