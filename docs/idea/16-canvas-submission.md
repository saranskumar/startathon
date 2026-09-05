# 16. Canvas V1 — Event Submission Answers (current, supersedes draft framing in places)

These are the actual answers filled into the event's "Canvas V1" form. Cleaned up for readability, not rewritten — content is verbatim from the team. This is now the **most current statement of scope and framing** for pitch purposes; where it conflicts with earlier docs (esp. [07-architecture.md](07-architecture.md) and [docs/tech/README.md](../tech/README.md)'s AI-agent framing), this doc wins and the older ones need a pass — flagged inline below and in [09-open-questions.md](09-open-questions.md)-style callouts.

---

## Team name
*(blank — fill in before submitting)*

## What problem are you solving, and for whom?

Well-developed accessibility tech already exists for **single** impairments:
- Visually impaired people can use TalkBack/Narrator to navigate almost any app.
- People with motor impairments can use Voice Access and perceive the output on screen.

But people with **multiple, overlapping** impairments — cerebral palsy is a strong fit — have a hard time with existing tools, on both the input and output side: limited hand dexterity, limited speech ability, and limited vision, together.

**What we're solving:** their limited-input problem, by letting them control a wider set of inputs than any single existing tool lets them reach — plus a **smarter screen reader** that's easier to operate for people who struggle to control a conventional screen reader.

## What is the strongest evidence that this problem matters?

One team member has a brother with cerebral palsy, and has directly observed him — and other people with similar conditions — interacting with technology: they can do certain specific inputs really well, but can't control everything with just that.

## What have you learned or changed since kickoff?

1. Learned about the accessibility tree and its applications.
2. Learned about existing accessibility tools and their limitations.
3. **Decided not to make this unnecessarily AI-powered or agentic.**

> **Flag:** point 3 is a real shift from the AI-agent-centric framing in [07-architecture.md](07-architecture.md) and [docs/tech/README.md](../tech/README.md) (both currently describe an LLM-driven agent, originally OpenClaw-based, interpreting fused intent and executing actions). It's directionally consistent with the tech-research findings in [docs/tech/research/04-agent-execution-layer.md](../tech/research/04-agent-execution-layer.md), which already recommended dropping OpenClaw for a small, non-autonomous, confirmation-gated loop rather than a general agent framework — but "not unnecessarily agentic" is a stronger statement than that research thread assumed. Worth a short team conversation on exactly how much LLM inference survives (see Open Questions below) before the architecture doc is updated to match.

## What is still uncertain?

- For the screen reader: how to determine what's important to surface vs. not.
- How much of the system needs LLMs at all — for understanding what's on screen, or for parsing the user's input — versus simpler deterministic logic.

## What is the most important assumption you need to test?

That we can parse the user's input even if it has gaps.

*(Restated a second time in the form, same substance:)* That we can map a larger input space of any app to the limited set of inputs a disabled person can actually give.

> **Note:** this reframes the previously-pinned riskiest assumption ([11-risks.md](11-risks.md): "the AI guesses right often enough that confirmation doesn't become annoying") in input-parsing terms rather than action-inference terms. The two are related but not identical — "can we parse gappy input" is a narrower, more testable claim than "does the agent guess right about what to *do*." Recommend reconciling these into one current statement rather than tracking two versions.

## How will you test it?

By giving a beta version to the team member's brother — who has motor and visual impairment — for real testing, and recording his feedback.

> **Note:** this is a real upgrade over [10-validation-plan.md](10-validation-plan.md)'s "clearly-labeled proxy" fallback plan — an actual representative user, not a proxy, is now the stated test subject. Update 10-validation-plan.md to reflect this as the primary plan rather than the aspirational "if possible" case.

## What result would support or weaken that assumption?

By analyzing how satisfied the user was while navigating, after using the software.

*(Restated once more, more concretely:)* **Support:** if the user is able to use more apps/websites, with more functionality, than they were able to before. **Weaken:** the inverse — no meaningful gain in what he can access or do, or the input-parsing gaps produce wrong/unusable results often enough that it doesn't actually extend what he can do.

## How will you know whether the test worked?

By analyzing how satisfactory the user found navigating through the software after using it.

## What is the smallest useful thing you need to build to run that test?

The input layer on the smartphone that adapts to the user's abilities.

> **Note:** this narrows "smallest useful thing" to just the adaptive input/calibration layer — not the full pipeline (agent execution + narration) described in [07-architecture.md](07-architecture.md). Consistent with treating the input layer as the actual innovation being tested (per [04-goals.md](04-goals.md) §4.2's "the product is not the AI agent") — worth confirming this is also how [05-scope.md](05-scope.md)'s locked build scope should be read.

## What are you deliberately not building?

- **Not** a fully automated "J.A.R.V.I.S."-style agent that automates every task from speech instruction alone.
- **Only** targeting websites for now — using the JS DOM to parse on-screen content. Any-app support would hit real parsing problems this scope avoids. (This matches the already-decided browser-accessibility-tree approach in [docs/tech/README.md](../tech/README.md).)
- **Not** running the whole system on a standalone smartphone yet — the phone is the input layer only, controlling a separate computer, so the input system itself can be refined and validated first. Once the input system is validated with real disabled users, the plan is to build toward a standalone-smartphone version.

## How will they know it worked?

If the user feels they're able to access these services in a much more efficient and productive way than before.

---

## Open items this raises for the rest of the docs

1. **Reconcile the "not agentic" decision with [07-architecture.md](07-architecture.md) and [docs/tech/README.md](../tech/README.md).** Both still describe an LLM-driven agent interpreting fused intent and filling inference gaps. Decide and document: is the LLM still doing intent-matching/inference (as [docs/tech/research/04-agent-execution-layer.md](../tech/research/04-agent-execution-layer.md) assumed, just via a small custom loop instead of OpenClaw), or is more of the system meant to be deterministic/rule-based than that research thread assumed?
2. **Update [10-validation-plan.md](10-validation-plan.md)** to reflect a real representative user (the brother) as the primary test plan, not a fallback proxy.
3. **Reconcile the two statements of the riskiest assumption** — "agent guesses right often enough" ([11-risks.md](11-risks.md)) vs. "we can parse gappy input" (this doc) — into one current version.
4. **Confirm the "smallest useful thing"** (input layer only) against [05-scope.md](05-scope.md)'s locked demo scope, which currently also includes agent-driven form submission and narration — decide whether those stay in scope or move to a later validation phase after the input layer is proven.
