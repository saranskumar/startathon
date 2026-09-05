# PRD: Adaptive Capability-Profile Access Layer
### Accessibility as a continuous ability spectrum, not a set of disability labels

**Status:** Draft v3 — Startathon submission
**Owner:** [Team name / SCTCE]
**One-line concept:** A system that treats accessibility as a continuous *capability profile* instead of a set of disability labels, and fuses the right combination of input and output modalities for each user's actual abilities — with an AI agent covering the gaps where input is imprecise.

---

## 0. What changed from v2 (read this first)

v1 and v2 modeled users by **category** ("motor impaired," "speech impaired," "people with 2+ impairments"). v3 abandons categories entirely in favor of two ideas:

1. **Spectrum, not labels.** Every user is a point on a few *continuous ability axes*. Disability labels are a lossy compression of where someone actually sits.
2. **Composition, not selection.** Existing tools force the user to pick *one* accessible input (voice **or** switch **or** touch). We **fuse** whatever partial abilities a user has, because two weak modalities used together beat one weak modality used alone.

The rest of this document is written around those two ideas. The AI agent is infrastructure; the capability profile and the modality fusion are the product.

---

## 1. Problem Statement

### 1.1 The real problem: fixed tools assume a fixed point on the spectrum
Accessibility tooling today is built **per single impairment, at a single assumed capability point**:
- Screen reader → assumes *zero vision, good motor control, and the patience/ability to navigate linear menus*.
- Switch access → assumes *near-zero motor precision but reliable scanning timing and good vision*.
- Voice access / speech-to-text → assumes *clear, reasonably fast, reliable speech*.

Each tool works when the user sits **exactly** at the point it was designed for. The moment a user's actual abilities differ — even slightly — on any axis the tool didn't account for, the tool breaks down:
- A screen reader is useless-to-tedious if you *also* have a motor impairment that makes the required navigation gestures hard.
- Voice access fails if your speech is present but slurred or slow — it times out or mis-hears.
- Switch access assumes you can't touch at all, so it wastes the residual touch ability a user *does* have.

### 1.2 Why "multiple impairments" is the wrong framing (and spectrum is the right one)
People with a **single** impairment "make do" because a matching fixed tool exists near their point. People whose abilities **don't line up with any single tool's assumed point** — which includes, but is not limited to, people with multiple impairments — fall through. The honest framing is not "we serve people with 2+ diagnoses" (sounds like an edge case). It's:

> **We serve the long tail of ability combinations that fixed-point tools ignore.**

That is a platform problem, not an edge case.

### 1.3 The consequence today
Users in this long tail either:
- Stitch together multiple single-purpose tools that were never designed to cooperate (e.g. a switch scanner fighting a screen reader), or
- Depend on a caregiver/family member to operate the device for them.

Both are slow, effortful, and cost independence. The evidence we want to gather (see §8) is exactly this: tasks that *should* be independently doable get abandoned or handed off because no available tool matches the user's real coordinates.

---

## 2. The Core Model

### 2.1 Ability axes
Model **every** user — disabled or not — as a point on continuous axes. Minimum viable set for this project:

| Axis | Spectrum (one end → other end) | Governs |
|---|---|---|
| **Touch precision** | hits tiny targets → only one large zone → no reliable touch | Interface resolution (how many/how big the controls are) |
| **Speech clarity** | clear + fast → slow/slurred → single sounds only → none | Whether/how voice input is used, and how patient recognition must be |
| **Vision** | reads normal screen → needs large text → no usable vision | Output mode (screen vs. proactive narration) |

*(Future axes — cognitive load tolerance, hearing, steadiness/tremor — can extend the same model. Not in the v1 build.)*

### 2.2 The two theses
**Thesis A — Spectrum:** A tool that adapts to a user's *coordinates on these axes* serves vastly more people than a tool built for one fixed point.

**Thesis B — Composition (modality fusion):** When a user has *partial* ability on more than one axis, fusing those partial abilities produces a better interaction than any single modality alone — because each modality covers another's weakness:
- **Touch is good at selection** (pick this contact) but bad at free text.
- **Voice is good at free text** (say the message) but bad at reliable precise selection.
- A user with imprecise-but-present touch **and** slurred-but-present speech is far more capable using **both** — big touch zones for selection, patient voice for content — than being forced into either alone.

**Composition is the innovation.** Not the agent.

### 2.3 The capability profile (the object everything runs off)
One data structure drives the entire system:

```
profile = {
  touch:  {
    reachable_zone:   <region of screen the user can comfortably reach>,
    min_target_size:  <smallest control the user can reliably hit>,
    steadiness:       <tremor / accidental-touch tolerance>,
    max_controls:     <how many controls to show at once>
  },
  speech: {
    available:        <true | false>,
    clarity_level:    <full | partial | sounds | none>
  },
  vision: {
    mode:             <screen | large | none>
  }
}
```

- The **input** composition adapts to the input axes (touch + speech).
- The **output** composition adapts to the output axis (vision).
- Input and output are **decoupled**: e.g. great vision + no motor = rich screen output but minimal fused input; no vision + good motor = minimal narration output but rich input.

### 2.4 The precision–inference coupling
A deliberate design law of the system:

> **The less precise the user's input, the lower the interface resolution — and the more the agent infers, always gated by confirmation.**

- High-precision input → more direct controls, less AI guessing, less confirmation friction.
- Low-precision input → fewer/bigger controls, the agent fills the inference gap, and confirmation before consequential actions protects against wrong guesses.

Input precision literally tunes the ratio of *user specifies* vs. *AI infers*.

---

## 3. Goals

### 3.1 Product goals
- Represent each user as a capability profile across touch / speech / vision axes.
- **Compose input**: fuse the user's available partial abilities (touch + voice) into one interaction rather than forcing a single modality.
- **Compose output**: deliver results in the mode the user can perceive — normal screen, large text, or proactive real-time narration.
- Adapt **interface resolution** (control count/size, reachable zone) to the touch profile.
- Use an AI agent to perform the actual computer actions and to fill inference gaps when input is imprecise, always confirming consequential actions.

### 3.2 What the innovation is (state explicitly in the pitch)
The product is **not the AI agent** — agents that take instructions and act on a computer already exist. The product is the **capability-profile-driven adaptive I/O layer** that composes each user's actual abilities into a usable interaction, so users are not confined to a fixed interface built for one assumed impairment point.

### 3.3 Non-goals (out of scope for the MVP)
- A fully native on-device accessibility OS shell. The phone is a **remote control / thin client** by design, so the idea can be validated on existing agent infrastructure (e.g. OpenClaw) rather than building a platform first.
- Covering the entire spectrum in the demo. The build proves the model with **two points on the spectrum and a profile switch between them** — not the whole continuum (see §5).
- Perfect free-form transcription. Coarse, patient intent recognition is enough for v1 when speech is unclear.
- Every app/workflow. One bounded task for the demo.

### 3.4 Success metric (north star)
The system, **unchanged**, serves **two different capability profiles** on the same task — producing two different composed interfaces, both of which let the user complete the task using only the abilities they actually have.

Secondary (with a representative/proxy user):
- Independent task-completion rate (no external help)
- Time + error count vs. the user's current method (existing tool or caregiver-assisted)
- Whether the composed interface matched what the user could actually operate

---

## 4. User Model & Example Profiles

**Primary user:** anyone whose ability coordinates don't line up with a single existing fixed-point tool — prominently including people with overlapping motor / speech / visual limitations, but defined by *coordinates*, not diagnosis.

**Explicitly de-emphasized for v1:** users who sit exactly on an axis a mature tool already serves well (e.g. zero vision + full motor + good navigation patience → an ordinary screen reader is fine). Our value is the *combinations* those tools miss.

**Illustrative profiles (used as the demo's two points — see §5):**

*Profile A — "big-zone, no speech":*
```
touch:  { min_target_size: large, max_controls: 2, reachable_zone: bottom-half }
speech: { available: false, clarity_level: none }
vision: { mode: screen }
```
→ Composed interface: 2 large touch zones, no voice input, screen output.

*Profile B — "fused touch + slurred speech, low vision":*
```
touch:  { min_target_size: medium, max_controls: 4, reachable_zone: full }
speech: { available: true, clarity_level: partial }
vision: { mode: large / none }
```
→ Composed interface: more/medium controls for selection **plus** patient voice input for content, **plus** proactive narration output.

The single most important demo moment is switching from Profile A to Profile B and watching the **same system** reshape the interface.

---

## 5. What We Actually Build in 30 Hours (LOCKED SCOPE)

The spectrum is the pitch. The build proves it with **two points and a switch**. Locked contract:

1. **Two capability profiles**, not the whole spectrum — Profile A and Profile B from §4.
2. **One bounded task** demoed under both profiles (e.g. read + reply to a WhatsApp message — reuse the concrete flow from v1 unless the team picks another single task).
3. **Profile switch** that visibly reshapes the interface between A and B — this *is* the proof of the thesis; do not cut it.
4. **Input composition** shown at least once: Profile B must demonstrate touch-for-selection + voice-for-content in the *same* interaction (this is Thesis B; a demo without it only proves adaptivity, not fusion).
5. **Both output modes** appear across the two profiles (screen for A, narration for B) — this gets output composition demoed "for free" via the profile switch rather than needing a third build.
6. **Confirmation before consequential actions** + **interrupt** — hard constraints, not optional polish.

Anything beyond these six is future work in the pitch, not built. See §8 for the decisions still needed to finalize this section.

---

## 6. System Architecture

```
        ┌───────────────────────────────────────────────┐
        │              CAPABILITY PROFILE                │
        │   touch {zone,size,steadiness,max_controls}    │
        │   speech {available, clarity_level}            │
        │   vision {mode}                                │
        └───────────────┬───────────────────────────────┘
                        │ drives everything below
        ┌───────────────▼───────────────┐
        │   Phone (remote control /       │
        │   thin client)                  │
        │                                 │
        │  INPUT COMPOSITION:             │
        │   • adaptive touch surface      │
        │     (resolution set by touch    │
        │      profile: count/size/zone)  │
        │   • patient AI voice input      │
        │     (enabled + tuned by speech  │
        │      profile)                   │
        │   → fuses touch (selection) +   │
        │     voice (free text)           │
        └───────────────┬─────────────────┘
                        │ fused user intent
                        ▼
        ┌───────────────────────────────┐
        │          AI AGENT              │
        │   (e.g. OpenClaw-based)        │
        │  • interprets fused intent      │
        │  • fills inference gap when     │
        │    input precision is low       │
        │  • confirms consequential acts  │
        │  • executes on the computer     │
        │  • prepares output per profile  │
        └───────────────┬───────────────┘
                        │ result
                        ▼
        ┌───────────────────────────────┐
        │   OUTPUT COMPOSITION            │
        │   (set by vision profile)       │
        │   • screen / large-text view    │
        │   • proactive real-time         │
        │     narration                   │
        └─────────────────────────────────┘
```

**Why the phone is a remote, not a native app:** building a full on-device accessible shell can't be validated in 30 hours. The phone as a pure I/O remote, backed by an existing agent doing the computer control, lets the team test the real hypothesis — does profile-driven composition improve independent task completion — without first building a platform.

**Why the profile is the top-level object:** every adaptive behavior (input resolution, modality fusion, output mode, inference ratio) is a pure function of the profile. This is what makes "the same system reshapes for a different user" both true and demoable.

---

## 7. Requirements

### 7.1 Functional requirements
| ID | Requirement | Priority |
|----|---|---|
| FR1 | System stores a capability profile (touch/speech/vision) and can switch between at least two | P0 |
| FR2 | Touch interface resolution (control count, size, reachable zone) is derived from the touch profile | P0 |
| FR3 | Voice input is enabled/tuned by the speech profile and waits for slow/unclear speech without timing out | P0 |
| FR4 | For a partial-ability profile, touch (selection) and voice (content) are fused in one interaction | P0 |
| FR5 | Output is delivered per the vision profile: screen view or proactive real-time narration | P0 |
| FR6 | System detects a relevant event (e.g. new message) and surfaces it in the profile's output mode | P0 |
| FR7 | System confirms with the user before any consequential action | P0 |
| FR8 | User can cancel/interrupt before an action executes | P0 |
| FR9 | Agent executes the confirmed action on the actual application/computer | P0 |
| FR10 | Lower input precision → lower interface resolution + more agent inference (precision–inference coupling) | P1 |
| FR11 | Profile is user-configurable (even a preset switch counts) rather than hardcoded per build | P1 |
| FR12 | Additional axes (steadiness, cognitive load) influence the profile | P2 (stretch) |

### 7.2 Non-functional requirements
- No consequential action without explicit confirmation — hard constraint.
- Voice input must never penalize slow, unclear, or interrupted speech.
- Every interface state shows the fewest controls necessary for that state, at the size the touch profile requires.
- Profile switch must visibly and quickly reshape the interface (this is the demo's core moment).

---

## 8. Open Questions (resolve before/early in build)

| Question | Why it matters |
|---|---|
| Are Profile A and Profile B (§4) the final two demo points, or different coordinates? | These two points *are* the proof of the spectrum thesis |
| Is the demo task WhatsApp read/reply, or another single bounded task? | Need one task demoable under both profiles |
| How is the profile represented and switched in the demo — preset toggle, config screen, or a short "calibration"? | Affects build time and how convincingly "adaptive" it reads |
| For Profile B's fusion demo, what exactly does touch select vs. voice provide? | Thesis B must be visible in one concrete interaction |
| Do we already have OpenClaw (or equivalent) running, or is agent plumbing itself unbuilt? | Determines how much of 30 hours goes to agent infra vs. the I/O innovation |
| Which narration approach for the "no vision" output — TTS of agent summaries, at minimum? | Output composition needs at least one working non-visual mode |

---

## 9. Validation Plan

**What we want to learn:**
- Does profile-driven composition let a user complete the task more independently / faster than their current method?
- Does modality **fusion** (touch + voice together) outperform either modality alone for a partial-ability user? (Directly tests Thesis B.)
- Does proactive narration reduce missed information vs. requiring navigation to find it?

**How we'll test:**
- Baseline: same user/task with their current method (existing tool or caregiver-assisted) — record time, completion, errors.
- System: same user/task through the composed interface for their profile — record the same.
- If possible, also test the fusion condition against a single-modality condition for the same partial-ability user.

**Representative user is the highest-leverage non-coding action.** Even a clearly-labeled proxy (a teammate constrained to the exact coordinates of Profile A or B — e.g. one large touch zone only, or forced-slow speech) strengthens the submission far more than arguing the need in the abstract. Label proxies honestly as proxies.

---

## 10. Risks

| Risk | Mitigation |
|---|---|
| Spectrum framing reads as vague if the demo shows only one slice | Demo **two** profiles + the switch; state plainly "this is the validated slice, the profile engine is the extensible part" |
| Scope creep back toward "cover the whole spectrum / all axes" | §5 is the locked contract — two points, one task, one switch |
| Fusion (Thesis B) gets dropped under time pressure, leaving only adaptivity | FR4 is P0 — a demo without fusion under-sells the actual innovation |
| Agent/automation layer (OpenClaw or equivalent) unstable under time pressure | Timebox agent integration early; keep a manually-triggered fallback path for the live demo |
| Patient voice input is hard to show convincingly in a short pitch | Pair the live demo with a recorded example of slow/unclear speech being accepted |
| No representative user found in time | Clearly-labeled proxy constrained to a profile's exact coordinates |
| Profile switch demo fails live | Have a recorded backup of the A→B reshape |

---

## 11. Roadmap Beyond This Event (pitch narrative only — not build scope)

If two points on the spectrum prove the model, the same profile-driven architecture extends to:
- **More axes** (steadiness/tremor, cognitive load, hearing) — richer coordinates, same engine.
- **More of the continuum** — not two presets but a real calibration that places a user anywhere on each axis.
- **Fuller composition** — both output modes simultaneously, more input modalities fused, per-context resolution.
- **More tasks/apps** beyond the single demo workflow (email, shopping, banking) — the agent layer already generalizes; only the profile-driven I/O is the moat.

The through-line for every extension: **accessibility as coordinates + composition, not labels + fixed tools.**
