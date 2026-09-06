# Desktop backend

The agent-controlled-browser side of the architecture ([idea/07-architecture.md](../../docs/idea/07-architecture.md)'s
"AI AGENT" box) — runs on the desktop machine, not the phone. Build-order step (1) in
[docs/tech/README.md](../../docs/tech/README.md); see
[docs/tech/research/04-agent-execution-layer.md](../../docs/tech/research/04-agent-execution-layer.md)
for the design rationale (Playwright accessibility snapshot, no general agent framework).

Three pieces, one shared session:

| File | What it is |
|---|---|
| `src/domTreeEngine.js` | The ranking engine. Pure, synchronous, no Playwright/network/LLM. |
| `src/groupFeatures.js` | Hierarchical packing when a bucket overflows `limit` (structural then spatial groups). |
| `src/browserSession.js` | One Playwright browser wrapped as `goto` / `scan` / `act` / `screenshot` / events. |
| `src/dasherModel.js` | The zooming navigator: probability-sized nested regions steered by one slider. |
| `src/server.js` + `src/ui/` | The desktop inspector: a local HTTP+SSE server and the page that shows everything. |

`src/auxCli.js` is the same session printed to a terminal, and `src/snapshot.js` is the original
raw-tree dump kept for when only the unranked YAML tree is wanted.

## Setup

```bash
npm install
npx playwright install chromium
```

## The desktop inspector

```bash
npm run ui                             # inspects code/mock/index.html
npm run ui -- https://example.com
npm run ui -- --port 7788 --headless
```

Opens `http://localhost:7777` with three panes, all driven off one scan:

- **Page** — a live screenshot of the controlled browser, with every ranked feature drawn as a
  numbered box on top of it, plus the event log explaining *why* the tree last regenerated.
- **Accessibility tree** — the whole tree as the engine sees it: role, name, score, `[ref=eN]`, and
  for every node the engine dropped, the reason it dropped it (`pruned: repeats a control's label`).
  Filter by role or name; tick **show pruned** to see what was thrown away.
- **Auxiliary tree** — the two ranked buckets. Clicking a score expands the exact list of terms that
  produced it; the button on the right dispatches the real Playwright action.

Hovering anything highlights the same node in all three panes. A second, separate Chromium window is
the page actually being driven — interact with it directly and the inspector follows.

**List / Slider** switches the middle pane between the accessibility tree and the zooming navigator
below.

## The DOM tree engine

`src/domTreeEngine.js` decides *which* features are worth showing, per the ranking plan in
[docs/tech/research/08-feature-ranking-auxiliary-tree.md](../../docs/tech/research/08-feature-ranking-auxiliary-tree.md)
and the navigation/information split from
[docs/idea/18-meeting-notes-feature-ranking.md](../../docs/idea/18-meeting-notes-feature-ranking.md).
No LLM in this path — it is a hand-tuned heuristic score per node (ARIA landmark, heading level,
interactivity, accessible-name presence, text length, link density, visibility, distance from the
nearest landmark), the same signal set real screen readers and Readability/Boilerpipe-style content
extractors already use. `src/usageStore.js` adds one more: a persisted per-feature selection count
(`data/usage-counts.json`, gitignored), so a feature picked often before ranks higher next time — a
plain frequency count standing in for "an ML model, not an LLM" without needing training data.

It returns four things, not just a ranked list:

- `navigation` / `information` — the two buckets, each feature carrying `parts`, the exact score
  terms that produced its total, so no number in the UI is unexplained.
- `tree` — the same nodes kept as a hierarchy, each with `kept` and `prunedBecause`.
- `ambiguity` — tier 1's own assessment of whether it is out of its depth (see below).
- `stats` — nodes in, nodes kept, nodes pruned, and the counts per category.

Each feature also carries `label` (a short display string — a card-shaped button's accessible name is
routinely a whole paragraph), `taskShape` (`discrete` / `continuous` / `pointing` / `text`, matching
the phone app's `TaskShape` in `code/app/lib/runtime/task_spec.dart`) and `action` (`click` / `fill`
/ `check` / `select` / `set`) — so a feature arrives at the phone already knowing which input pattern
renders it and which Playwright call executes it.

```bash
npm run aux                          # loads code/mock/index.html
npm run aux -- https://example.com
npm run aux -- --once
npm run aux -- --json                # one machine-readable scan, then exit
npm test                             # the ranking regression suite
```

### Where doc 08's formula was corrected

The tier-1 formula is doc 08 §5's, with the following changes — all found by running it against the
mock UI, its form, and a real Wikipedia article, which is exactly the hand-tuning doc 08 says the
weights need ("starting points, not validated constants"):

- **Link density is inherited from the container, not computed on the node.** A link's own density is
  1.0 by definition, so applying the penalty to the link itself was a flat −2.0 on every link on the
  page. Readability's actual signal is about *blocks*: a container with real text sets the density,
  and its descendants inherit it. A link in a sidebar blob is now demoted; the same link inside prose
  is not. On Wikipedia this alone replaced a Navigation bucket of twelve article-body links with the
  page's actual controls (search, main menu, section toggles).
- **A landmark now scores its own proximity.** Landmark proximity was computed with the parent's
  depth, so a landmark never got credit for being one.
- **Landmarks are excluded from the Information bucket.** A landmark's name ("Page tools", "Personal
  tools") is structure, not something to read to anyone — its +3.0 exists to lift the content
  *inside* it. Leaving them in put six navigation labels above the article's `h1`, backwards from
  doc 08 §1's WebAIM finding that headings, not landmarks, are how people navigate.
- **`nameLengthCap` 1.5 → 0.75.** At 1.5 a long label was worth more than the entire h1-to-h6 range,
  so a verbose `h3` outranked the page's `h1`. Name length should break ties, not decide them.
- **Duplicate-name detection is containment, not equality.** An accessible name is built by
  concatenating descendant text, so a child's text is a substring of its parent's name far more often
  than an exact match. Static text that only repeats an ancestor's name is now dropped outright, not
  merely penalised — and separately, text that only repeats an *adjacent control's* label is dropped
  too (a `<label>` is a sibling of its input, so the ancestor check can never see it). On the mock
  form that removed five of nine Information entries, all of them duplicates.
- **Disabled and zero-size controls never enter the Navigation bucket** — you cannot act on them.
- **Features are de-duplicated by signature**, best score winning, and an unnamed node gets no
  signature at all rather than sharing one usage counter with every other unnamed node of its role.
- **A `<div onclick>` with no ARIA role** (doc 18's "unknown element") is scored below a real control,
  kept in Navigation because it is genuinely actionable, and flagged `isAmbiguous`.
- **Page chrome vs main content.** Controls inside `banner` / `navigation` / `complementary` /
  `contentinfo` / `search` get a **page chrome** penalty; controls inside `main` / `form` get an
  **in main content** boost. When several chrome interactives sit alongside real task controls, the
  chrome is collapsed into one synthetic **Site chrome · N** group so banner links cannot fill the
  visible slots.
- **Offscreen nodes are hard-excluded from both buckets** (same as zero-size / hidden). They remain
  in the inspector tree with `prunedBecause: 'outside viewport'`.
- **Overflow packs into hierarchical groups** instead of a silent `slice(0, 12)`. When a bucket has
  more candidates than `limit`, [`groupFeatures.js`](src/groupFeatures.js) clusters by nearest
  heading / `role=group` / landmark, then falls back to a 2×2 spatial split, and recurses until each
  visible level fits. Opening a group (`action: 'open'`) only changes the choice set — no Playwright
  call. A page with ≤12 controls stays a flat list.
- **`identity` (`role::name::nearestNamedAncestor`)** disambiguates repeated labels for dedupe /
  locate. `signature` (`role::name`) is unchanged and still keys the usage-frequency boost.

Tunable knobs: `DEFAULT_WEIGHTS` in `domTreeEngine.js`, and `usageWeight` / `limit` / `weights` in
`buildAuxiliaryTree`.

### When tier 1 says it is unsure

`ambiguity` implements doc 08 §5's tier-2 trigger conditions — purely structurally, because deciding
whether to escalate must not itself cost an LLM call. It flags a page when there are no landmarks and
no headings to anchor on, when the top candidates are within 0.5 points of each other (a flat,
close-to-arbitrary ordering), or when clickable elements have no ARIA role to classify them by. The
inspector shows this as a banner. Nothing calls an LLM — the engine reports, the caller decides. On
the mock form, all seven fields score within 0.2 of each other and the flag fires, correctly: on a
form there is no "most important field".

## The zooming navigator (Slider mode)

The same ranked features, driven by a single continuous axis instead of a list of buttons — a
Dasher-style zooming interface where every option is a box whose **size is its predicted
probability**. Steer with the slider, hold *go* to fly into what you want, hold *back out* to
reverse. `src/dasherModel.js` is pure and synchronous; `src/ui/dasher.js` draws it.

Why this shape: for someone who cannot tap precisely, a ranked list is still a set of small discrete
targets. Making the likely option physically bigger converts precision into time — you can be sloppy
and still land on the thing you probably wanted. That is Dasher's whole argument, and the ranking to
size the boxes with already exists here.

### Relationship to Dasher

[docs/tech/research/07-dasher-integration.md](../../docs/tech/research/07-dasher-integration.md)
assessed the real Dasher and concluded the library is not integrable (no Dart binding; the WASM port
is disclaimed by its own maintainers as "a demo, not a supported product"; DasherCore is wired
specifically to letters and an n-gram language model). Its §7.2(a) named the tractable alternative —
borrow the *mechanism* and build a purpose-specific widget — and flagged one objection: doing that
for non-alphabet choices would mean faking a corpus to get region sizes. That objection does not
apply here. `domTreeEngine.js` already produces a score per feature and `usageStore.js` already
counts how often each was picked; those are real probabilities over exactly the options being
navigated, filling the language model's role.

The dynamics are DasherCore's, from `Src/DasherCore/DasherModel.cpp`: the same coordinate space
(`MAX_Y = 4096`, crosshair at 2048, `NORMALIZATION = 1<<16`), the same arithmetic-coding interval
nesting for child bounds, and the same one-step interpolation toward "the target range fills the
viewport" —

```
r  = MAX_Y * (R - y1) / (y2 - y1)          # where the root would be if [y1,y2] filled the screen
frac = (ratio^(1/steps) - 1) / (ratio - 1) # how far along to move this frame, ratio = MAX_Y/(y2-y1)
R += frac * (r - R)
```

`steps` is the speed preset — beginner / intermediate / advanced, roughly 1.8s / 1.0s / 0.5s to
select and confirm. Dasher ships the same three-way manual preset rather than measuring the user
(doc 07 §7.2d), so it is the same knob in the same place.

### What differs from Dasher, deliberately

- **Actions sit behind a confirm box.** In Dasher, entering a node outputs a letter and backing out
  un-outputs it. A letter is retractable; a click on someone's page is not. So zooming into a
  feature only opens it — the dispatch is a second box you have to steer into. Drifting across a
  region cannot fire anything.
- **Forward speed is bounded by how far the aim is from the crosshair.** DasherCore does this too
  (`CDefaultFilter::ApplyTransform`'s `xmax(double_y)`). It is not cosmetic: zoom and steering
  converge at the same rate, so without it a box you are aiming at from a distance is still short of
  the crosshair when the view has to re-root, and the neighbour sitting on the crosshair gets
  committed instead.
- **Descending and ascending are exact inverses** — enter a child once it covers the viewport, leave
  the root once it does not. Every width-threshold version of this rule tried here either committed
  a neighbour early or popped straight back out of any child smaller than the threshold's share.
- **A scan that lands mid-branch is held, not applied.** The watcher can fire at any moment;
  rebuilding the tree under someone mid-steer discards a half-spelled word. The new scan is applied
  when they return to the top.
- **Every box keeps a floor on its size** (`MIN_CHILD_SHARE`), so a low-ranked option is never too
  small to steer into — the same property that keeps rare letters reachable in Dasher.

### Text entry

Steering into a text field opens an alphabet sized by English letter frequency, so you keep zooming
to spell — the original Dasher use case, and the gap doc 07 §7.2(b) identified as this project's
strongest unaddressed one (someone with neither reliable speech nor reliable tapping, but some
continuous control). It is an order-0 frequency model, not a reimplementation of Dasher's PPM: the
property that matters for a coarse input is that common letters are bigger targets, and that is all
it claims to do. `⌫` deletes, and `✓ type "…"` fills the real field via `/api/act`.

### One axis on purpose

The slider is the entire input. One continuous 1D axis is what the phone app already calibrates for
(`TaskShape.continuous` in `code/app/lib/runtime/task_spec.dart`, driven by a joystick), so anything
drivable in this pane is drivable from the phone with no second control channel. The canvas also
accepts mouse steering, which is only there to make it demonstrable.

Tunable knobs: `SPEED_PRESETS`, `MIN_CHILD_SHARE` and `MAX_ZOOM` in `dasherModel.js`; the
**prediction** slider in the UI is the softmax temperature over feature scores — low gives the
predicted option a much bigger target, high flattens everything toward equal widths.

## New-page / state-change detection

`src/pageWatcher.js` + `src/inject/pageWatcher.client.js` implement doc 08 §4: after a click the
auxiliary tree is **not** regenerated on a fixed rule like "always rescan" — only when something
page-shaped actually happened, detected two ways, without ever trying to classify what was clicked:

1. **History API hook** — `pushState`/`replaceState`/`popstate` are wrapped inside the page. Covers
   real routers.
2. **MutationObserver threshold** — covers apps (like the mock UI) that re-render without touching the
   URL: after each batch of mutations a cheap fingerprint (element count, `<h1>` text, `main`'s
   accessible name, `document.title`) is compared against the previous one. It counts as a new screen
   if the heading/label/title changed, or element count churned by more than 50% — both starting
   thresholds to hand-tune, not proven constants. The client reports *which* fields changed, so the
   event log names the real reason rather than guessing at one.

Either signal calls back into Node (`page.exposeFunction`) and the session regenerates only then,
debounced at 250ms so a router firing both signals for one navigation causes one rescan. Verified this
discriminates: switching the mock UI's demo mode (a full screen swap) fires it; dragging the scroll
selector's slider (an in-place value change, same screen) does not.

## The API surface

The inspector is an HTTP client of the session, not a special case of it — these are the routes it
uses, and they are the same shape the phone client needs:

| Route | Does |
|---|---|
| `GET /api/state` | Last scan: both buckets, the pruned tree, stats, ambiguity, recent events. `?raw=0` omits the full accessibility tree. |
| `POST /api/scan` | Force a re-scan. |
| `POST /api/goto` | `{ url }` — navigate and scan. Bare hosts and local paths are accepted. |
| `POST /api/act` | `{ ref \| signature \| bucket+rank, action?, value? }` — dispatch a real interaction and record the selection. |
| `GET /api/screenshot.png` | Current page. |
| `GET /api/events` | SSE: `scan`, `watcher`, `act`, `selection`, `goto`, `navigated`, `error`. |

A feature is addressed by `ref` (the snapshot's `aria-ref=eN` — exact, but only valid until the next
scan) or by `signature` (`role::name` — stable across scans, ambiguous when a page repeats a label).
`browserSession.locate()` tries the precise one first and falls back to the stable one.
