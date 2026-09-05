# 11. Voice Accessibility — Viability Assessment

**Research date:** 6 September 2026  
**Source:** *Voice Accessibility Research Context* (docx) + reconciliation with [02 — Speech Recognition](02-speech-recognition.md) and the current Flutter voice stub  
**Scope:** Dysarthric / atypical speech — models, open-source building blocks, datasets, commercial fallbacks, and what is actually viable for the Startathon build

---

## Bottom line

**Viable for the event if scoped correctly. Not viable if the demo depends on fine-tuned dysarthric ASR.**

Keep the voice layer **model-agnostic**, route audio through a **hosted general ASR** for MVP, and spend engineering time on fusion / patient capture / confirmation — not training. The product moat is modality composition, not speech recognition.

| Layer | Event viability | Current code state |
|---|---|---|
| Touch + voice fusion + confirmation | **Strong** | Built — real interaction; only the recogniser is stubbed ([`SpeechSource`](../../../code/app/lib/inputs/voice.dart)) |
| `sounds` tier (VAD / sound-count) | **Strong** | Interaction built (one-sound / two-sounds); real VAD not wired yet |
| Hosted general ASR behind `SpeechSource` | **Strong** | Stub only — swap in Google STT (safe) or Sarvam (code-switch) per [02](02-speech-recognition.md) |
| Small personal phrase list (“call amma”) | **Moderate–Strong** | Not built; buildable as fuzzy match over rough transcript |
| Fine-tune Whisper / Wav2Vec on TORGO / UASpeech / SAP | **Weak / out of scope** | Needs corpus + compute + held-out eval; do not attempt in 30h |
| Claiming “dysarthria-capable” from generic Whisper | **Do not claim** | Fine-tunable ≠ already adapted |

---

## 1. Why dysarthric / atypical speech is a distinct ASR problem

General-purpose ASR is optimized for typical speech. Neuro-motor speech disorders change cadence, breathing pauses, articulation, phoneme realization, and intelligibility — a **domain mismatch**, not a minor accent problem.

**Product implication:** “speech input available” cannot be binary. A user may have speech that is slow, slurred, partial, or highly speaker-specific. The system needs:

- patient recognition (no timeout on slow speech), and
- for production quality, speech-specific adaptation (roadmap — not event).

This already matches `speech.clarity_level`: `full` | `partial` | `sounds` | `none` in [02 — Core Model](../../idea/02-core-model.md).

---

## 2. Role of voice in the adaptive access layer

| Layer | Primary role | Why it matters |
|---|---|---|
| Touch | Selection / navigation | Choosing a contact, button, or context |
| Voice | Content / free text | Dictating or expressing what should be said or done |
| AI inference | Bridge ambiguity | Cleans partial / noisy input into intent; confirm before consequential actions |
| Output | Result feedback | Text or narration per vision profile |

Voice recognition is a **replaceable backend**. The frontend composition layer must not depend on one ASR vendor or model family — which is why the app already isolates recognition behind `SpeechSource`.

---

## 3. Open-source foundation models (roadmap context)

### 3.1 OpenAI Whisper

Large pretrained ASR; adaptable via fine-tuning. Base model can fail or hallucinate on slurred speech; architecture is suitable for dysarthria-specific adaptation. Whisper-Small / Medium are practical size/latency trade-offs for later experimentation.

### 3.2 Meta Wav2Vec 2.0 / XLS-R

Self-supervised speech representations from raw audio; strong family for dysarthria-oriented ASR and specialized checkpoints on Hugging Face.

**Event use:** cite as roadmap foundations. Do not fine-tune during the hackathon.

---

## 4. Specialized open-source repos & checkpoints

| Repo / checkpoint | Use |
|---|---|
| **CBA-Whisper** | Curriculum / AdaLoRA fine-tuning for low-resource dysarthric ASR — strong Stage-2 starting point |
| **asr-dysarthria** | Wav2Vec2 Large XLS-R fine-tuned for dysarthria; HF weights + deployment notes |
| **Dysarthric Speech Transcription** | Notebooks for Whisper Small/Medium; cross-user vs user-specific approaches |
| **Dys-Locate** | TORGO-based pipeline with Streamlit; optional dysarthria-detection stage before transcription |
| **HF dysarthria pipelines** | Community checkpoints to avoid building the training stack from scratch |

Quantitative claims (WER ranges, dataset hours) should be verified against the original paper/repo before pitching — see [02](02-speech-recognition.md) for the numbers already researched (e.g. post-fine-tune TORGO ~40.5% WER, UASpeech ~51.8% — still far from healthy-speech reliability).

---

## 5. Datasets

| Dataset | Role |
|---|---|
| **TORGO** | Historical “gold standard” open dysarthric corpus (aligned recordings + controls) |
| **UASpeech** | Widely cited isolated-word dysarthric adult recordings |
| **Speech Accessibility Project (SAP)** | Newer, larger atypical-speech resource (notes: 400+ hours, 500+ speakers; ALS, Parkinson’s, CP, Down syndrome; SLP ratings) — verify scale before external claims |
| **Community multilingual** (e.g. `chuber/dysarthric-speech`) | Non-English experimentation |

**Data distinction:** training JSON (transcripts + paths) alone is not a training corpus. Actual `.wav` files + a base model + preprocessing are required.

---

## 6. What fine-tuning actually requires (why it’s not event-scope)

1. Real audio from the chosen dysarthric datasets  
2. A pretrained base (Whisper or Wav2Vec2 / XLS-R)  
3. Compatible training + preprocessing code  
4. Meaningful compute (even parameter-efficient methods add engineering/runtime overhead)  
5. Evaluation on **held-out speakers** (user-specific calibration can look strong without generalizing)

---

## 7. Two adaptation modes (roadmap)

| Mode | Idea | Product fit |
|---|---|---|
| **Cross-user / speaker-independent** | Train on many speakers → broader atypical-speech patterns | Stage 2 base model |
| **User-specific / idiosyncratic** | Calibrate to one user’s speech | Stage 3; matches “call amma” / Relate / Voiceitt |

Production path: broad dysarthria-adapted model **plus** lightweight user calibration — not a full retrain per user every session. Event-sized version of Stage 3: small enrolled phrase list + fuzzy/phonetic match ([02](02-speech-recognition.md) §2), not offline ASR fine-tuning.

---

## 8. Commercial / non-open references

| Option | Relevance |
|---|---|
| **Voiceitt** | Non-standard speech; ~50-phrase calibration → idiosyncratic model; text or synthesized speech out |
| **Google Project Relate / Euphonia** | Non-open benchmark; personalize atypical speech → text / Assistant; architecture reference, not a build dependency |

These validate the long-term personalization thesis without being integrable in 30 hours.

---

## 9. Locked 30-hour approach (Stage 1 only)

1. **Do not** train a specialized dysarthric model during the event.  
2. Capture audio on the phone (simple record / stream path).  
3. Send audio to a **fast hosted ASR** backend.  
4. Keep orchestration **model-agnostic** so a dysarthria-tuned model can swap in later.  
5. Use the intent / LLM layer to normalize imperfect transcripts.  
6. Spend limited time on adaptive UI, modality fusion, confirmation, and profile switching — the product thesis.

**Recommended vendor path (from [02](02-speech-recognition.md)):** Google Cloud Speech-to-Text as the safe default; Sarvam AI if Hindi–English code-switching is a hard demo requirement. BHASHINI / AI4Bharat are pitch narrative, not sole live dependencies.

---

## 10. Architecture (voice as replaceable backend)

```
Mobile / thin client
    │
    ├── Adaptive touch UI  ───────────────┐
    │                                      │
    └── Voice capture → ASR backend        │
                       │                  │
                       ▼                  ▼
                 transcript        touch selection
                       └──────────┬──────────┘
                                  ▼
                          intent / inference layer
                                  │
                                  ▼
                            AI agent / action
                                  │
                                  ▼
                          confirmation gate
                                  │
                                  ▼
                           computer / app
```

Maps cleanly onto existing `SpeechSource` → fusion UI → confirmation gate. Replacing the stub with a real backend should not rewrite the interaction layer.

---

## 11. How voice supports the product thesis

- Voice is **one adaptive modality**, not the product.  
- Residual / unreliable speech → use voice for **content**, touch for **selection** (Thesis B).  
- Clarity tier tunes patience and how much inference is allowed.  
- Lower-confidence speech → stronger confirmation before consequential actions.  
- Model-agnostic interface enables Stage 1 → Stage 2 swap without rewriting UX.

---

## 12. Concrete demo shape (partial-ability profile)

1. User taps a large contact / task tile (touch = selection).  
2. Voice input opens and waits patiently for slow / unclear speech.  
3. User speaks content (e.g. a short message).  
4. ASR returns imperfect text; inference resolves intent.  
5. System shows the proposed result for confirmation.  
6. User confirms or interrupts.  
7. Action executes.

**What this proves:** fusion in one interaction; ASR backend remains replaceable. Live-demo safety: if ASR fails, touch alone should still complete the task (voice augments, never gates) — and the existing `SIMULATED RECOGNISER` panel remains a stage fallback.

---

## 13. Risks & pitch guardrails

| Guardrail | Why |
|---|---|
| Do not call generic Whisper “dysarthria-capable” | Fine-tunable ≠ adapted |
| Do not equate transcription with intent | Partial text needs inference + confirm |
| Do not treat training JSON as readiness | Need audio, weights, compute, preprocess |
| Do not depend on untested local GPU inference for the live demo | Latency / env risk |
| Measure latency and failure recovery in the real demo room | Aggregate accuracy ≠ live feel |

**Safer pitch line:** patient voice capture + touch fusion + confirmation; specialized dysarthric models and personal calibration are the open-source roadmap.

---

## 14. Longer-term roadmap (post-event)

| Stage | Focus |
|---|---|
| **1 — MVP (event)** | Hosted general ASR + adaptive UI + inference + confirmation |
| **2 — Specialized model** | Integrate a dysarthria-tuned open checkpoint (Wav2Vec2 / XLS-R or CBA-Whisper-class) |
| **3 — Personal calibration** | Lightweight user-specific adaptation / enrolled phrase list |
| **4 — Multilingual** | Same interface abstraction → Indian-language + localized patterns |
| **5 — Hybrid** | Broad accessibility model + small-data personal adaptation |

---

## 15. Evidence boundaries

This brief consolidates the supplied *Voice Accessibility Research Context* docx and reconciles it with [02 — Speech Recognition](02-speech-recognition.md). Named models, repos, and datasets are preserved for roadmap planning. Specific quantitative claims (WER, SAP scale, commercial phrase counts) should be re-checked against primary sources before external pitch or publication use.

**Primary research prompt behind the source doc:** voice accessibility for slurry / atypical speech — existing models and open-source building blocks.

---

## Cross-links

- [02 — Speech Recognition](02-speech-recognition.md) — API/VAD/few-shot feasibility detail  
- [03 — Input & Calibration](../../idea/03-input-calibration.md) — clarity tiers and fusion rules  
- [14 — Market Research](../../idea/14-market-research.md) — India multilingual / dysarthria market framing  
- [15 — Brain Dump](../../idea/15-brain-dump.md) §15.5 — per-phrase “call amma” learning loop  
- [code/app/README.md](../../../code/app/README.md) — stubbed recogniser, real fusion UX  
