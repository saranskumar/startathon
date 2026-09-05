# 17. Meeting Notes — Tree Simplification & Whether AI Is Needed (unverified transcript)

**Source:** auto-generated meeting summary (Essential Space), Sept 5 2026 18:46–18:56, three unnamed speakers. **Not verified against a recording or by the team — treat as a rough transcript of a real conversation, not a settled decision.** Captured here because it's the actual discussion behind the "decided not to make this unnecessarily AI-powered or agentic" line in [16 — Canvas Submission](16-canvas-submission.md).

---

## What was discussed

**The core question:** given the accessibility/DOM tree of a real app or site, how does the system figure out which elements matter enough to show the user, without the user having to manually browse the whole tree?

- Concrete example raised: in a mail app, "inbox" and "compose" are obviously important, but the system has to infer that without the user explicitly saying so — one speaker suggested it may be simpler and more reliable to have the **user state their intent explicitly** rather than have the system try to infer importance on its own.
- A **screenshot alongside the DOM/accessibility tree** was discussed as a way to ground "important" in what's actually *visible* right now, since the accessibility tree can contain more than what's currently on-screen (e.g. off-screen or collapsed content).

**The AI-necessity debate — this is the part that matters most for [16-canvas-submission.md](16-canvas-submission.md):**
- One speaker (latency/cost concern) argued that if the system can just let the user browse the tree structure directly and select from it, an LLM might not be strictly necessary — especially given privacy and cost concerns with calling an LLM on every interaction.
- Another speaker countered that **complex trees genuinely need something** to cut them down — a real page can have many buttons/layers, and presenting that raw structure to a low-precision user is unusable without some simplification step.
- The resolution point floated: use AI **narrowly**, specifically for **mapping a complex tree down to a simpler one** (the "spanning tree" framing — take the full tree, produce a reduced/simplified version for the user to actually interact with), rather than using an LLM for every decision in the interaction loop. I.e. LLM-as-a-preprocessing/simplification step, not LLM-as-the-orchestrating-agent.

## Open tasks the meeting ended on (unassigned to real names — speaker numbers only)

1. Explore non-AI methods for simplifying UI tree structures, in case LLMs prove too complex/costly.
2. Investigate the actual feasibility and cost-effectiveness of using LLMs specifically for tree simplification, weighed against latency and privacy.
3. Determine the best method overall for identifying "important" UI features from DOM/accessibility trees.

## How this connects to the rest of the docs

This is the reasoning trail behind the shift already flagged in [16-canvas-submission.md](16-canvas-submission.md): the team isn't dropping AI entirely, but narrowing *where* it's used — from "an agent that interprets everything and executes actions" toward "AI (if used at all) does one narrow job: compress a complex tree into a simpler one," with the interaction loop itself potentially staying deterministic/rule-based. This is more specific than the canvas answer alone, and worth folding into whichever doc ends up being the reconciled architecture statement (see [16-canvas-submission.md](16-canvas-submission.md)'s open items list, item 1).

It's also directly relevant to the existing research in [docs/tech/research/03-proactive-narration.md](../tech/research/03-proactive-narration.md) (§2–3), which already proposed a similar "diff the tree, cheap pre-filter, then one narrow LLM call" pipeline — this meeting's "map complex tree to simpler tree via AI" framing is consistent with that research's recommendation, not a contradiction of it. Worth citing both together when this gets reconciled into the architecture doc.

**Caveat again: this is an unverified auto-transcript.** Speaker attributions are placeholders ("Speaker 1/2/3"), not real names, and the summary tool may have compressed or slightly misrepresented what was actually said. Confirm with whoever was in the room before treating any specific claim here as a locked decision.
