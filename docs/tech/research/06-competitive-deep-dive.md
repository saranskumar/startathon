# 06. Competitive Deep-Dive: Modality-Fusion + AI-Agent Accessibility Layer

**Research date:** 5 September 2026
**Purpose:** Extend [14-market-research.md](../../idea/14-market-research.md) — that file already covers Voiceitt, Android Voice/Switch Access, TalkBack, Tobii Dynavox/PRC-Saltillo AAC hardware, and Ability-Based Design academic prior art (Wobbrock et al.). This file searches specifically for prior art on the two things this project claims are novel: (1) a **continuous ability-axis / capability-profile** user model, and (2) **composing/fusing multiple partial-ability modalities** with an **AI agent that executes real actions** and fills inference gaps.

Everything below is from live web searches conducted today. No product, paper, or startup here is invented. Where a search category found genuinely nothing close, that is stated explicitly rather than padded.

---

## 1. Multi-modality composition/fusion for accessibility (shipped or startup, 2023–2026)

### 1.1 Google Natively Adaptive Interfaces (NAI) — closest shipped/prototype analogue found
Google Research has a framework called **Natively Adaptive Interfaces (NAI)** that is the single closest match found to this project's combined thesis.

- Uses multimodal AI processing **voice, vision, and text simultaneously** rather than tracking one axis in isolation.
- Uses an **"Orchestrator"** that maintains shared context and delegates to specialized sub-agents (e.g., a Summarization Agent, a Settings Agent) — i.e., an agent layer that can autonomously adjust the interface on the user's behalf, not just describe it.
- Explicitly framed as a shift from *reactive* accessibility (screen readers translating an existing static UI) to *natively adaptive*, agent-driven interface architecture — closing what Google calls the "accessibility gap" (delay between feature release and assistive-tool support).
- Prototype example cited: **StreetReaderAI**, which keeps conversation history/context across a navigation session.

**Why this matters for differentiation:** NAI is a Google Research framework/prototype line, not a shipped consumer product, and it is *output/interface-generation* centric (an orchestrator adapting UI + narrating) rather than built around a **persistent, calibrated per-user numeric capability profile** driving *input-method selection* (which touch method, how much speech is trusted, how many controls to show) the way this project's `profile` object does. It is the strongest signal that a large lab is converging on the same idea, and should be treated as directional prior art / competitive risk, not as something already doing exactly this project's job.

Source: https://research.google/blog/how-ai-agents-can-redefine-universal-design-to-increase-accessibility/

### 1.2 Actain — startup, motor-impairment focus, closest commercial analogue
**Actain** is a startup building accessibility for people with motor impairments by combining **voice activation, reasoning algorithms/LLM-style planning, and computer vision** so users can execute tasks on a device. Described as blending speech, language, and vision AI "to emulate the intricacies of human-computer interaction," with a claimed productivity increase for users.

- This is the closest **commercial, agent-executes-actions** analogue found: voice + vision + reasoning fused into one interaction, aimed at motor-impaired users specifically.
- What is *not* evidenced in available sources: a continuous multi-axis ability profile, calibration UI, task-aware composition (Thesis C), or the precision→inference coupling law (§2.4 of 02-core-model.md). Public material reads as a single blended pipeline rather than an explicit profile object with per-modality confidence scores driving interface resolution.
- Could not independently verify funding stage, geography, or product maturity beyond the one source found; treat as an early-stage competitor to monitor, not a fully validated one.

Source: https://medium.com/@sanaakarkera/empowering-digital-independence-through-actain-868c0887b3d3

### 1.3 GestureVoice (SIGACCESS) — academic prototype, narrow but real fusion
A system called **GestureVoice** enables multimodal *text editing* for blind users by combining gesture and voice input (iOS + companion watch implementation). This is genuine input-modality fusion (touch/gesture + speech) shipped as a research prototype, but scoped to one task (text editing) for one population (blind users), not a general capability-profile-driven composition layer across touch/speech/vision and arbitrary tasks.

Source: https://dl.acm.org/doi/full/10.1145/3663547.3746388 (ACM SIGACCESS 2024/2025 proceedings)

### 1.4 What did NOT turn up
No shipped product or funded startup was found that (a) maintains an explicit **continuous multi-axis capability profile per user**, (b) uses that profile to **dynamically decide which input/output modalities to combine and at what interface resolution**, AND (c) has a general-purpose **AI agent executing real device/task actions** with confirmation-gated inference — all three together, as one system, across arbitrary tasks. NAI (§1.1) and Actain (§1.2) each cover two of the three pieces at most, based on available public material. This three-way combination — profile-driven composition + task-general agent execution + confirmation-gated inference — is the most defensible gap identified in this research.

---

## 2. Academic/research prototypes beyond Ability-Based Design (2023–2026)

### 2.1 "The Accessibility Capability Boundary" (arXiv, May 2026) — near-direct academic overlap
This is the single most important prior-art find in this whole research pass. The paper formally models accessibility as a **continuous, multidimensional capability space**, defining a user via an ability profile:

> 𝒰 = (a_v, a_m, a_c, a_h) — visual, motor, cognitive, and hearing abilities, each normalized to [0,1]

This is structurally almost identical to this project's `profile = {touch, speech, vision}` continuous-axis model (§2.1–2.3 of 02-core-model.md), just with different named axes (adds cognitive + hearing, no explicit speech axis). It also discusses multimodal *output* composition (audio + optional haptic + visual) in a worked example (a webcam-alignment assistant).

Key difference from this project: the paper's system is **AI-generated static HTML artifacts** synthesized per-user from natural-language prompts and deployed as single-file browser apps — it explicitly does *not* propose an autonomous agent executing actions; everything runs deterministically in a browser sandbox once generated. There is no persistent agent inferring intent from imprecise multi-modal input and confirming before acting — the "adaptation" happens at generation time, not at runtime via an agent loop.

**Implication:** the continuous-ability-profile idea itself (Thesis A) can no longer be pitched as unprecedented in academia as of a well-informed judge's knowledge — this May 2026 paper already formalizes it, with a citable equation. The defensible ground shifts to Thesis B/C (runtime modality *fusion* driven by that profile) plus the agent-executes-and-infers layer, which this paper explicitly disclaims.

Authors: Rizwan Jahangir (NUST Business School), Daisuke Ishii (Kiara Inc.). Source: https://arxiv.org/html/2605.19638

### 2.2 GUIDE project (EU, "Gentle User Interfaces for Elderly people") — older but structurally close prior art
Older (EU FP7-era) but structurally very close: GUIDE built a **user-model-driven "Smart Adaptation Layer" (SAL)** with explicit **fusion and fission mechanisms** giving elderly/impaired users multiple simultaneous input and output modalities for TV/set-top-box interaction, using "virtual user" profiles compiled from user studies plus a simulation engine to predict perception/interaction of impaired users at design time.

This confirms the fusion+profile idea has real prior art going back over a decade in EU accessibility research — worth knowing so the pitch doesn't imply the *general concept* of profile-driven multimodal fusion is new; it isn't. What's newer is doing it live, on a commodity smartphone, with an LLM-based agent filling inference gaps rather than a pre-simulated rules engine.

Sources: https://link.springer.com/chapter/10.1007/978-3-642-21672-5_37, http://www.guide-project.eu/index.php?item=7&mainItem=Consortium

### 2.3 Persona-L (arXiv, Sept 2024) — LLM + ability-based framework, but for design personas, not runtime adaptation
"Persona-L has Entered the Chat" combines an **LLM with an ability-based framework** to generate personas for people with complex/overlapping needs. This is a *design-time* tool for researchers/designers to generate realistic composite-disability personas — not a runtime system that calibrates a live user and adapts an interface/agent to them. Relevant as evidence that "ability-based + LLM" is an active 2024–2026 research thread, but it targets a different point in the pipeline (persona generation for design) than this project (live per-user runtime adaptation).

Source: https://arxiv.org/pdf/2409.15604 (full text could not be parsed cleanly by automated tooling; citation is from search metadata, treat title/abstract as verified, deep content unverified — recommend a human skim before citing specifics)

### 2.4 ADEPTS — human-centered agent design framework (not accessibility-specific but relevant to the agent-execution claim)
A 2025 paper proposes **ADEPTS**, a six-capability framework (Actuation, Disambiguation, Evaluation, Personalization, Transparency, Safety) for human-centered agent design. Not accessibility-specific, but directly relevant to the "agent infers + confirms" mechanism in this project (§2.4 of core-model.md) — it's general HCI/agent literature the project could cite to justify the confirmation-gated inference design pattern as aligned with emerging best practice for agent safety/personalization, rather than an accessibility-specific competitor.

Source: https://arxiv.org/pdf/2507.15885

### 2.5 What did NOT turn up
No paper was found building a **shipped, evaluated system** that combines (a) live per-user continuous capability calibration, (b) runtime multi-modality input/output fusion decided by that profile, and (c) an LLM agent executing real actions with confirmation. The Accessibility Capability Boundary paper (§2.1) is the closest on axes (a); GUIDE (§2.2) is closest on (a)+(b) but pre-dates LLM agents and uses static simulation rather than live inference; nothing found combines all three with a real evaluation.

---

## 3. India-specific / Global-South accessibility-tech

### 3.1 AssisTech Foundation (ATF) portfolio — no direct competitor, but relevant landscape
ATF (Bangalore-based accelerator, already referenced generically via ADIP/BHASHINI context in 14-market-research.md) has an active multi-cohort startup portfolio. None of the portfolio companies found do general-purpose capability-profile-driven modality fusion; all are single-modality or single-population tools, consistent with the "white space" already identified in 14-market-research.md §8:

- **Trestle Labs** — print/handwritten/digital content to audio for blind/low-vision users, 12+ languages.
- **DeepVisionTech.AI** ("Let'sTalkSign") — AI sign-language recognition for two-way deaf/hearing communication.
- **Glovatrix** — sensor gloves translating sign-language gestures.
- **Punarjeeva Technology Solutions** — gamified physiotherapy across motor/cognitive/musical rehab modalities (adjacent but rehab-focused, not access/control).
- **Infiheal** — AI co-therapist ("Healo") personalizing mental-health support by communication preference.
- **SparshMind Innovations** — XR neuro-rehabilitation for stroke/cerebral palsy/TBI.

None combine input modalities for general device control the way this project proposes; all are point solutions for one population or one task category. This corroborates rather than contradicts 14-market-research.md's existing conclusion.

Source: https://atflabs.org/startups/

### 3.2 Broader India assistive-tech landscape
Tracxn data (independent of the ATF portfolio) counts **244 assistive-tech startups in India**, 93 funded, funding peaking at >$26M in 2024 before a ~30% drop in 2025. No named startup in the available search results was doing capability-profile-driven multimodal fusion + agent execution; coverage skews toward single-disability tools (vision-to-audio, sign-language translation) consistent with §3.1.

Source: https://tracxn.com/d/explore/assistive-tech-startups-in-india/

### 3.3 AT2030 / Attvaran accelerator
The AT2030 Programme's **Attvaran** accelerator (India launch) exists specifically to power early-stage affordable-assistive-tech entrepreneurs for people with disabilities and older people — a relevant ecosystem/funding contact point, not a competitor. Worth noting as a potential post-Startathon accelerator target rather than a threat.

Source: https://at2030.org/attvaran-india-launch/

### 3.4 What did NOT turn up
No India-specific or other Global-South open-source project or government program was found that does cross-modality composition/fusion for general device access (as opposed to single-modality translation tools, BHASHINI-style ASR/TTS infra, or ADIP-style hardware subsidy, both already covered in 14-market-research.md). This remains a genuinely open niche in the India context specifically.

---

## 4. Patent landscape check (informational only, not legal advice)

No patent was found using the exact phrase "capability profile" in an accessibility-adaptive-input-fusion context. Closest results by category:

- **US20210056764A1 — "Transmodal input fusion for a wearable system" (Magic Leap).** Describes fusing multiple input modes (eye gaze, head pose, hand gesture, "totem"/controller input) for object selection in an AR/VR wearable. Not accessibility-framed and not phone-based, but it is a granted-family patent explicitly claiming multimodal input fusion mechanics (detecting convergence of multiple simultaneous input streams to resolve one user intent) — structurally close to the touch+speech fusion mechanism in this project. Worth a closer read if this project ever pursues its own IP, to understand claim scope and avoid overlap in a phone/AR context. https://patents.google.com/patent/US20210056764A1/en
- **US7554522B2 / CN1794159A — "Personalization of user accessibility options" (Microsoft, older family).** Dynamically responds to user preferences/abilities, detects interaction issues, and adjusts settings — an early precedent for "system infers accessibility needs and adapts," though it's settings-level personalization, not continuous-axis profile-driven modality composition or agent execution.
- **US20240289863A1 — "Systems and methods for providing adaptive AI-driven conversational agents."** Generates a user profile from history/data to drive an adaptive AI agent's behavior — general pattern-level overlap with "profile drives agent behavior," but not accessibility- or modality-fusion-specific.
- General multimodal-fusion patents exist in unrelated domains (autonomous driving sensor fusion — US11983625B2; emotion recognition — CN116450819B) confirming "fusion of multiple modalities into one inference" is a well-trodden general patent category, just not one anyone has narrowly claimed for *accessibility capability-profile-driven interface composition + agent execution* specifically, as far as this search found.

**Flag for the team:** none of these look like a blocking patent for a Startathon prototype, but the Magic Leap transmodal-fusion patent and the accessibility-personalization patent family are the two most worth a proper legal/IP review before any commercialization push, given their structural closeness to the fusion mechanism and the profile-driven-personalization mechanism respectively. This is not legal advice.

---

## 5. Differentiation summary — what's actually defensible

### What this research confirms is genuinely still open (safe to claim)
1. **No found system combines all three**: (a) a persistent, continuous, multi-axis, per-user capability profile, (b) runtime composition of multiple *partial*-ability modalities (not just multiple full modalities offered as alternatives) driven by that profile, and (c) a general-purpose AI agent that executes real actions and fills inference gaps under a confirmation gate. NAI (§1.1) and Actain (§1.2) each get closest but are missing at least one leg; the Accessibility Capability Boundary paper (§2.1) has the profile but explicitly not the runtime agent.
2. **The precision→inference coupling law** (§2.4 of core-model.md — lower input precision literally tunes how much the agent infers, gated by confirmation) was not found stated as an explicit design law anywhere in this search. This is a genuinely specific, articulable mechanism the project can own as a named contribution, distinct from "AI helps accessibility" in general.
3. **India-specific general-purpose modality-composition layer**: still a real gap — everything found in the India ecosystem is single-modality/single-population (§3).

### What is risky or likely to be challenged by a well-informed judge
1. **"Nobody models users on continuous ability axes."** False as of this research — the Accessibility Capability Boundary paper (May 2026, §2.1) already formalizes almost exactly this (a 4-axis [0,1] profile), and GUIDE (§2.2) did user-model-driven multimodal fusion over a decade ago in the EU. A judge who knows the HCI literature could cite either. Safer claim: "the *continuous-profile* idea has academic precedent; what's underexplored is doing it live, on a commodity phone, with an LLM agent closing the inference gap in real time — not at design/generation time."
2. **"Nobody fuses multiple modalities for accessibility."** False — GUIDE, GestureVoice, and NAI all do real multimodal composition to some degree; 14-market-research.md itself already concedes Android supports multiple modalities independently. The correct claim (already used correctly in 14-market-research.md §8) is about *profile-driven, task-aware composition of partial abilities*, not "multimodality exists nowhere else."
3. **"An AI agent executing actions for accessibility is novel."** Risky standalone — Actain, GitHub's general-purpose accessibility agent work, and the broader 2025–2026 "agentic AI + accessibility" discourse (OpenAI Operator-style perceive-reason-act loops applied to accessibility, per search in §1) show the AI-agent-executes-tasks pattern is already being explored industry-wide. The defensible slice is *agent execution rate-limited and shaped by a live capability profile with a precision-inference coupling law*, not agent execution alone.

### Recommended framing for pitch
> "Continuous ability-axis modeling has academic precedent (2026 HCI literature); modality fusion for accessibility has prior art back to EU projects like GUIDE; AI agents executing tasks is an active 2025–2026 industry trend (Google NAI, Actain, general agentic AI). No one found in this research puts all three together as one runtime system: a live per-user profile that *drives* which partial modalities get composed *and* how much an executing AI agent is allowed to infer versus must ask — governed by one explicit precision-inference coupling law. That specific combination, not any single piece of it, is the claim."

---

## Sources

- Google Research — Natively Adaptive Interfaces: https://research.google/blog/how-ai-agents-can-redefine-universal-design-to-increase-accessibility/
- Actain (via Medium writeup): https://medium.com/@sanaakarkera/empowering-digital-independence-through-actain-868c0887b3d3
- GestureVoice, ACM SIGACCESS: https://dl.acm.org/doi/full/10.1145/3663547.3746388
- "The Accessibility Capability Boundary," arXiv 2605.19638 (May 2026): https://arxiv.org/html/2605.19638
- GUIDE project — Contribution of Multimodal Adaptation Techniques to the GUIDE Interface: https://link.springer.com/chapter/10.1007/978-3-642-21672-5_37
- GUIDE project consortium page: http://www.guide-project.eu/index.php?item=7&mainItem=Consortium
- "Persona-L has Entered the Chat," arXiv 2409.15604 (Sept 2024): https://arxiv.org/pdf/2409.15604
- ADEPTS: A Capability Framework for Human-Centered Agent Design, arXiv 2507.15885: https://arxiv.org/pdf/2507.15885
- AssisTech Foundation startup portfolio: https://atflabs.org/startups/
- Tracxn — Assistive Tech startups in India: https://tracxn.com/d/explore/assistive-tech-startups-in-india/
- AT2030 Programme — Attvaran India launch: https://at2030.org/attvaran-india-launch/
- US20210056764A1 — Transmodal input fusion for a wearable system (Magic Leap), Google Patents: https://patents.google.com/patent/US20210056764A1/en
- US7554522B2 — Personalization of user accessibility options, Google Patents: https://patents.google.com/patent/US7554522B2/en
- US20240289863A1 — Systems and methods for providing adaptive AI-driven conversational agents, Google Patents: https://patents.google.com/patent/US20240289863A1/en
- "Sighted by Default" (VLM assistance for BLV users), UIST '26 preprint (checked, ultimately not a fusion/profile match — used for elimination): https://arxiv.org/pdf/2511.00945
- "Accessibility people, you go work on that thing of yours over there" — Disability Inclusion in AI Product Organizations, arXiv 2508.16607 (found in India-hackathon search, general industry-culture paper, not a system): https://arxiv.org/pdf/2508.16607
