# 03. Research — Proactive Narration Output Layer

Research brief for the "watch the screen, decide what matters, speak it unprompted" output thesis in [15-brain-dump.md §15.3](../../idea/15-brain-dump.md) and [02-core-model.md §2.4](../../idea/02-core-model.md). Ties directly to the decided tech stack in [tech/README.md](../README.md): the agent already drives a Playwright-controlled Chromium browser and reads each page's accessibility tree (role/name/value/children).

---

## 1. Precedent for proactive/ambient screen narration

**Verdict: Moderate feasibility** — the *concept* is well precedented, but existing tools are either narrow (live regions: reactive-but-automatic, not truly "salience-ranked") or camera/scene-based (Seeing AI, Be My AI), not screen-state-based in the way this project needs.

- **ARIA live regions** are the closest existing web-platform primitive to "proactively narrate what changed without navigation." A `aria-live="polite"` (or `assertive`) region is announced by the screen reader automatically whenever its content changes, *without* the user needing to focus/navigate to it — this is exactly the "new WhatsApp message announced without navigating there" shape, just scoped to a page author explicitly marking a region as live. `aria-relevant`, `aria-atomic`, and `aria-busy` give some control over *what part* of a change is spoken. This validates the underlying idea (auto-announce on change) but live regions are **binary and site-authored** — they don't do intent-aware summarization or importance ranking; every change in a marked region gets spoken, which is the "noise" problem this project explicitly wants to avoid (§15.3 point 2).
- **Google Lookout (Explore mode)** proactively announces objects/text in the environment via camera without the user taking a photo — users describe it as a "narrator walking beside them." This is the best real-world precedent for *unprompted*, continuous narration as a product pattern, though it's camera/scene-based, not app-UI-state-based.
- **Seeing AI / Be My AI** are request-response (point camera, get description) or short-answer scene descriptions, not standing proactive monitors of app state. Be My AI can do follow-up Q&A; Seeing AI's Scene mode gives a basic description first, more detail on request.
- **Academic HCI**: general "ambient notification" and "intelligent notification system" literature (surveys on notification urgency/interruption, e.g. arXiv:1711.10171) is mature but is about *notifications*, not accessibility-tree-driven narration specifically. Dedicated BLV (blind/low-vision) HCI research is concentrated on screen readers, captioning, and tactile graphics — proactive/ambient *app-state* narration for BLV users specifically is an under-explored niche, i.e. this project's framing is a genuinely novel combination, not a solved problem to copy.

**Implication for the pitch:** it's fair to say "no one has combined ARIA-live-region-style automatic announcement with LLM-based salience filtering and intent-aware minimal narration for app/browser state" — this is a legitimate, not over-claimed, novelty point.

---

## 2. Detecting "what changed" and "is it worth surfacing"

**Verdict: Strong feasibility for detection, Moderate for ranking** — the detection half is a solved, cheap engineering problem given the existing Playwright/accessibility-tree stack; the ranking/filtering half needs a deliberately simple heuristic for a 30-hour build, not a research-grade system.

**Detecting change (technique):**
- Playwright already exposes `page.accessibility.snapshot()`, returning a serializable tree (role/name/value/children) — the same object the agent already reads for intent-matching (per `tech/README.md`). Poll or event-trigger this on a short interval (e.g. every 1–2s, or on Playwright's `domcontentmutation`/frame navigation/`load` events) and diff consecutive snapshots.
- Because the tree is already structured JSON, a **structural diff** (not raw DOM diff) is simpler than general DOM diffing: walk both trees by role+name path, and emit a changeset of {added node, removed node, changed value/name}. This avoids most DOM-diffing complexity (e.g. virtual-DOM reconciliation algorithms) because the accessibility tree is already a pruned, semantic representation — far smaller and more stable than the raw DOM.
- `MutationObserver` (browser-native DOM change API, batched/async, supports `attributeFilter` to reduce noise) is the standard low-level mechanism sites use to detect DOM changes and is what live-region implementations rely on internally; it's a good *fallback/supplement* if snapshot polling proves too slow, but is more DOM-shaped than accessibility-tree-shaped, so probably unnecessary if Playwright snapshot diffing already works.

**Ranking/filtering worth-surfacing (technique):**
- No off-the-shelf "salience score for UI change" library exists; the notification-salience HCI literature (content type, sender, context, timing) is a useful mental model but not directly portable.
- Realistic approach for the timebox: feed the **diff** (not the full tree) to the LLM already used for intent inference, with a short prompt: "here's what changed since last check, here's the user's current task context — is this worth interrupting narration for, and if so, what's the minimal thing to say?" This reuses the same LLM call pattern the project already has for intent-matching, so it's additive, not a new subsystem.
- Cheap pre-filter before even hitting the LLM: ignore purely cosmetic changes (style/attribute noise), require the diff to include an added node with non-empty accessible name, or a value change on a node marked with ARIA-live-equivalent semantics (role=alert/status, or a domain-specific allowlist like "new chat message row appended to a chat list container"). This keeps LLM calls (cost + latency) down to only meaningful diffs.

**Honest risk:** false positives (spam narration) and false negatives (missed genuinely important changes) are both easy to get wrong without real usage data/tuning — for a 30-hour demo, hard-coding the "what counts as important" allowlist for the specific demo app (Aperture / the mock site) rather than building a generalized salience model is the pragmatic path, and should be stated as such rather than oversold as a generalized solution.

---

## 3. LLM-based accessibility-tree summarization → minimal choice-set narration

**Verdict: Strong feasibility** — this is a proven pattern in recent HCI/NLP research, not a novel risk.

- **"Enabling Conversational Interaction with Mobile UI using Large Language Models"** (arXiv:2209.08655) is the most directly relevant precedent: LLM-generated summaries of mobile UI screens were judged *more accurate* than baseline in the majority of cases (64.1% by majority vote, unanimous for 52.8%), demonstrating LLMs are already good at compressing a UI's accessible representation into a short, useful description — exactly the "there are two buttons, press yes to turn on Bluetooth, press no to go back" pattern this project needs.
- **"LLM-Driven Optimization of HTML Structure to Support Screen Reader Navigation"** (arXiv:2502.18701) and **VizAbility** (arXiv:2310.09611, chart accessibility via LLM + tree-view) both show the broader pattern of LLMs operating over a structured accessibility representation (not raw pixels) to produce accessible, task-relevant output — reinforcing that reasoning over the accessibility tree (already the project's chosen approach) rather than screenshots is the right call for this kind of summarization too, not just for input-matching.
- **ScreenAudit** (LLM-based screen-reader-error detection in mobile apps) further validates LLMs' reliability at reasoning over accessibility metadata for practical, user-facing accessibility judgments.
- Practical implementation pattern: same LLM call used for change-detection ranking (§2) can, in one pass, both (a) decide if the change is worth surfacing and (b) produce the minimal spoken summary — a single prompt like "Given this accessibility (sub)tree and the user's inferred context, produce the shortest useful spoken description, phrased as a choice if the screen presents one" is a reasonable, buildable prompt, not a research problem.

---

## 4. TTS options for real-time narration

**Verdict: Strong feasibility** — mature, well-documented options exist at every price/latency point; the main constraint is Indian-language coverage and integration time, not availability.

| Option | Latency | Cost | Quality | Integration effort | Indian language support |
|---|---|---|---|---|---|
| **ElevenLabs (Flash v2.5)** | ~75ms (fastest commercial TTS) | ~$50/M chars (Turbo/Flash), ~$100/M (v3) | High, natural | Simple REST/SDK, streaming supported | Multilingual voices exist but Indian-language depth/naturalness is not its strength; pricier at scale |
| **Google Cloud TTS** | Good, not lowest | $4/M (Standard/WaveNet) – $16/M (Neural2) – $30/M (Chirp3 HD); free tier: 4M chars/mo standard, 1M neural | Solid, WaveNet/Neural2 good quality | Simple REST/SDK, well-documented, generous free tier | **380+ voices across 75+ languages/variants including Hindi and other major Indian languages** — best-documented broad Indian-language coverage among the big three |
| **Azure TTS** | Comparable to Google | $15/M (Neural), $22/M (Neural HD) | High quality, strong custom-voice option | SDK integration straightforward | Broad language support incl. Hindi; less explicitly documented for the full Indian-language set than Google |
| **On-device (flutter_tts)** | Zero network latency, instant | Free | Depends entirely on OS-installed voices — variable | Very simple Flutter plugin call, no network/API-key needed | **Weak** — flutter_tts delegates to the platform TTS engine (Android's Google TTS, iOS's Apple TTS); it has **no first-class support for Tamil, Kannada, Odia and similar Indian languages** (open GitHub issue confirms this gap); Hindi generally available since it's a major installed Android voice, but the long tail of Indian languages depends on what the specific device has installed |
| **Sarvam AI (India-focused)** | Not benchmarked here | Not benchmarked here | Purpose-built for Hindi/Tamil/Telugu/Hinglish | New/smaller SDK ecosystem | Flagged in current comparisons as the first provider to evaluate specifically for Hindi/Tamil/Telugu/Hinglish workflows — worth a look if Indian-language quality becomes the bottleneck, but adds integration-research risk in a 30-hour window |

**Recommendation:** Google Cloud TTS is the best fit for this build — broadest well-documented Indian-language voice coverage, generous free tier (covers an entire hackathon demo), simple REST API, and "good enough" (not best-in-class) latency is fine since narration doesn't need sub-100ms conversational turn-taking. Fall back to on-device `flutter_tts` only for English narration or as an offline/zero-cost fallback, not as the primary path given its Indian-language gaps.

---

## 5. Concrete implementation recommendation for the 30-hour build

**Verdict: Moderate feasibility for the full proactive/unprompted vision; Strong feasibility for a scoped-down version.**

### Simplest reliable pipeline (buildable in-scope)

```
[Agent's Playwright browser] 
     │  page.accessibility.snapshot() on an interval (e.g. every 1-2s)
     │  or triggered on known action-completion events (after agent clicks/fills)
     ▼
[Snapshot diff step]
     │  structural diff vs. last snapshot (role/name/value path compare)
     │  cheap pre-filter: drop cosmetic-only diffs, require added/changed
     │  node with non-empty accessible name
     ▼
[LLM call — reuse existing intent-inference LLM]
     │  input: diff + current task context (what the user was just doing)
     │  output: {worth_surfacing: bool, spoken_text: short string}
     ▼
[TTS — Google Cloud TTS REST call]
     │  spoken_text → audio
     ▼
[Phone client plays audio / or agent-host speaker for demo]
```

This pipeline reuses two things the project has already committed to (Playwright accessibility tree + an LLM call for the fused-intent step) — the narration layer is additive, not a new subsystem, which is what makes it buildable in the remaining time.

### Honest complexity/risk comparison

- **Simpler alternative — request/response narration** (user asks "what's on screen", agent reads current accessibility-tree summary once): this is nearly free given the existing stack — it's the same LLM-summarize-the-tree call as §3, just invoked on-demand rather than on a timer. Low risk, high reliability, easy to demo predictably.
- **Full proactive/unprompted narration** (continuous polling + diffing + salience filtering + interrupt-the-user speech) adds:
  - A polling/watch loop that must run concurrently with the agent's own action loop (coordination risk — don't want the agent's own clicks to trigger false "change detected" narration of its own actions).
  - Tuning the worth-surfacing filter to avoid narrating agent-caused UI changes as if they were "external" events like a new WhatsApp message — this needs an explicit distinction (agent-initiated change vs. externally-arriving change) that isn't automatic from the accessibility-tree diff alone; likely needs a simple flag ("suppress narration diffing for N ms after I just took an action").
  - Demo reliability risk: proactive narration triggering at the wrong moment (e.g. narrating during a live pitch) is a visible failure mode judges will notice, versus request-response's on-demand determinism.

**Recommendation:** build the request/response narration path first (cheap, reuses existing LLM+tree infra, guaranteed demo-safe), then layer the proactive polling+diff+filter loop on top *only if time remains*, using a hard-coded allowlist of "interesting" changes for the specific demo scenario (e.g. "new row appended to the WhatsApp-mock chat list container" → always narrate) rather than a general salience model. This gives a working, honest fallback story if the full proactive loop isn't stable in time, while still letting the demo show the flagship "unprompted narration" moment for the one scripted scenario it's rehearsed on.

---

## Sources

1. [ARIA Live Regions for Dynamic Content — UXPin](https://www.uxpin.com/studio/blog/aria-live-regions-for-dynamic-content/)
2. [Accessible notifications with ARIA Live Regions (Part 1) — Sara Soueidan](https://www.sarasoueidan.com/blog/accessible-notifications-with-aria-live-regions-part-1/)
3. [The Complete Guide to ARIA Live Regions for Developers — A11Y Collective](https://www.a11y-collective.com/blog/aria-live/)
4. [Seeing AI App Launches on Android — Microsoft Accessibility Blog](https://blogs.microsoft.com/accessibility/seeing-ai-app-launches-on-android-including-new-and-updated-features-and-new-languages/)
5. [Using Microsoft's Seeing AI in Day-to-Day Life — Equal Entry](https://equalentry.com/using-microsofts-seeing-ai-in-day-to-day-life/)
6. [Seeing AI and new AI abilities — AppleVis forum (Be My AI / Google Lookout comparison)](https://applevis.com/forum/ios-ipados/seeing-ai-new-ai-abilities)
7. [1 Intelligent Notification Systems: A Survey of the State of the Art — arXiv:1711.10171](https://arxiv.org/pdf/1711.10171)
8. [Designing Attention-Centric Notification Systems: Five HCI Challenges — ResearchGate](https://www.researchgate.net/publication/237135480_Designing_Attention-Centric_Notification_Systems_Five_HCI_Challenges)
9. [The scope and importance of human interruption in HCI design — ACM](https://dl.acm.org/doi/10.1207/S15327051HCI1701_1)
10. [MutationObserver: observe() method — MDN](https://developer.mozilla.org/en-US/docs/Web/API/MutationObserver/observe)
11. [Detect, Undo And Redo DOM Changes With Mutation Observers — Addy Osmani](https://addyosmani.com/blog/mutation-observers/)
12. [Accessibility testing — Playwright docs](https://playwright.dev/docs/accessibility-testing)
13. [Snapshot testing (ariaSnapshot) — Playwright docs](https://playwright.dev/docs/aria-snapshots)
14. [Validate Accessibility Tree of a Page in Playwright — journey of quality](https://journeyofquality.wordpress.com/2024/12/08/validate-accessibility-tree-of-a-page-in-playwright/)
15. [Enabling Conversational Interaction with Mobile UI using Large Language Models — arXiv:2209.08655](https://arxiv.org/pdf/2209.08655)
16. [LLM-Driven Optimization of HTML Structure to Support Screen Reader Navigation — arXiv:2502.18701](https://arxiv.org/abs/2502.18701)
17. [VizAbility: Enhancing Chart Accessibility with LLM-based Conversational Interaction — arXiv:2310.09611](https://arxiv.org/html/2310.09611v2)
18. [ScreenAudit: Detecting Screen Reader Accessibility Errors in Mobile Apps Using LLMs — ResearchGate](https://www.researchgate.net/publication/391240442_ScreenAudit_Detecting_Screen_Reader_Accessibility_Errors_in_Mobile_Apps_Using_Large_Language_Models)
19. [ElevenLabs vs Google Cloud TTS 2026 — Aloa](https://aloa.co/ai/comparisons/ai-voice-comparison/elevenlabs-vs-google-cloud-tts)
20. [Tested 1,800+ Voices: Google vs Azure vs ElevenLabs TTS 2026 — ttsforfree.com](https://ttsforfree.com/en/blogs/google-vs-azure-vs-elevenlabs-tts-comparison/)
21. [Google Cloud Text-to-Speech — Google Cloud product page](https://cloud.google.com/text-to-speech)
22. [Google Cloud Text-to-Speech Pricing (2026) — Costbench](https://costbench.com/software/ai-voice-tools/google-cloud-text-to-speech/)
23. [Best Voice AI API for Indian Languages in 2026 — CallMissed](https://www.callmissed.com/blog/best-voice-ai-api-indian-languages-2026-4)
24. [flutter_tts package — pub.dev](https://pub.dev/packages/flutter_tts)
25. [flutter_tts GitHub Issue #307 — no native Indian languages (Tamil, Odia, Kannada)](https://github.com/dlutton/flutter_tts/issues/307)
26. [flutter_tts List of Languages discussion — GitHub](https://github.com/dlutton/flutter_tts/discussions/191)
