# 04 — Agent Execution Layer: Accessibility-Tree-Driven Browser Action

Research thread: does the "AI Agent" box in [idea/07-architecture.md](../../idea/07-architecture.md) need a
general-purpose agent framework (OpenClaw or similar), or can/should the accessibility-tree click/fill/select
loop be purpose-built? Scoped to the locked demo task in [idea/05-scope.md](../../idea/05-scope.md): fill +
submit one real Google Form (plus the self-built Aperture mock UI) via a Playwright-controlled Chromium
instance, with confirmation-before-consequential-action and interrupt/cancel as hard constraints
([idea/11-risks.md](../../idea/11-risks.md), scope item 6).

---

## 1. Comparison of narrowly-scoped browser-automation-plus-LLM frameworks

The relevant design point is **not** "computer-use agent with shell/filesystem/OS access" — it's "LLM reads
a structured tree of the current page, picks a node, dispatches one Playwright action, and stops." Four
real options exist at that scope:

| Option | Accessibility-tree (not pixel) targeting | Maturity / maintenance (Sep 2026) | Integration effort for a 30h build |
|---|---|---|---|
| **Playwright accessibility snapshot + custom LLM loop** (build it yourself) | Yes — native. `page.accessibility.snapshot()` / ARIA snapshot (`toMatchAriaSnapshot`, and the same mechanism Playwright MCP's `browser_snapshot` exposes) gives role/name/value/children as YAML-like text, built for exactly this purpose. | Playwright itself is extremely mature (Microsoft-maintained, used as the underlying driver by nearly every tool below). The *loop* is code you own, not a dependency. | **Lowest** — a few hundred lines: snapshot → prompt LLM with tool-calling schema (click/fill/selectOption + node ref) → dispatch → confirm → re-snapshot. No framework abstractions to learn or fight. |
| **browser-use** (Python, open source) | Yes — explicitly builds a compact accessibility tree with stable element refs (e.g. `@e1`) specifically so the LLM can target semantically rather than by pixel/CSS. Runs on Playwright underneath. | Very actively maintained: ~101–106k GitHub stars, releases roughly every 4 days as of mid-2026. AGPL-3.0 license (worth checking for a hackathon demo, though low-stakes). | **Low-moderate** — pip install + task string gets you 80% of the way, but its default agent loop is designed for autonomous multi-step task completion, not "propose one action, wait for a human OK." Confirmation/interrupt gating has to be bolted on by intercepting its action-execution hook or running it action-by-action instead of letting it self-loop. |
| **Stagehand** (Browserbase, TS/Python) | Yes — this is its core pitch: "hybrid accessibility tree trimming" via the Chrome Accessibility Tree, cutting ~80-90% of raw-DOM noise before it reaches the LLM. Exposes atomic primitives `act`/`observe`/`extract` (single-step, inspectable) plus a higher-level autonomous `Agent`. | Actively maintained — v3/v4 released 2026, ~135k weekly npm downloads, backed by a funded company (Browserbase). Requires either a Browserbase-hosted browser or local Playwright/CDP session (v3 dropped the raw Playwright dependency layer but can still drive a local Chromium). | **Low** — the atomic `observe()` (returns candidate actionable elements with tree context) + `act()` (executes one, single step) pattern maps almost exactly onto "confirm before executing": call `observe`, show the candidate action to the user/LLM-confirmation step, then `act` only that one item. Best fit of the off-the-shelf options for this project's confirmation-gating requirement. |
| **Anthropic's "Computer Use" tool** | No — pixel/screenshot + coordinate-based by design (drives a whole virtual desktop). Anthropic's separate **"Browser Use" tool** (distinct from the browser-use OSS library) *does* read the accessibility tree with `[ref_N]`-tagged elements for click/type — closer to what's needed, but it's a hosted Claude API tool, not a standalone library, and pulls in the same broad "the model controls a browser session end-to-end" framing the project is trying to avoid re: OpenClaw's broad capability surface. | Mature, Anthropic-maintained, but scoped to their Messages API tool-use loop rather than a droppable library. | **Moderate** — usable, but couples the whole execution loop to Anthropic's specific tool-use protocol and hosted browser session model, less control over confirmation-gate insertion than a self-built loop. |
| **Playwright MCP (Microsoft)** | Yes — `browser_snapshot` is exactly an accessibility-tree serialization, designed for exactly this LLM-drives-browser purpose, and is the same primitive Claude Code/Cursor/Codex use in 2026. | Actively maintained, Microsoft first-party. | **Low-moderate** — but it's built as an MCP server for a *chat client* to call tools against, not as an embeddable library with a natural "wait for confirmation mid-action" hook. Usable but adds an MCP-protocol hop the custom loop doesn't need. |

**Verdict: Strong feasibility.** Multiple accessibility-tree-native options exist and are all viable within
30 hours; none require pixel-based grounding at all for this task.

---

## 2. Is a general-purpose agent framework (OpenClaw) actually necessary?

**No — a custom thin loop is the better fit, and is simpler, safer, and equally buildable in 30 hours.**

Reasoning:

- **Capability-surface mismatch.** OpenClaw-class frameworks are built to give an LLM shell access, filesystem
  access, and arbitrary integrations, because their target use case is "autonomous agent that does anything
  on your computer." This project needs exactly one thing: read a page's accessibility tree, dispatch one of
  three Playwright action types (click/fill/selectOption), on one browser instance the team already controls.
  Every other capability OpenClaw ships is unused attack surface, not unused convenience — see §11-risks.md's
  own flag that "Agent/automation layer (OpenClaw or equivalent) unstable under time pressure" and the prior
  research thread's finding that OpenClaw has multiple 2025-2026 papers specifically on its security/privacy
  risk profile (arXiv 2605.23330 "Security, Privacy, and Ethical Risks in OpenClaw"; arXiv 2603.19974
  "Trojan's Whisper," on prompt-injection against OpenClaw specifically; real CVE-2025-49596 / CVE-2025-6514,
  CVSS 9.4/9.6, from unauthenticated gateway exposure — i.e., these are not theoretical, they are exploited
  in the wild against its default broad capability surface).
- **Confirmation-gating is architecturally easier in a custom loop.** Scope item 6 requires the agent to
  confirm before every consequential action and support interrupt/cancel. A general framework's default loop
  is built to *not* stop — you'd be fighting the framework's autonomy-by-default design to insert a hard stop
  before every action, exactly where a bug or prompt-injected page content could cause it to skip the gate.
  A custom loop makes "dispatch nothing until the human/UI approves this one proposed action" the *only* path
  through the code — there's no autonomous fallback to accidentally hit.
  For the demo, this is stronger than what browser-use or Stagehand's autonomous `Agent` give you out of the
  box (both are safe to use, but only if you deliberately use their single-step primitives, `act()`/`observe()`
  for Stagehand or manual step-through for browser-use, rather than their default "run until done" mode).
- **Effort is comparable, control is higher.** The custom loop is roughly: (a) call
  `page.accessibility.snapshot()` or an ARIA snapshot, (b) serialize the relevant subtree to text, (c) one
  LLM call with a tool schema restricted to `{click, fill, selectOption} × {node_ref, value?}`, (d) show the
  proposed action to the user for confirm/cancel, (e) on confirm, dispatch via Playwright, (f) loop. This is
  a small, auditable amount of code (roughly 150-300 lines), directly matches the architecture diagram's
  wording ("reading each page's accessibility tree... dispatching actions... on the node the LLM matches"),
  and avoids taking on a dependency whose maintainers are optimizing for a different (broader, riskier) use
  case than this project needs.
- **Where a library still earns its place:** Stagehand's `observe()`/`act()` pair is worth adopting *as a
  utility inside the custom loop* — it saves reimplementing accessibility-tree-to-candidate-actions parsing —
  without adopting Stagehand's autonomous `Agent` or any shell/filesystem capability. This is "use the narrow
  library as a building block," not "use it as the orchestrator."

**Verdict: Strong feasibility for the custom-loop recommendation.** Recommend dropping OpenClaw (or any
general computer-use framework) entirely for this component and building the thin loop, optionally with
Stagehand's `observe`/`act` primitives as an accessibility-tree-parsing utility.

---

## 3. Confirmation-gating and interrupt design patterns

Existing primitives exist and transfer well, though most are framework-specific to LangGraph rather than
being a standalone library:

- **LangGraph `interrupt()`** is the most concrete existing pattern: a graph node calls `interrupt(payload)`,
  execution pauses and persists state (via LangGraph's checkpointer), the payload (e.g. "about to click
  Submit on the Google Form — confirm?") is surfaced to a human, and the graph resumes from that exact point
  once a `Command(resume=...)` is sent back in. This directly matches "AI proposes an action, waits for human
  confirmation before executing" and additionally survives process restarts, which is more durability than
  this hackathon demo needs but is a clean pattern to imitate even without adopting LangGraph itself.
- **The core idea to borrow, framework or not:** separate "decide the action" from "execute the action" into
  two distinct steps with a suspend point between them, and make the suspend point a real `await`/blocking
  point in code (not a flag the loop might race past). For interrupt/cancel specifically, the same shape
  works: keep the LLM's proposed-but-unexecuted action in a variable, and let a cancel signal (e.g. a
  cancelled Promise / an abort flag checked between steps) short-circuit before the Playwright dispatch call
  ever fires. Playwright actions themselves are also natively interruptible mid-flight via
  `page.close()`/context abort or an `AbortController`-driven timeout, which covers the case where a click
  is already in-flight when the user cancels.
- **Whether to adopt LangGraph itself for a 30-hour build:** optional, not necessary. LangGraph's interrupt
  pattern is valuable to imitate structurally (propose → pause → confirm → resume/cancel), but bringing in
  the full LangGraph dependency (state graphs, checkpointers) for a single linear confirm-then-act loop is
  more machinery than the task needs. A plain async function with an `await confirmFromUI(proposedAction)`
  call before every Playwright dispatch achieves the same guarantee with far less surface area.

**Verdict: Strong feasibility.** The pattern is well-documented (LangGraph docs, multiple 2026 tutorials) and
straightforward to reimplement directly without the dependency.

---

## 4. Accuracy/reliability: accessibility-tree vs. pixel-based targeting

Direct head-to-head benchmark numbers (same benchmark, same model, tree vs. screenshot, isolating only the
grounding method) are not cleanly published — most agent benchmarks report one modality per paper rather
than controlled A/B numbers. What the literature does show, converging from several angles:

- **WebArena and Mind2Web — the two standard web-agent benchmarks — both use the accessibility tree as their
  primary observation modality**, not screenshots, specifically because it's a more tractable and reliable
  representation for grounding actions to concrete elements. Mind2Web's own analysis found that filtering
  raw HTML into an accessibility-tree-like representation *improves* LLM task performance versus raw HTML or
  vision alone.
- **DOM/accessibility-tree pruning work (Prune4Web, 2025) reports 88.28% grounding accuracy** using a
  programmatic element filter + accessibility-tree-based action grounder (given correct sub-task decomposition)
  — versus **46.8%** for an unpruned baseline on the same setup. That's a large, concrete accuracy delta
  attributable specifically to structured/tree-based grounding over noisier raw representations.
  For comparison, a strong pure-vision/screenshot grounding model (ShowUI, 2B params) reports **75.1%
  zero-shot accuracy** on its own screenshot-grounding benchmark — a different benchmark, so not a strict
  apples-to-apples number, but consistent with the general finding that trees ground more reliably than
  pixels when a tree is available.
- **Caveat found in the security literature (RedTeamCUA, arXiv 2505.21936):** accessibility-tree-based
  targeting is not universally superior — it substantially reduces attack success rate from adversarial page
  content (good for this project, since it reduces the chance of a malicious/confusing Google Form element
  causing a wrong click), but the same line of research notes trees "do not consistently improve benign task
  performance" versus screenshots and are error-prone when a site's markup poorly reflects its visual
  structure (e.g. divs styled to look like buttons with no ARIA role). For a self-built mock UI (Aperture)
  and a Google Form — both well-structured, standard-forms-library markup — this failure mode is low-risk;
  it would be a bigger concern automating an arbitrary third-party site.
- **Token/latency side benefit:** Stagehand's accessibility-tree trimming reports 80-90% size reduction vs.
  raw DOM, and Playwright-MCP-style delta snapshots report up to 94% token reduction on repeated page reads
  — relevant for a 30-hour build because it keeps per-action LLM latency low enough for a live demo.

**Verdict: Moderate-to-Strong feasibility**, with the caveat that the specific "accessibility tree is X% more
accurate than pixels" number does not exist as a single controlled study — but every adjacent data point
(benchmark design choices, pruning-accuracy numbers, adversarial-robustness findings) points the same
direction, and the demo's two target surfaces (self-built mock UI + Google Form) are exactly the
well-structured-markup case where tree-based targeting is strongest and least likely to hit the known failure
mode (poor ARIA semantics on custom-styled elements).

---

## 5. Concrete recommendation for the 30-hour build

**Stack: Playwright (Node or Python) driving a dedicated Chromium instance, with a hand-written thin
loop — no general agent framework, no OpenClaw.**

1. **Snapshot:** `page.accessibility.snapshot()` (or Playwright's ARIA-snapshot / `toMatchAriaSnapshot`
   machinery, same primitive Playwright MCP's `browser_snapshot` uses) after every page-state change, to get
   role/name/value/children as structured text.
2. **Match:** one LLM tool-call per step, with a tool schema constrained to exactly the three actions the
   architecture doc specifies — `click(node_ref)`, `fill(node_ref, value)`, `selectOption(node_ref, value)` —
   fed the accessibility snapshot plus the fused touch+voice intent from the phone client. Optionally use
   Stagehand's `observe()` as a pre-filtering utility to shrink the candidate-node list before the match call,
   since its accessibility-tree trimming is a solved, well-tested piece of exactly this problem.
3. **Confirm:** before dispatch, surface the proposed action (in plain terms — "About to click Submit") to
   the confirmation UI/voice-narration path and block on an explicit yes, modeled on LangGraph's
   propose→pause→resume `interrupt()` shape but implemented as a plain awaited promise, not the LangGraph
   dependency itself.
4. **Dispatch:** on confirm, execute via Playwright's normal `locator.click()/.fill()/.selectOption()` against
   the same node the snapshot referenced (Playwright element handles/refs stay valid across the snapshot →
   confirm → dispatch window as long as the page hasn't re-rendered that node).
5. **Interrupt/cancel:** a single cancellation flag/AbortController checked immediately before step 4's
   dispatch call, plus reliance on Playwright's own action timeouts/abort for anything already mid-flight.

This is the lowest-risk path because: it has the fewest moving dependencies (Playwright is already the
locked choice per `docs/tech/README.md`), it makes the confirmation gate structurally unbypassable rather
than a convention layered on top of an autonomous framework, it avoids importing OpenClaw's broad
shell/filesystem/integration capability surface (and its documented CVEs / prompt-injection papers) for a
task that needs none of it, and both demo surfaces (Aperture mock UI, Google Form) are well-structured markup
where accessibility-tree targeting is empirically strongest.

**Verdict: Strong feasibility.**

---

## Summary of viability verdicts

| Area | Verdict |
|---|---|
| 1. Narrow framework comparison | Strong — multiple accessibility-tree-native, actively maintained options (Playwright native snapshot, browser-use, Stagehand) all fit a 30h build |
| 2. General framework (OpenClaw) necessity | Strong (for the "not necessary, build thin loop" recommendation) |
| 3. Confirmation-gating/interrupt patterns | Strong — LangGraph's `interrupt()` shape is a clean, reimplementable pattern without the dependency |
| 4. Tree vs. pixel accuracy data | Moderate-to-Strong — no single controlled study, but consistent converging evidence favors tree-based targeting for well-structured markup |
| 5. Concrete 30h recommendation | Strong — Playwright accessibility snapshot + custom LLM tool-call loop + confirm-then-dispatch |

---

## Sources

- [Playwright ARIA Snapshot Testing: The Complete 2026 Guide](https://qaskills.sh/blog/playwright-aria-snapshot-testing-guide)
- [Playwright: From Test Runner to AI Agent Interface](https://isagentready.com/en/blog/playwright-from-test-runner-to-ai-agent-interface)
- [What's New in Playwright 2026: AI Agents, MCP, and Accessibility-First Testing](https://qaskills.sh/blog/whats-new-playwright-2026)
- [Playwright MCP Accessibility Snapshots: Complete Reference 2026](https://qaskills.sh/blog/playwright-mcp-accessibility-snapshots-reference)
- [browser-use/browser-use — GitHub](https://github.com/browser-use/browser-use)
- [AI Browser Automation Tools for the LLM Agent Era (2026) — comparison gist](https://gist.github.com/kevinmichaelchen/9d77b8a681238cc45297dff969686175)
- [Stagehand: the AI web agent SDK — Browserbase](https://www.browserbase.com/blog/ai-web-agent-sdk)
- [Stagehand v3: Faster AI Automation, No Playwright — Browserbase](https://www.browserbase.com/blog/stagehand-v3)
- [browserbase/stagehand — GitHub](https://github.com/browserbase/stagehand)
- [@browserbasehq/stagehand — npm](https://www.npmjs.com/package/@browserbasehq/stagehand)
- [Stagehand AI Browser Automation: The Complete 2026 Guide](https://qaskills.sh/blog/stagehand-ai-browser-automation-guide-2026)
- [Browser Use Is a New Claude Tool, Not a Renamed One](https://www.digitalapplied.com/blog/anthropic-browser-use-tool-ga-new-agent-toolset)
- [Anthropic's Computer Use versus OpenAI's Computer Using Agent (CUA) — WorkOS](https://workos.com/blog/anthropics-computer-use-versus-openais-computer-using-agent-cua)
- [RedTeamCUA: Realistic Adversarial Testing of Computer-Use Agents in Hybrid Web-OS Environments (arXiv 2505.21936)](https://arxiv.org/pdf/2505.21936)
- [Prune4Web: DOM Tree Pruning Programming for Web Agent (arXiv 2511.21398)](https://arxiv.org/pdf/2511.21398)
- [Mind2Web — GitHub](https://github.com/OSU-NLP-Group/Mind2Web)
- [SeeAct / Mind2Web project page](https://osu-nlp-group.github.io/SeeAct/)
- [Accessibility tree vs screenshot desktop automation: it is a router, not a binary choice](https://t8r.tech/alternative/compare/accessibility-tree-vs-screenshot-automation)
- [LangGraph's interrupt() Function: The Simpler Way to Build Human-in-the-Loop Agents](https://medium.com/@areebahmed575/langgraphs-interrupt-function-the-simpler-way-to-build-human-in-the-loop-agents-faef98891a92)
- [Making it easier to build human-in-the-loop agents with interrupt — LangChain blog](https://www.langchain.com/blog/making-it-easier-to-build-human-in-the-loop-agents-with-interrupt)
- [Interrupts — LangGraph docs](https://docs.langchain.com/oss/python/langgraph/interrupts)
- [Security, Privacy, and Ethical Risks in OpenClaw (arXiv 2605.23330)](https://arxiv.org/abs/2605.23330)
- [Trojan's Whisper: Stealthy Manipulation of OpenClaw through Injected Bootstrapped Guidance (arXiv 2603.19974)](https://arxiv.org/pdf/2603.19974)
- [Uncovering Security Threats and Architecting Defenses in Autonomous Agents: A Case Study of OpenClaw (arXiv 2603.12644)](https://arxiv.org/html/2603.12644v1)
