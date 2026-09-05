# 1. Problem Statement

## 1.1 The real problem: fixed tools assume a fixed point on the spectrum
Accessibility tooling today is built **per single impairment, at a single assumed capability point**:
- Screen reader → assumes *zero vision, good motor control, and the patience/ability to navigate linear menus*.
- Switch access → assumes *near-zero motor precision but reliable scanning timing and good vision*.
- Voice access / speech-to-text → assumes *clear, reasonably fast, reliable speech*.

Each tool works when the user sits **exactly** at the point it was designed for. The moment a user's actual abilities differ — even slightly — on any axis the tool didn't account for, the tool breaks down:
- A screen reader is useless-to-tedious if you *also* have a motor impairment that makes the required navigation gestures hard.
- Voice access fails if your speech is present but slurred or slow — it times out or mis-hears.
- Switch access assumes you can't touch at all, so it wastes the residual touch ability a user *does* have.

## 1.2 Why "multiple impairments" is the wrong framing (and spectrum is the right one)
People with a **single** impairment "make do" because a matching fixed tool exists near their point. People whose abilities **don't line up with any single tool's assumed point** — which includes, but is not limited to, people with multiple impairments — fall through. The honest framing is not "we serve people with 2+ diagnoses" (sounds like an edge case). It's:

> **We serve the long tail of ability combinations that fixed-point tools ignore.**

That is a platform problem, not an edge case.

## 1.3 The consequence today
Users in this long tail either:
- Stitch together multiple single-purpose tools that were never designed to cooperate (e.g. a switch scanner fighting a screen reader), or
- Depend on a caregiver/family member to operate the device for them.

Both are slow, effortful, and cost independence. The evidence we want to gather (see [10 — Validation Plan](10-validation-plan.md)) is exactly this: tasks that *should* be independently doable get abandoned or handed off because no available tool matches the user's real coordinates.
