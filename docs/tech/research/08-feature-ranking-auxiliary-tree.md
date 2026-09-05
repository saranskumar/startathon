# 08. Research — Feature Ranking & the "Auxiliary Tree" (Non-AI-First Approach)

Research brief for the open question raised in [17-meeting-notes-tree-simplification.md](../../idea/17-meeting-notes-tree-simplification.md) and [18-meeting-notes-feature-ranking.md](../../idea/18-meeting-notes-feature-ranking.md): given a page's DOM/accessibility tree, how do you rank elements by importance to produce a simplified "auxiliary tree" **without** calling an LLM for every decision, per the "decided not to make this unnecessarily AI-powered or agentic" line in [16-canvas-submission.md](../../idea/16-canvas-submission.md). This is upstream of and distinct from [03-proactive-narration.md](03-proactive-narration.md), which already covers *narrating* a tree once you have one — this doc covers *building and ranking* the tree in the first place, plus detecting when to regenerate it on navigation.

---

## 1. Non-AI / heuristic content-importance ranking

**Verdict: Strong feasibility.** This is a mature, well-trodden problem — "find the important part of a page without ML" has ~15 years of production-grade prior art, and the core techniques translate directly to accessibility-tree ranking.

- **Mozilla Readability.js** (powers Firefox Reader View) uses a small set of hand-tuned heuristics, no ML, no LLM:
  - **Unlikely-candidate filtering**: elements whose `class`/`id` match a regex of known junk patterns (`sidebar`, `comment`, `ad-`, `footer`, `share`, etc.) are excluded early; a positive-pattern regex (`article`, `content`, `main`, `post`) gives a bonus.
  - **Content scoring per node**: base score by tag (`<p>`, `<pre>`, `<td>` score positively; `<form>`, `<li>`, `<td>` in nav contexts score negatively), incremented for comma count and text length, and the score is added to (not just kept at) the node's own score *and* propagated up to the grandparent, since the "real" content container is usually a wrapper a couple of levels up.
  - **Link density**: `linkTextLength / totalTextLength` per block — link-heavy blocks are demoted because they're almost always navigation/boilerplate, not content. This is the single most reusable signal for this project (a nav-heavy accessible-tree branch is nav, not "info").
  - Candidate with the highest propagated score becomes "the content"; a threshold-based retry loosens the rules if the strict pass returns too little.
  - Chromium's **DOM Distiller** (reader mode) is a descendant of the same lineage (**Boilerpipe**, see below) and does the equivalent job at browser-engine scale — proof this class of heuristic is production-grade, not academic-only.
- **Boilerpipe** (Kohlschütter et al., the classic academic/production content-extraction algorithm, also cited as feeding into Chrome's DOM Distiller) frames the problem as **binary classification per text block** (content vs. boilerplate) using **shallow, cheap features**: word count of the block and its immediate previous/next siblings, link density, average word length, and tag/text ratio. No semantic/NLP understanding — just structural/statistical features computed directly from the parse tree. This is the closest existing precedent to "score accessibility-tree nodes with structural features only," just applied to raw HTML blocks rather than accessibility-tree nodes.
- **CETR** (Content Extraction via Tag Ratios, Weninger et al.) computes a per-line/per-block **tag-to-text ratio** and clusters lines into "high density = content" vs. "low density = boilerplate" — another zero-ML, purely structural signal.
- **Trafilatura** (modern, widely-used Python extraction library) is explicitly heuristic/rule-based (a cascade of XPath queries, falling back to jusText/Readability-style heuristics if the primary pass fails) and is reported as competitive with or better than ML-based extractors like Boilerpipe/Dragnet in recent benchmarks — meaning heuristics-first is not just adequate but often still state-of-the-art for this kind of extraction, not a fallback compromise.
- **Screen readers themselves are the strongest existing precedent, and require zero ML**: ARIA landmark roles (`banner`, `navigation`, `main`, `complementary`, `contentinfo`, `search`, `form`) and heading levels (`h1`–`h6`) are a **standardized, already-computed importance signal** built into every accessible page — no scoring model needed at all, just reading role/level attributes already present in the accessibility tree. Per the **WebAIM Screen Reader User Survey**: headings are the dominant navigation method (~72% of respondents use them to navigate; 88.8% find heading levels "very" or "somewhat" useful), which is strong external validation that a heading/landmark-first ranking scheme matches how real screen-reader users already prioritize page content. Landmark usage is lower (~25–32% "always/often" use landmarks when present) but still a meaningful secondary signal, particularly useful for the "navigation vs. information" split raised in doc 18.

**Implication for this project:** a Readability/Boilerpipe-style scorer, re-targeted at accessibility-tree nodes instead of raw HTML text blocks, is a direct, low-risk, zero-LLM starting point — and it doubles as literally the same signal (landmarks/headings) that real screen-reader users already rely on, so it isn't an arbitrary heuristic invented for this project.

---

## 2. Salience/importance scoring specifically for accessibility trees

**Verdict: Moderate feasibility.** There is no off-the-shelf "accessibility-tree salience scorer" library or a settled academic subfield for this exact framing — but the adjacent research that does exist (web-agent accessibility-tree filtering) validates the same structural-signal approach, just built for a different consumer (LLM agents, not disabled end users).

- Content-extraction research (§1) is about raw HTML/text blocks, not accessibility-tree nodes specifically — nobody has published a dedicated "accessibility a11y-tree salience score" paper as far as this search found. This is a real gap, not something to overclaim.
- The closest real precedent is the **LLM web-agent tooling space**, which faces almost the identical sub-problem — "accessibility trees contain significant redundant information, requiring filtering ... based on the element's tag, visibility, usability, and textual or image content" — for a different reason (token budget, not human cognitive load), but using the same structural signals this project would need: role, visibility, interactivity, and text content. Microsoft's **Playwright MCP**, for example, already exposes accessibility-tree snapshots (role/name/children) as its state representation for browser agents, and research on "Impact of Element Ordering on LM Agent Performance" (arXiv:2409.12089) shows ordering/salience of tree nodes measurably affects downstream task success — indirect but real evidence that structural node-ranking of an accessibility tree is a legitimate, impactful lever, not a cosmetic detail.
- Deterministic, rule-based accessibility-tree simplification is already used in practice by some agent tooling: e.g. removing `StaticText` children whose text duplicates the parent's accessible name, filtering by visibility/tag/usability — this is exactly the shape of a zero-ML "tier 1" pass this project needs, just documented informally in agent-tooling blog posts/READMEs rather than a formal paper.
- Landmark/heading salience *has* a formal analogue in a completely different field — urban wayfinding research (Sorrows & Hirtle 1999; Raubal & Winter 2002) formally decomposes "landmark salience" into visual/semantic/**structural** salience, where structural salience is about a landmark's importance relative to its position in a network (e.g. intersection degree). It's not directly portable, but it's a reusable *framing*: "structural salience" (a node's position/role in the tree) as one scoring axis, separate from "semantic salience" (what it says) — which maps cleanly onto "score role/position without needing NLP" vs. "score meaning, which would need an LLM."
- Chrome DevTools itself validates role/heading-based filtering as a *recognized useful view* of an accessibility tree ("Show landmark nodes", "Show headings" filters have been considered/built for the full a11y tree inspector) — further evidence that role- and heading-based subsetting is considered a natural, structurally-sound simplification of an accessibility tree by browser engineers, independent of this project.

**Implication:** no one has built exactly this (accessibility-tree salience scoring for a limited-input human user), which is consistent with this being a legitimate novelty point for the pitch — but the component signals (role, landmark, heading level, visibility, interactivity, text length, position/DOM depth) are all individually well-precedented as importance signals in adjacent fields (content extraction, web agents, urban wayfinding). This is a synthesis opportunity, not a solved-problem-to-copy — same posture as doc 03's narration research.

---

## 3. Where a lightweight ML model (not a full LLM) could fit

**Verdict: Strong feasibility as a documented technique; Weak fit for a 30-hour hackathon build.**

- This is a well-trodden middle ground in the content-extraction literature specifically, which validates it as a real design point (not a hack):
  - **Boilerpipe** itself is explicitly framed as **binary classification** (content vs. boilerplate) using hand-crafted shallow text/structural features — it's typically run with simple linear/decision-tree classifiers, not deep learning. This is the closest analogue to "small classifier trained on structural features."
  - **Dragnet** explicitly combines Boilerpipe- and CETR-style block/text-density features with **word frequency of class/id attribute tokens**, trained as an ML model (originally the same shallow-feature philosophy, but learned weights instead of hand-tuned ones) — the paper trail (Kohlschütter et al. "Boilerplate Detection using Shallow Text Features", Weninger et al. "CETR") is a direct, citable precedent for "train a small classifier on structural features (tag, position, text length, density, is-interactive-equivalent) to predict importance."
  - Academic comparisons (e.g. SIGIR 2025 multilingual main-content-extractor benchmark, ACM's "Empirical Comparison of Web Content Extraction Algorithms") consistently find that classic ML approaches (Boilerpipe as the standout) are competitive with, and heuristic approaches (Trafilatura, Readability) are sometimes *better* than, more complex or LLM-based extraction for this task — meaning a lightweight classifier is a proven, non-toy technique but not obviously superior to well-tuned heuristics for this exact job.
  - Newer work explores small/lightweight *language* models (not full LLMs) for content extraction (e.g. "Dripper: Token-Efficient Main HTML Extraction with a Lightweight LM", arXiv:2511.23119) — confirms the "something between pure heuristics and a full LLM call" tier is an active, real research direction, not a stopgap.
- Where this would concretely fit for this project: a small classifier (logistic regression / gradient-boosted trees, trainable on maybe a few hundred hand-labeled accessibility-tree nodes from a handful of demo sites) taking features like `role`, `depth`, `is_landmark`, `heading_level`, `text_length`, `link_density_of_subtree`, `is_interactive` (button/link/input/etc.), `visible_area`/`is_in_viewport`, `sibling_count` — outputting an importance score. This is genuinely the textbook Boilerpipe/Dragnet pattern, just re-targeted at accessibility-tree nodes instead of HTML text blocks.
- **Why it's a weak fit for THIS 30-hour build specifically**: it needs a labeled training set (even a small one), a train/inference pipeline, and a model-serving story on the client — real setup cost for a timebox where hand-written heuristic weights (§5) can be authored directly and tuned by eyeballing demo-site output in far less time, with zero training-data risk. It's the right *next* investment after the hackathon (a natural "v2" once real usage data exists — every candidate/rejected node from tier-1 heuristics is a free labeled example), not a good use of hour 1–30.

---

## 4. New-page / major-state-change detection in SPAs

**Verdict: Strong feasibility.** This is a solved, well-documented engineering problem with mature production precedent (every web analytics SDK does this today).

- **History API interception** is the standard baseline: monkey-patch `history.pushState` and `history.replaceState` (most SPA routers call these on navigation) and listen for the native `popstate` event (fires only on browser back/forward, **not** on programmatic `pushState`/`replaceState` — a common gotcha). Analytics SDKs (Adobe's SPA guidance, Inspectlet, Microsoft's ApplicationInsights-JS SPA route-tracking PR, Clickport) all converge on this exact pattern: hook all three (`pushState`, `replaceState`, `popstate`) and de-duplicate/forward to one internal "route changed" event, since a router may trigger more than one of these per navigation.
- **URL polling** is the universally-cited fallback for routers that don't touch `history` at all (hash-based routers, or ones that mutate the DOM without any URL change) — a `setInterval` comparing `location.href` is crude but catches everything the History API hook misses; production guidance explicitly warns against relying on History API interception alone for this reason.
- **MutationObserver as a supplementary signal**, specifically for the "how do we know this is a full page swap, not a small update" question this project's meeting notes raise directly (doc 18's "unknown elements... may still need to trigger a fresh tree-generation" case): observe a stable root container (e.g. the app's root div) with `childList: true, subtree: true`, and apply a **heuristic threshold** on the batch of mutations — e.g. "a large fraction of direct children of the main/root landmark were replaced," "the accessible name of the document's `<title>`/`h1`/`main` landmark changed," or simply "more than N nodes were added/removed within one microtask batch." No source found a standardized percentage threshold for this (it's treated as an app-specific tuning knob in practice, not a documented constant) — this is a genuine open engineering parameter this project would have to tune itself, not something to cite as "the" answer.
- Practical combined pattern used by production SPA-tracking tools: **URL/History hook as the primary trigger** (cheap, precise, catches the overwhelming majority of real navigations) **+ MutationObserver as a fallback/corroboration signal** (catches router-less state changes, and can help distinguish "this pushState was a real page change" from "this pushState was a minor query-param update" by checking whether the DOM actually changed substantially afterward). This maps directly onto doc 18's "new page trigger" concept: certain elements (nav links, tab switches) are known triggers wired to explicit listeners; anything else falls through to the URL+DOM-delta heuristic as a catch-all, with the truly ambiguous residue being the "unknown elements" case the meeting flagged.
- For the **"unknown elements"** case specifically (an element that isn't clearly a nav link or clearly inert): the pragmatic, zero-LLM answer is to treat "did the URL change OR did >X% of the current auxiliary tree's tracked nodes disappear/get replaced after this interaction" as the trigger condition, regardless of what the element *was* — i.e. don't try to classify the *element* at all, just watch the *effect* (URL + DOM delta) after any interaction. This sidesteps the classification problem doc 18 flags as unresolved by moving the decision point from "was this a nav-triggering element" (hard, needs classification) to "did navigation-shaped things happen after this click" (easy, purely observational).

---

## 5. Concrete recommendation: layered approach for the 30-hour build

**Tier 1 — pure heuristics, no AI, build this first (targets: works today, ships in the demo).**

Ranking formula per accessibility-tree node, roughly:

```
score(node) =
    3.0  if role in {banner, navigation, main, search, form, complementary, contentinfo}   # ARIA landmark
  + 2.5 - (0.3 * heading_level)   if role == "heading"     # h1=2.2 ... h6=0.7
  + 2.0  if is_interactive (button, link, textbox, checkbox, radio, combobox, menuitem...)
  + 1.0  if node has a non-empty accessible name AND accessible name is not duplicated in an ancestor's name
  + min(text_length / 40, 1.5)                              # longer accessible text, capped
  - 2.0 * link_density_of_subtree                           # Boilerpipe/Readability signal, ported directly
  - 1.5  if node is hidden / zero-size / not in viewport
  - 1.0  if node's role in {presentation, none, generic} with no accessible name
  + 0.5 * clamp(3 - depth_from_landmark_ancestor, 0, 3)     # closer to a landmark root scores slightly higher
```

Then split into the two buckets doc 18 already proposed:
- **Navigation set** = interactive nodes inside `navigation`/`banner` landmarks, or top-scoring links/buttons anywhere, sorted by score descending → Rank 1, 2, 3...
- **Information set** = headings + high-scoring static text/landmark content, sorted the same way.
- **Scroll** handled outside this pipeline entirely, per doc 18's note, cross-referenced to [03-input-calibration.md](../../idea/03-input-calibration.md) §3.2's continuous/directional task shape — don't try to represent it as a ranked tree node.

This alone (landmarks + headings + link-density + interactivity + visibility) reuses exactly the signal real screen-reader users already rely on (§1's WebAIM data) and the exact feature set Boilerpipe/Readability use (§1) — defensible, explainable, and zero marginal cost per page.

**Tier 2 — fall back to one LLM call only when tier 1's output is ambiguous.** Concrete trigger conditions for "ambiguous" (keep these cheap/structural, not another AI call to *decide* to call AI):
- No ARIA landmarks present anywhere on the page (a real, common case on messy/legacy sites) **and** no heading elements either — tier 1 has no strong signal to anchor on.
- Top-N scored candidates are within a small score delta of each other (e.g. top 8 candidates all within 0.5 points) — i.e. tier 1 produced a "flat" ranking with no clear winner, so a coarse heuristic ordering would look arbitrary to the user.
- The "unknown element" case from doc 18: an interacted-with element that is not classifiable as clearly navigation or clearly info by role/heuristic alone (e.g. a `div` with `onclick` and no ARIA role, no accessible name pattern match) — this is exactly the case the meeting flagged as possibly needing a fresh tree-generation call; a single scoped LLM call ("here's this ambiguous node and its immediate context, classify it as navigation/info/ignore") is appropriately narrow, matching the "spanning tree" / "AI narrowly for tree simplification, not the interaction loop" resolution from doc 17.

This is the same "cheap pre-filter, then one narrow LLM call only when needed" shape doc 03 already recommends for narration (§2 of that doc) — using the same pattern for ranking keeps the two research threads architecturally consistent, per doc 17's cross-reference note.

**New-page detection (feeds both tiers):** wire `pushState`/`replaceState`/`popstate` interception as the primary trigger (cheap, standard, matches production analytics-SDK practice per §4) with a `MutationObserver` on the root landmark as a fallback/corroboration signal using a simple threshold (e.g. >50% of previously-tracked node IDs no longer present, or the `main`/`h1` accessible name changed) to decide "regenerate the auxiliary tree now." Don't attempt to classify the *triggering element*; watch the *post-interaction effect* instead (§4's closing point) — this avoids needing any classifier or LLM call just to decide whether a click was "a navigation click."

**Honest risk:** tier-1 weights above are starting points, not validated constants — they need to be hand-tuned against the actual demo site(s) in the first few build hours, the same way Readability's own thresholds are hand-tuned rather than derived. State this openly rather than presenting the formula as empirically proven.

---

## Summary of verdicts

| Area | Verdict |
|---|---|
| 1. Non-AI heuristic content-importance ranking | **Strong** |
| 2. Salience scoring specifically for accessibility trees | **Moderate** |
| 3. Lightweight ML classifier as a middle tier | **Strong as a technique / Weak fit for this timebox** |
| 4. SPA new-page / major-state-change detection | **Strong** |
| 5. Layered recommendation (heuristics tier 1 + narrow LLM tier 2) | **Strong feasibility for a 30-hour build** |

---

## Sources

1. [Mozilla Readability Algorithm (Readability.js) explanation — WebcrawlerAPI Blog](https://webcrawlerapi.com/blog/mozilla-readability-algorithm-readabilityjs)
2. [Comparing algorithms for extracting content from web pages — Chuniversiteit](https://chuniversiteit.nl/papers/comparison-of-web-content-extraction-algorithms)
3. [Readability and the Web — MDPI](https://www.mdpi.com/1999-5903/4/1/238)
4. [SpeedReader: Reader Mode Made Fast and Private — arXiv:1811.03661](https://arxiv.org/pdf/1811.03661)
5. [An overview of web page content extraction — Joy Bose, Medium](https://joyboseroy.medium.com/an-overview-of-web-page-content-extraction-5e0e2c62855d)
6. [Boilerplate Removal using a Neural Sequence Labeling Model — arXiv:2004.14294](https://arxiv.org/pdf/2004.14294)
7. [Improving the Boilerpipe Algorithm for Boilerplate Removal in News Articles Using HTML Tree Structure — ResearchGate](https://www.researchgate.net/publication/326167148_Improving_the_Boilerpipe_Algorithm_for_Boilerplate_Removal_in_News_Articles_Using_HTML_Tree_Structure)
8. [dragnet-org/dragnet — GitHub](https://github.com/dragnet-org/dragnet)
9. [Web2Text: Deep Structured Boilerplate Removal — arXiv:1801.02607](https://arxiv.org/pdf/1801.02607)
10. [The Impact of Main Content Extraction on Near-Duplicate Detection — arXiv:2111.10864](https://arxiv.org/pdf/2111.10864)
11. [Multilingual Benchmarking of Main Content Extractors — SIGIR 2025 paper](https://maurelf.users.greyc.fr/docs/conferences/SIGIR_2025_paper_1968.pdf)
12. [An Empirical Comparison of Web Content Extraction Algorithms — ACM](https://dl.acm.org/doi/pdf/10.1145/3539618.3591920)
13. [Dripper: Token-Efficient Main HTML Extraction with a Lightweight LM — arXiv:2511.23119](https://arxiv.org/pdf/2511.23119)
14. [A Machine Learning Approach to Webpage Content Extraction — Yao & Zuo, CS229 Stanford](https://cs229.stanford.edu/proj2013/YaoZuo-AMachineLearningApproachToWebpageContentExtraction.pdf)
15. [Web Content Extraction Through Machine Learning — Zhou & Mashuq, CS229 Stanford](https://cs229.stanford.edu/proj2013/ZhouMashuq-WebContentExtractionThroughMachineLearning.pdf)
16. [Learning Web Content Extraction with DOM Features — ResearchGate](https://www.researchgate.net/publication/329061153_Learning_Web_Content_Extraction_with_DOM_Features)
17. [10 SEO use cases for auditing your accessibility tree for AI search — Search Engine Land](https://searchengineland.com/accessibility-tree-seo-use-cases-484338)
18. [The accessibility tree: understanding and debugging — Sophie Beaumont, Medium](https://sbeaumontweb.medium.com/the-accessibility-tree-understanding-and-debugging-fab9df75a1d0)
19. [Full accessibility tree in Chrome DevTools — Chrome for Developers Blog](https://developer.chrome.com/blog/full-accessibility-tree/)
20. [Structural Landmark Salience Computation in Compact Urban Districts — MDPI](https://www.mdpi.com/2075-5309/13/4/1024)
21. [WebAIM: Screen Reader User Survey #10 Results](https://webaim.org/projects/screenreadersurvey10/)
22. [WebAIM: Screen Reader User Survey #9 Results](https://webaim.org/projects/screenreadersurvey9/)
23. [Key Findings From the WebAIM 2024 Screen Reader User Survey — Medium](https://medium.com/design-domination/key-findings-from-the-webaim-2024-screen-reader-user-survey-bb15864d3bc8)
24. [Building Browser Agents: Architecture, Security, and Practical Solutions — arXiv:2511.19477](https://arxiv.org/html/2511.19477v1)
25. [The Impact of Element Ordering on LM Agent Performance — arXiv:2409.12089](https://arxiv.org/pdf/2409.12089)
26. [Accessibility Tree and AI Agents - How to Optimize Yours — Webyes](https://www.webyes.com/blogs/accessibility-tree-ai-agents/)
27. [LUMOS: A Semantic Operating-System Layer for Accessibility-Grounded AI Agents — arXiv:2606.30697](https://arxiv.org/pdf/2606.30697)
28. [Data layers and SPAs: Page view and event patterns — Adobe Experience League](https://experienceleague.adobe.com/en/perspectives/data-layers-and-spas-page-view-and-event-patterns)
29. [Virtual Page Views: Setting Up SPA Tracking — Inspectlet](https://www.inspectlet.com/guides/virtual-page-views)
30. [SPA Tracking — Clickport Analytics Docs](https://clickport.io/docs/spa-tracking)
31. [Feature: add SPA auto route change tracking — microsoft/ApplicationInsights-JS PR #947](https://github.com/microsoft/ApplicationInsights-JS/pull/947/files/a0f431d126ca1463ea99a1cc81143b9d149972d9)
32. [Window: popstate event — MDN](https://developer.mozilla.org/docs/Web/Events/popstate)
33. [Detect, Undo And Redo DOM Changes With Mutation Observers — Addy Osmani](https://addyosmani.com/blog/mutation-observers/)
34. [Detect DOM changes with mutation observers — Chrome for Developers Blog](https://developer.chrome.com/blog/detect-dom-changes-with-mutation-observers)
35. [Master DOM Tracking with MutationObserver: Complete Guide — jsdev.space](https://jsdev.space/mutation-observer-dom-tracking-guide/)
