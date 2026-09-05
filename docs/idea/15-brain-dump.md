# 15. Brain Dump — Pitch Narrative & New Threads (raw, unedited into other docs yet)

Captured from a voice brain-dump on how to actually *present* this to judges, plus a few product threads that came up while explaining it out loud. This is intentionally closer to spoken language than the other docs — treat it as raw material to fold into [13 — Event Submission](13-event-submission.md) and the pitch deck, not as a finished spec.

---

## 15.1 Open with two things, before the model

**1. This is not a revenue-model pitch.** Say it plainly at the start: this is being built for public good, open source (already the recommended positioning in [14 — Market Research](14-market-research.md) §5, §6, §10 — just needs to be said *first*, not buried).

**2. This is personal, and it's the actual reason the point lands.** Lead with the origin story before the model or the axes — not as a footnote in the user-model doc, but as the opening beat of the pitch itself:

> Shreevardhan's brother has cerebral palsy. On his phone, he can only do a narrow, specific set of things: open WhatsApp, scroll through his chats, tap in one region of the screen he can reliably reach, and record/send voice notes. He can see fine. For anything outside that narrow set — opening other apps, calling someone — he uses Google Assistant. But his speech isn't always clearly recognized, so getting it to work reliably took a lot of manual practice: real training effort just to get Google to consistently recognize "call amma" or "call father."

This is the moment that makes the whole framing click for judges — say it early enough that the rest of the pitch is obviously *for* this, not an abstract accessibility thesis they're asked to take on faith.

---

## 15.2 The "who's already served" framing (new opening structure for the problem slide)

Instead of opening with the capability-profile model directly, open with three examples of people the *existing* tools already serve well — then name the gap as everyone left over.

| If a person has... | ...they can already use | Why it works for them |
|---|---|---|
| No vision, but good hand control | A screen reader (TalkBack, VoiceOver) via keyboard/touch navigation | They can physically operate the navigation gestures the screen reader requires |
| Motor/touch difficulty, but fine vision and speech | Voice Access (phone or computer) | Clear speech reliably drives the interface; they can see the screen to verify results |
| Can reliably type or speak clearly | General-purpose AI agents (LLM agents, Google Astra-style assistants) | These already assume a working, precise input channel — voice or text — to receive instructions |

**The gap this project targets:** people who don't have *any* single clean channel — e.g. someone with both limited vision *and* limited hand precision at once. Screen readers assume the hand control to operate them. Voice Access assumes clear speech and sight to verify. General AI agents assume a working precise input channel to talk to in the first place. This person has none of those individually, but *does* have partial ability across more than one — which is exactly Thesis B (composition) from [02 — Core Model](02-core-model.md), now with a sharper opening hook than the current abstract phrasing in [01 — Problem](01-problem.md).

This reframes 01-problem.md's existing "long tail of ability combinations" line into something demoable in three quick beats before the audience even hears the words "capability profile."

---

## 15.3 The output side needs its own worked example (currently under-specified)

The existing docs describe output composition abstractly (screen / large text / narration, [02 — Core Model](02-core-model.md) §2.3). The brain-dump adds a concrete mechanism worth writing up properly:

**Worked example — WhatsApp, for a user with limited vision *and* limited hand precision:**

A sighted user with good hand control who's blind can learn to navigate to WhatsApp's chat list with a screen reader because they have the motor precision to operate the screen reader's navigation gestures in the first place. Our target user doesn't have that — they can't reliably operate the gesture-based navigation a screen reader itself requires, so they'd never even reach the chat list to have it read to them.

So the system can't just be a screen reader bolted onto low vision. It needs to:

1. **Watch the screen proactively**, not wait to be navigated to — scan for state changes / new content (a new message, a badge count) without requiring the user to first navigate there.
2. **Decide what's worth surfacing** — not read everything, only what's contextually relevant (an "important update" the user needs to know about now).
3. **Speak it unprompted**, in the user's output mode (narration).

**Second worked example — a settings screen (e.g. Bluetooth toggle):**

Context matters, not just content. If the user has just landed on a Bluetooth settings screen (inferred from *how* they got there — e.g. they came from a "connect a device" flow), the system doesn't just describe the screen generically. It infers the likely intent and offers the minimal, task-shaped choice:

> "There are two buttons on your screen. Press yes to turn on Bluetooth. Press no to go back."

This is the **precision–inference coupling** ([02 — Core Model](02-core-model.md) §2.4) applied to *output*, not just input: low-precision users get a narrower, more inferred, more pre-digested description rather than a literal readout of the full screen. Worth a short addition to §2.4 or its own subsection — currently the doc frames the coupling as input-resolution-only ("fewer/bigger controls"); this extends it to *narration resolution* too.

---

## 15.4 The input side can be pattern-based, not AI-based — worth stating explicitly

Important framing point that isn't clearly stated in [03 — Input & Calibration](03-input-calibration.md): the *task-aware fallback interaction* itself doesn't need to be AI/LLM-driven at all — it's closer to a fixed state machine per input method, which is actually a strength to say out loud (cheaper, more predictable, more auditable than "AI decides everything"):

- **Binary/switch-style input** (e.g. only reliable yes/no): press "no" to move to the next option and have it read aloud; press "no" again to advance again; press "yes" to select the currently-announced option. This is effectively single-switch scanning ([03 — Input & Calibration](03-input-calibration.md) §3.5) implemented as the *simplest* case, not the most exotic one — worth reconsidering whether §3.5 is really "not built" or whether it's actually the natural minimum viable interaction and should be pulled into scope.
- **Scroll-only input** (can't tap precisely, but can scroll): scrolling down moves to the next option (reads it aloud / highlights it), scrolling up moves to the previous one, a tap/click selects the currently-highlighted option.
- Other method families as already covered in 03-input-calibration.md §3.1–3.3: joystick, trackpad, etc.
- **If the user can see clearly, the narration/output layer isn't needed at all** — output composition is genuinely conditional, not always-on, which is worth stating plainly: a user with good vision and only a motor limitation gets the adaptive *input* layer with zero narration overhead.

The AI's job in this picture is narrower and more honest than "the AI drives the interaction": it fills inference gaps (§2.4) and interprets fused/ambiguous intent — the actual moment-to-moment interaction pattern per method is a fixed, designed state machine. This is worth stating explicitly in the pitch (see the research brief's pitch-strategy section) since "we don't use AI where we don't need it" is a stronger, more credible claim than implying AI is doing more than it is.

---

## 15.5 Speech calibration needs to account for real-world training effort

The Google Assistant anecdote (§15.1) is concrete evidence for a gap in [03 — Input & Calibration](03-input-calibration.md) §3.1's voice calibration section: it currently treats voice calibration as a **one-shot** test (say one fixed phrase, bucket into a clarity tier). The real-world case it's modeled on required **repeated practice** before recognition worked reliably for specific phrases ("call amma").

Two implications worth adding to 03-input-calibration.md:
- Calibration may need a **per-phrase learning loop**, not just a single clarity score — some phrases/words may become reliably recognizable with repetition even if general speech clarity stays low.
- This suggests a **user-specific vocabulary/phrase list** (contacts' names, common commands) that gets extra calibration attention, rather than treating "speech clarity" as one flat number across all possible utterances.

Not necessarily event-build scope, but should be logged as a real open question rather than left implicit.

---

## 15.6 Phone-as-remote-control decision, restated with the actual reasoning

[07 — Architecture](07-architecture.md) already documents *that* the phone is a thin client controlling a separate computer rather than a native on-device accessibility shell, but the brain-dump adds the actual reasoning trace worth having on record: the original inspiration (§15.1) is entirely phone-native — the brother only ever uses a phone. Building a full native-phone accessibility shell in 30 hours isn't viable, so the team is validating the *same underlying model* (capability profile → composed interaction) via a phone-as-remote-control controlling a computer instead, on the understanding that the phone's own adaptive control surface — the calibration flow and the smart input-composition UI on the phone itself — is the actual innovation being tested, independent of what it happens to be remotely controlling. Worth one explicit line in the pitch: "the real product surface is phone-native; today's demo controls a computer because that's what's buildable in 30 hours, not because that's the end architecture."

---

## 15.7 Open threads not yet resolved

- Exactly how proactive screen-watching decides what counts as "important enough to surface unprompted" — this is a real design question for the output layer (§15.3), not yet specified anywhere.
- Whether per-phrase speech calibration (§15.5) is in event scope or purely roadmap.
- Whether §3.5's single-switch scanning should move from "prepared answer, not built" to core scope, given §15.4's point that it may be the simplest case rather than the most exotic one.
- One more thread the brain-dump flagged but didn't finish ("another thing... I'll say that later") — flag for Shreevardhan to fill in later rather than guessing at it here.
