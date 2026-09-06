# Slide outline — mapped to the six judging dimensions

**Product name:** KAI — Capability Awareness Interface.  
**Domain:** Inclusive access to essential services.  
**Format:** 5 minutes slides · 5 minutes demo · 5 minutes Q&A. Hard stop at 10:00 for talk + demo. Max 5 slides.

Open: `presentation/slides.html`. Photo: drop `presentation/media/01-origin.jpg`. TalkBack / Voice Access clips play on slide 1 (see `demo-clips.md`).

The scorecard scores the **whole slot** (talk + demo + Q&A), not one slide per letter. **E (team)** has no slide — answer it if asked.

On slide 1–2 you may name **the brother**. After the problem is clear, prefer **the user**.

Do not say: TAM, ₹95,000 crore, “26 million people need KAI,” architecture diagrams, library lists.

---

## A — Problem insight → Slide 1 (~50s)

| Beat | On-slide |
|---|---|
| User | A team member’s brother, with cerebral palsy. Observed directly. One reachable tap region; speech present but not consistently recognized. Overlapping motor + speech limits are common in cerebral palsy — not a one-off. |
| Gap | TalkBack needs swipes he cannot land. Voice Access needs speech that is not recognized. Each current system assumes one complete channel. Clips: tool works for a single impairment, then breaks on this combination. |
| Today | WhatsApp island. Outside that: Assistant after “call amma,” or a **caregiver is called in**. |
| Who else | Census 2011: 2.68 crore PwDs; 8% recorded multiple disabilities. rATA study: 24.5% AT need; unaffordability 36.9% of unmet need. MouthPad (~$1,400, US-only, dental scan), foot trackballs, AAC hardware exist. We build for the phone already in the user’s hand. |

**Say:** This is my brother. Cerebral palsy. On his phone four things work: WhatsApp, scroll, one tap region, a voice note. Opening another app or placing a call does not. Watch TalkBack — it needs swipes he cannot land. Watch Voice Access — it needs speech that is not recognized. When the task is outside that set, a caregiver takes the phone. Dedicated hardware already does adaptive input — MouthPad, foot trackballs — but it is extra kit, often expensive, often not here. He already has a phone.

**Numbers — say as estimates, not “people KAI will serve”:**

- 2.68 crore persons with disabilities (Census 2011).
- 8% of that count recorded **multiple** disabilities (same census).
- About **3 in 1,000** Indian children have CP (Chauhan et al. 2019 pooled estimate 2.95/1000 — study, not census). Optional; skip if short on time.
- rATA: 24.5% of Indians had an assistive-tech **need** (study extrapolation, not an official count). 36.9% of unmet need was inability to afford AT.
- MouthPad: **$1,400**, US-only, custom dental scan, months to ship. Point: hardware exists; our bet is software on a commodity phone.

**Do not claim his vision** either way — docs conflict.

---

## B — Validation and learning → Slide 2 (~50s)

### What even is the test?

Judges score: importance of the assumption, credibility of the test, honesty of the result.

**There are two tests. Do not mix them.**

| | During the 30 hours (what you can claim) | After the event (not yet done) |
|---|---|---|
| **Assumption** | “An AI agent would solve his problem.” | “With KAI, he completes more essential-service tasks independently than with WhatsApp + Assistant + a caregiver.” |
| **How** | Watch his real workflow. Note residual inputs that already work. Note that Assistant (already AI) already fails. Try / reject OpenClaw (overhead, security, latency). | Put the **built** app in front of him. Same tasks. Time, completion, errors vs today. |
| **Result** | Assumption did **not** hold. Dropped AI. Input layer first. | Unknown. Say that. |
| **Credibility** | Named user, direct observation, decision followed the evidence. | Will be credible **when** you run it. Invented “user reviews” would destroy this dimension. |

**User reviews:** you do not have them. Do not paste MouthPad testimonials or write fake quotes. The brother’s photo + the workflow you observed **is** the evidence. Reviews are the continuation plan (his network), not a slide 2 asset.

**Say:** We believed we needed an agent. We tested that against his day, not against a persona. He already has inputs that work. Assistant already fails. OpenClaw made it worse. We dropped AI. We have **not** yet proven the app with him. That is next, and we will use him and people he already knows.

---

## C — Solution and value → Slide 3 (~50s) → hand off to demo

| Beat | On-slide |
|---|---|
| Core value | Measure residual ability; map one task onto it. Calibration + composed input modes. Touch selects; voice fills when usable. Voice alone is not the product. |
| Scope we cut | Input layer is the product. Not a Voice Access clone. Not a trained recogniser. Not page-parsing / an agent as the core. Not a full accessible phone OS in 30 hours. |
| Vs agents | OpenClaw, Astra, NAI assume a clean speech/text channel. He does not have one. |
| Why a remote | Intended surface = his smartphone. 30-hour build = phone input layer driving a laptop, because a native phone shell is not finishable/testable here. |

**On “we avoided unnecessary scope like voice inputs”:** show **every input mode** in the demo, including voice as a *residual* channel. What you avoided is making **voice the whole product** (Voice Access / Astra) and making **real ASR** the 30-hour bet (it is simulated). If you literally cut voice from the story, the fusion thesis disappears — don’t.

**On parsing:** core value is the input mechanism. Ranking a page exists so a dense service can be reduced; it is not the headline. Say: parsing / agent execution was pushed further out so we could finish the thing he actually lacks — a control surface that matches his hands and speech.

**Say:** This is KAI. We measure him, then compose what is left — one profile, not a screen per person. We are not OpenClaw with a new UI. The phone is the real product; today’s laptop is how we test the input layer in 30 hours. That is what we will show.

---

## D — Product and technical execution → Slide 4 + the live demo

Judges score: core workflow, reliability, technical appropriateness, trade-offs, integrity of the live demo.

**Trade-offs to say (docs, not a tour):**

- Zero AI — deterministic calibration, mapping, ranking (`docs/idea/28`, desktop `domTreeEngine`).
- Phone is a remote / thin client (`docs/idea/07`) because a native accessible shell is out of 30 hours.
- Browser accessibility tree, not native OS apps (`docs/tech/README.md`).
- Flutter SDK for the input app; speech behind `SpeechSource` (simulated).
- Confirm + interrupt use the **measured** method (`code/app/README.md`).
- Same task, different profiles — including switch-scan floor. Invite judges to change the profile.

**Disclose once, at demo start:** speech is simulated; primary sites are our mocks; intended architecture is phone-native, this event uses phone ↔ laptop.

---

## E — Team execution and ownership → Q&A only (no slide)

You said this still needs a team discussion. Do not improvise a hero narrative. Agree **before** you walk in, in one minute:

1. **Who owned what** (names): input/calibration on the phone · ranking/relay on the laptop · research/docs · demo/clips.
2. **One hard cut you made together** — dropping OpenClaw / zero AI / input-layer-first instead of a phone OS.
3. **One challenge you absorbed** — time, wiring, speech stub, mock vs live site — and who decided.

If asked “who made the product decisions?”: mentors challenged; **every decision stayed ours** (event rule). The no-AI lock is a team decision, not a mentor’s.

Fill this table and stop:

| Person | Owned | Cut they argued for |
|---|---|---|
| | | |
| | | |
| | | |

---

## F — Communication and continuation → Slide 5 (~40s)

| Beat | On-slide |
|---|---|
| Proven | Profile reshape. Page ranking without an agent. AI assumption failed. |
| Uncertain | Independent extra tasks with him. Real ASR. Confirmation load. |
| Next | Him in front of the app. Hosted recognizer if speech is added. Then ordinary websites. Then native phone shell. |
| After | He is tester one. His network — people with similar conditions already known to the family — is how we get feedback and keep building. Not a go-to-market slide. |

**Future scope (say two, not the whole roadmap):** real ASR swap behind `SpeechSource`; native on-phone shell; live third-party sites; more ability axes. Full list lives in `docs/idea/12-roadmap.md` — do not read it.

**Say:** We proved the input layer and the ranking. We have not proved KAI with him on a live service. Next is him, then the people around him who already live this. Same phones they already have.

---

## Demo — 5 minutes

One workflow. Clips of TalkBack/Voice Access belong on **slide 1**, not here.

1. Calibrate — or a preset that matches him (large targets, one reachable region, partial speech). Name the skip.
2. Show **calibration scores**, then **more than one input mode** (buttons, then stick or switch). Then one complete task: discrete choice + confirm; text = touch selects, simulated voice fills. Interrupt bar.
3. If time: laptop on one Aperture Daily page (RailLink or the form). Ranked actions, one real click. Say whether the phone relay is live in this run.

Backup: recorded calibration, then live task views.
