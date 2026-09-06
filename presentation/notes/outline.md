# Slide outline

**Product name:** KAI — Capability Awareness Interface.

**Format (event template):** 5 minutes presentation · 5 minutes product demo · 5 minutes Q&A. Hard stop at 10 minutes for talk + demo. Maximum 5 slides.

Open: `presentation/slides.html` · ← → / Space / click.

Journey: Problem → Evidence → Learning → Solution → What we built → What next.

**Refer to the person as “the user.”** Do not say he / him / his / brother on stage or on slides.

Do not say: TAM, competitor tables, architecture diagrams, library lists, open-source/revenue positioning, market size.

---

## 1 — Problem & User (~50s)

**Title:** Problem & User

| Beat | On-slide |
|---|---|
| User | A person with cerebral palsy. Observed directly. Reliable motor input is limited to one region of a smartphone screen; speech is present but not consistently recognized. |
| Problem | The user can operate WhatsApp—scroll, tap that region, send a voice note. The user cannot independently open other applications or place a call. Existing tools each require one complete ability the user does not have. |
| Today | Tasks outside that set are done through Google Assistant, after extensive training on phrases such as “call amma,” or by a caregiver operating the device. |
| Why it matters | Independent use of a phone the user already owns is confined to a single application. Remaining tasks are abandoned or delegated. |

**Say:** The user has cerebral palsy. We know this from direct observation. On the user’s phone four things work: WhatsApp, scroll, one tap region, a voice note. Opening another app or placing a call does not. TalkBack still needs swipes the user cannot land. Voice Access still needs speech that is not recognized. Today that is Assistant training or a caregiver. Independence is confined to one app.

**Do not claim vision either way** — docs conflict ([15](../../docs/idea/15-brain-dump.md) vs [06](../../docs/idea/06-user-model.md)/[16](../../docs/idea/16-canvas-submission.md)).

---

## 2 — Validation & What You Learned (~50s)

**Title:** Validation & What You Learned

| Beat | On-slide |
|---|---|
| Evidence | Direct observation of the user, and through the user a community of people with similar conditions. Not a survey. Not a persona. |
| Assumption | That we require AI—that an AI agent would solve the user’s problem. |
| Observed | The user already has a small set of reliable inputs. Google Assistant, itself an AI, already fails the user. The bottleneck is mapping a large application onto that set, not another agent. |
| Changed | Dropped OpenClaw: performance overhead, security issues, and it is too slow. No AI. A deterministic DOM engine ranks the page instead. |

**Say:** Evidence is watching the user, and a community of people with similar conditions. We assumed we would need AI—that an agent would solve the user’s problem. We were wrong. The user already has a working input set; Assistant is already an AI and already fails. OpenClaw added performance overhead, security risk, and latency. We dropped it. A DOM engine ranks the page instead.

**Honest:** observational evidence that changed the architecture. Formal beta of the built app with the user is still planned, not done.

---

## 3 — Your Solution (~50s) → hand off to demo

**Title:** Your Solution

| Beat | On-slide |
|---|---|
| What it is | **KAI — Capability Awareness Interface.** Measures what the user can do, then maps any task onto those residual abilities. Touch selects. Voice, when usable, supplies content. |
| How it fits | Calibration produces a capability profile. A runtime composes primitives: input method, target size, reach zone, voice mode, visual field. A webpage is reduced to ranked actions by a DOM engine. No AI. |
| Value | The user keeps the inputs that already work and reaches apps beyond WhatsApp, without handing the phone over. |
| Vs today | TalkBack still needs swipe gestures the user cannot land. Voice Access and Assistant still need speech that is not recognized. KAI does not require one complete channel. |

**Say:** This is KAI, the Capability Awareness Interface. We measure the user, then compose what is left—one profile, not a separate screen per person. The phone only offers inputs the user can operate. The desktop reduces a dense page to ranked actions without AI. That is what we will show.

---

## 4 — What You Built (~50s)

**Title:** What You Built

| Beat | On-slide |
|---|---|
| Phone | KAI on Flutter: tap-or-hold setup, optional caregiver training, axis-gated calibration, a live profile (reach, methods, voice vocabulary, visual field, contrast). Four task shapes through four methods; touch-plus-voice on text. |
| Desktop | Playwright reads a page’s accessibility tree. A heuristic DOM engine ranks navigation vs information and can act on a node. A zooming navigator uses the same ranking. No LLM. |
| Choices | Zero AI. No OpenClaw (overhead, security, latency). Browser tree, not native OS apps. Phone and desktop are not yet wired. Primary demo is self-built mocks (Aperture Daily). |
| Not real yet | Speech recognition is simulated. TTS / narration is not built. Phone intents stop on an on-screen strip. They do not yet drive the laptop. |

**Say:** Two working halves of KAI, not yet connected. Speech is simulated on purpose so the room does not depend on a microphone. Say that again in the demo.

---

## 5 — Results & What Comes Next (~40s)

**Title:** Results & What Comes Next

| Beat | On-slide |
|---|---|
| Proven | KAI can measure a profile and reshape the same task to match the user. A real page can be ranked without an AI agent. The assumption that AI would solve the user’s problem did not hold. |
| Uncertain | Whether the user can complete more tasks independently than with WhatsApp, Assistant, and a caregiver. Whether real speech recognition works for the user. |
| Next week | Wire the phone to the desktop. Put KAI in front of the user. Decide whether to add a real speech package. |
| To be useful | The user must reach apps currently abandoned or handed off, without confirmation becoming constant interruption, on ordinary websites—not only our mocks. |

**Say:** We proved the input layer and the ranking. We have not yet proved KAI with the user on a live site. That is the next test.

---

## Demo — 5 minutes

One workflow. Do not tour every feature.

**Journey to show:** can the user operate something beyond WhatsApp using only what the user can already do?

1. **Calibrate** on the phone (or land on a profile like the user’s: large targets, one reachable region, partial speech). State if you skip to a preset.
2. **One complete task** on the phone — discrete choice + confirm, then the text task (touch selects, simulated voice fills). Show the confirmation gate and the interrupt bar.
3. **If time:** desktop inspector on one Aperture Daily page (e.g. RailLink or the form). Show the ranked navigation list and one real click. Say this is the page-reduction half, **not yet driven by the phone**.

**Say out loud, once, at the start of the demo:**

- Speech recognition is **simulated**.
- Phone intents **do not yet drive** the laptop.
- Target sites are **our mocks**, not WhatsApp or a live third-party app.

Backup if live calibration fails: recorded calibration, then live task views.
