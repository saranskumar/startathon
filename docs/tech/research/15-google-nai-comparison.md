# 15. Google "Natively Adaptive Interfaces" (NAI) — Detailed Comparison

**Research date:** 6 September 2026. Follow-up to [06-competitive-deep-dive](06-competitive-deep-dive.md) §1.1, which flagged NAI as the closest shipped/prototype analogue found. Requested after the team decided **not to use AI at all** in this build (see [docs/idea/28](../../idea/28-meeting-notes-scope-lock-no-ai.md)) — this comparison is written against that decision, not the older AI-agent framing in [07-architecture.md](../../idea/07-architecture.md).

Source: [Google Research blog — "How AI agents can redefine universal design to increase accessibility"](https://research.google/blog/how-ai-agents-can-redefine-universal-design-to-increase-accessibility/)

---

## 1. What NAI actually is

NAI is a **research framework and set of prototypes**, not a shipped product. Its stated goal is closing the "accessibility gap" — the lag between a new feature shipping and an assistive layer catching up to it — by making interfaces *natively* adaptive instead of accessibility being a reactive patch (screen readers translating an already-built static UI after the fact).

**Architecture — an Orchestrator delegating to sub-agents:**
- A central **Orchestrator** holds shared context (what document/screen the user is in, what they've asked) and delegates work to specialized agents rather than handling everything itself.
- **Summarization Agent** — breaks a complex document down and surfaces key information.
- **Settings Agent** — handles UI adjustments (e.g. dynamically scaling text) on the user's behalf.
- Built on **Gemini's multimodal processing** (voice, vision, text simultaneously) plus a RAG pipeline for one prototype (MAVP, a video player): an offline "dense index" of visual descriptions, retrieved fast at playback time.

**StreetReaderAI** (its flagship prototype) is an AI walking-navigation guide for blind/low-vision users: an "AI Describer" continuously analyzes camera + geographic data, and an "AI Chat" answers follow-up questions with contextual memory (e.g. "where was that bus stop?" → "~12 meters back").

**Status:** explicitly prototypes and proofs-of-concept validating a vision, per Google's own framing — not deployed products with real users at scale.

## 2. What NAI does *not* have

- **No explicit, continuous capability profile or ability axes.** NAI's personalization is interaction-driven and per-feature ("the Grammar Laboratory prototype adapts based on interaction"), not a persistent, measured `{touch, speech, vision}`-style profile that a system reasons over structurally. There's no calibration step, no per-method score, no reachable-zone measurement — adaptation happens implicitly, inside the model, not as an inspectable data structure.
- **No task-aware ideal/fallback input-method matrix.** NAI is about *output* adaptation (summarizing, describing, adjusting text) and *conversational* interaction (voice/chat), not about selecting which of several physical input methods (buttons/joystick/trackpad/switch) a given user should use for a given task shape.
- **AI is the mechanism, not a narrow tool.** Every adaptive behavior in NAI — deciding what to summarize, when to describe something, how to adjust settings — runs through an LLM (Gemini) at runtime. There is no deterministic, non-AI fallback path described; the Orchestrator and its sub-agents *are* the adaptation layer.

## 3. Direct comparison

| | NAI (Google) | This project |
|---|---|---|
| **What adapts** | Output narration/summarization and some UI settings, via conversational AI agents | Which physical input method renders, at what resolution, plus output mode — via a measured capability profile |
| **How it decides** | An LLM orchestrator reasoning per-interaction | A calibration step producing per-axis scores, then a fixed, designed ideal/fallback mapping per task shape ([03-input-calibration](../../idea/03-input-calibration.md) §3.2–3.3) |
| **Is there a persistent user model?** | Not an explicit one — adaptation is implicit in the model's behavior | Yes — the capability profile is a first-class, inspectable object (`touch.method_scores`, `speech.clarity_level`, `vision.mode`) that every downstream decision is a pure function of |
| **Role of AI** | Central and load-bearing — the Orchestrator/sub-agents are Gemini-driven at runtime | **None**, per the team's decision ([docs/idea/28](../../idea/28-meeting-notes-scope-lock-no-ai.md)) — every mechanism (calibration scoring, ideal/fallback selection, tree ranking) is deterministic and hand-specified |
| **Status** | Google Research prototypes (StreetReaderAI, MAVP, Grammar Laboratory), not shipped | 30-hour event build targeting two demoed capability profiles |
| **Cost/hosting model implied** | Requires Gemini API calls at runtime for every adaptive decision | Runs offline/self-hostable — no model-hosting cost, no per-request inference bill, consistent with the project's open-source, affordability-first positioning ([14-market-research](../../idea/14-market-research.md)) |

## 4. What this means for the pitch, now that AI is fully out of scope

The comparison got *cleaner*, not weaker, once AI left the build:

- **Before:** the project risked reading as "a smaller, less-polished version of what Google is already prototyping with Gemini" — same general shape (adaptive interface, agent-driven), different scale.
- **Now:** the two projects sit in genuinely different categories. NAI is *AI-mediated* adaptation (a model decides, per-interaction, what to show/say). This project is *profile-driven, deterministic* adaptation (a measured, inspectable capability profile drives a fixed decision table). That's a real, statable difference, not a hedge: **no model call, no hosting cost, no inference latency, fully offline-capable, and every adaptation decision is auditable** — you can point at exactly why a given control rendered a given way, which an LLM-orchestrated system cannot promise as cleanly.
- **Honest framing for a judge who knows NAI:** "Google's NAI shows the industry agrees adaptive interfaces are the right direction — they're doing it with an AI agent deciding per-interaction. We do the same *kind* of adaptation without any AI at all: a measured capability profile and a fixed, deterministic decision table. That means it's free to run, auditable, and doesn't depend on a model API being available or affordable — which matters a lot for the exact underserved population this is for."
- This also resolves the tension [06-competitive-deep-dive](06-competitive-deep-dive.md) flagged (NAI as "directional prior art / competitive risk") — it's no longer a risk to be defended against, it's a clean contrast to lead with.

## Sources

- [How AI agents can redefine universal design to increase accessibility — Google Research blog](https://research.google/blog/how-ai-agents-can-redefine-universal-design-to-increase-accessibility/)
- [06 — Competitive Deep-Dive §1.1 (this project's own thread, cross-referenced throughout)](06-competitive-deep-dive.md)
