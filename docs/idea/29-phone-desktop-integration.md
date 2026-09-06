# 29. Phone ↔ Desktop Integration — Highlighting, Transport, and Scan/Voice Grids

**Status:** first pass, backend half implemented (`code/desktop`); phone-side wiring not yet started (see §5). This is the doc [tech/README.md](../tech/README.md) asked for under "Next steps" — the seam it already named as unstarted: *"the phone↔agent transport,"* now with a concrete shape, plus the two UX questions raised alongside it (how the desktop shows *which panel* a feature lives in, and how a switch/voice user gets from "many features" down to "the one I want").

**Reads together with:** [03 — Input & Calibration](03-input-calibration.md) (§3.2–3.3, the task/method mapping this doc's scan tree serves), [07 — Architecture](07-architecture.md) (the diagram this doc fills in one box of), [28 — Scope Lock: No AI At All](28-meeting-notes-scope-lock-no-ai.md) (binding constraint: everything below is deterministic, no LLM in the loop), [tech/research/05 — Mobile Remote Architecture](../tech/research/05-mobile-remote-architecture.md) (the WebSocket verdict this doc implements), [tech/research/10 — Additional Input Modes](../tech/research/10-additional-input-modes.md) §3 and §7 (Android Voice Access's grid, and the coarse-then-fine pattern every input mode converges on).

---

## 0. The four questions this doc answers

1. **Highlighting** — before anything is scanned or spoken, how does the system show *which of the page's panels* a feature belongs to (the "top bar / left panel / main content" framing)?
2. **Transport** — how does what the desktop computes reach the phone in real time, and how does fused intent get back?
3. **Input-method handshake** — who decides *which* rendering (buttons, joystick, trackpad, switch-scan, or a voice grid) is live at any moment, and how does the desktop find out?
4. **Grid/tree mapping** — once switch-scan or a voice grid is the active method, how does "many ranked features" become "a sequence of presses/words this specific user's calibrated input can produce"?

---

## 1. Highlighting: regions, not a flat ranked list

`domTreeEngine.js`'s `buildAuxiliaryTree(...).tree` is already a hierarchy with every ARIA-landmark node flagged `isLandmark: true` — a page's `banner`/`navigation`/`main`/`complementary`/`contentinfo` structure was already being computed, just never surfaced as its own thing. **[`src/regions.js`](../../code/desktop/src/regions.js)** walks that tree once and extracts the **top-level landmarks** (a landmark nested inside another, like a `search` region inside `header`, folds into its parent rather than becoming a fourth sibling) as `Region` objects: `{ role, friendlyName, name, box, features }` — `friendlyName` maps `banner → "top bar"`, `navigation`/`complementary → "side panel"`, `main → "main content"`, matching the three-panel framing directly. `features` is the flat list of ranked navigation/information entries that live inside that region.

This is what "highlight the three main panels" resolves to concretely: the desktop inspector (and, later, the phone) draws each region's `box` as its own outline — a different visual layer from the per-feature numbered boxes the inspector already draws — so a user or caregiver sees "3 panels" before they see "12 buttons." `describeRegions(regions)` renders the same fact as one narration line ("3 panels: top bar (4 items), side panel (6 items), main content (2 items)") for when the output channel is voice, not sight.

No new heuristic was needed — this is existing landmark-scoring output, grouped, not re-derived.

---

## 2. Transport: a WebSocket on the same process, per research/05

[tech/research/05](../tech/research/05-mobile-remote-architecture.md) §1 already picked raw WebSocket over polling/Firebase/gRPC and gave the reason: the desktop already runs a long-lived Node process (`server.js`) hosting the Playwright session, so a WS route on that same process is one extra endpoint, not a new service. **[`src/phoneTransport.js`](../../code/desktop/src/phoneTransport.js)** implements exactly that, mounted at `ws://<desktop-host>:7777/phone`:

| Direction | Message | When |
|---|---|---|
| → phone | `{ type: 'state', regions, navigation, information, ambiguity, url }` | On connect, and after every real rescan (`session.onEvent('scan')` — not `'goto'`/`'navigated'`, which fire before the rescan completes and would push a stale tree) |
| → phone | `{ type: 'scanTree', arity, bucket, root, paths, narration, vocabularyMap }` | On request, or automatically alongside `state` once the phone has told the desktop its active method is `switchScan` or `voiceGrid` — a phone using buttons never pays for scan-tree computation it will never render |
| ← phone | `{ type: 'inputMethod', method, arity?, vocabulary? }` | The handshake — see §3 |
| ← phone | `{ type: 'act', ref\|signature\|bucket+rank, action?, value? }` | Identical shape to `POST /api/act` — the phone and the inspector dispatch through the exact same `session.act` call, so nothing about "is this the phone or the inspector" leaks into `browserSession.js` |
| ← phone | `{ type: 'requestScanTree', arity?, bucket? }` | Ask for a tree at a specific arity/bucket outside the standing handshake (e.g. trying a second calibrated method) |

Same routes are also reachable over plain HTTP (`GET /api/regions`, `GET /api/scan-tree?arity=&bucket=`) for the inspector UI and for debugging without a WebSocket client.

**Deliberately not built yet:** the Flutter side of this link (`web_socket_channel`, per research/05 §5's package pick). See §5 for exactly where it plugs in and why it's sequenced after this half.

---

## 3. The input-method handshake: the phone decides, the desktop renders

The desktop has no idea what the user's `CapabilityProfile` says — that measurement lives entirely on the phone (`code/app/lib/model/profile.dart`). So the handshake is one-directional by design: the phone sends `{ type: 'inputMethod', method, arity, vocabulary }` once calibration/preset selection resolves a method (`chooseMethod` in `task_spec.dart` already computes this — `TouchMethod.buttons | joystick | trackpad | switchScan`, plus the not-yet-modeled `voiceGrid` for a grid-based voice selection per research/10 §3), and the desktop's only job is to remember it per-connection and shape its pushes accordingly:

- **buttons / joystick / trackpad:** no scan tree — the phone already renders `navigation`/`information` directly (discrete list, cycle-and-confirm, or drag-to-hover, per §3.3's existing matrix). Nothing new needed here; this doc doesn't touch that path.
- **switchScan:** `arity` = however many simultaneous switch signals the user's calibration found reachable (2 for a strict two-switch setup; the profile's `reachableCells` count for a coarser mapping). The desktop returns a binary/N-ary `scanTree` (§4).
- **voiceGrid:** `arity` = a numbered-grid size (research/10 §3's Android Voice Access pattern — "say a number"), or, when the user has a *calibrated personal vocabulary* (`CapabilityProfile.vocabulary`, issue #3's sentence-based calibration), `vocabulary` is sent instead and the desktop's `scanTree.assignVocabulary` maps real words onto tree branches directly rather than numbers.

Re-sending `inputMethod` (e.g. after a profile switch, per the phone's `preview` screen "Level up"/"recalibrate" actions) simply updates what gets pushed next scan — no reconnect needed.

---

## 4. Grid/tree mapping: one N-ary partition, generalized

The concrete request behind this doc: *"if there are two buttons, map one to the left half of the screen and one to the right, then subdivide; if there's a voice grid, map vocabulary onto it; if it's buttons, show what each button does."* **[`src/scanTree.js`](../../code/desktop/src/scanTree.js)** is that, generalized past "two buttons splitting a screen in half" to *any* arity over *ranked features* rather than raw screen geometry — which matters because a page's actually-useful controls are rarely evenly spread across four screen quadrants; they cluster (a nav bar, a form). Partitioning by rank instead of raw position means the button/swipe/word that takes the fewest steps to reach is the one domTreeEngine.js already believes is most likely wanted, not whichever happened to land top-left.

**Mechanism — Huffman-style N-ary merge:** sort features by score ascending, repeatedly merge the `arity` lowest-weight nodes into one internal node until a single root remains (padding with invisible zero-weight placeholders first so every internal node ends up with exactly `arity` children — a scanning device needs a fixed number of positions per step, not a tree that's binary on one branch and ternary on another). This is the same principle Huffman coding uses for prefix codes, applied here to path *length* instead of encoded *bits*: a higher-ranked feature never ends up on a longer path than a lower-ranked one.

This is a direct generalization of the binary-quadrant idea in the request (arity 2 ⇒ literally a left/right, then up/down binary tree, exactly as described) to:
- **More than two switches or swipe directions** — arity = however many the calibration found reliable (a 4-way swipe profile gets a 4-ary tree, reaching four times as many features per "level" as binary).
- **Voice grids** — `assignVocabulary(node, vocabulary)` maps a calibrated personal vocabulary onto one node's children directly when there are enough words (mirrors `code/app/lib/inputs/voice_vocab.dart`'s `VocabMapping.mapWords`, which already does this for the four fixed demo tasks — this is the same idea applied to a live ranked feature list instead of a static option array), falling back to the same next/previous/select three-tier scheme when the vocabulary is smaller than the branching factor.
- **"Show on the computer what each button does"** — `describe(node)` renders what pressing further narrows into ("Search, Menu" for a small group; "A, B, and 3 more" once a group is large), so the inspector (and eventually the phone's own output strip) can caption each branch instead of showing an unlabeled split.

**What's out of scope here, on purpose:** actually drawing the split on the live screenshot (today's inspector already draws a numbered box per feature; drawing the *scan tree's* current group boundary is a UI task on `src/ui/`, not a ranking-engine task, and isn't done yet), and the phone-side rendering of any of this (§5).

---

## 5. What's still unstarted, and where it plugs in

Per [tech/README.md](../tech/README.md)'s existing framing, build order was (1) desktop read/rank, (2) phone calibration UI, (3) native-app control (never in scope). This doc is squarely inside (1) — the transport, regions, and scan-tree pieces above are desktop-only and have their own test coverage (`code/desktop/test/{scanTree,regions}.test.js`, `npm test`). Not done, and sequenced deliberately after this half so the phone side has a fixed message contract to build against rather than guessing at one mid-flight (research/05 §5's flagged "biggest integration risk"):

- A WebSocket client connecting to `/phone`, sending `inputMethod` once `chooseMethod` resolves and forwarding resolved intents as `act` messages. **Which phone codebase this lands in changed mid-write of this doc:** [docs/app/03-expo-port.md](../app/03-expo-port.md) (merged in while this doc was being written) plans an Expo/React Native rebuild at `code/app-expo/`, with Flutter kept only as the behavioural spec until parity — `code/app` is not being deleted, but new client work should target `code/app-expo/`'s `session.ts` (the `AppState.emit` equivalent named in `docs/app/03-expo-port.md` §1), not `lib/model/session.dart`. This doesn't change anything in §1–4 above: the transport is plain JSON over a WebSocket, equally reachable from Dart's `web_socket_channel` or React Native's built-in `WebSocket`, so nothing here is Flutter- or Expo-specific.
- Rendering `regions`/highlight boxes and the `scanTree` shape on whichever phone client is current — a discrete/joystick/trackpad task driver already exists on both the Dart side and in the Expo port plan; a switch-scan/voice-grid driver consuming `scanTree` doesn't exist on either yet.
- Turning `scanTree`'s `describe()` output plus `regions`' `describeRegions()` into actual narration — the *content* is produced by both modules already; the *voice* (TTS) is the still-not-decided piece tech/README.md flags separately, independent of which phone client ends up speaking it.

**A live merge-conflict note for whoever picks this up:** both `code/app` (Flutter) and the incoming `code/app-expo/` are moving targets on separate work right now. Nothing in this doc's implementation touches either — every file listed in §1–4 is new (`regions.js`, `scanTree.js`, `phoneTransport.js`) or an additive change to `server.js` (new imports, three new routes, one `attachPhoneTransport(...)` call at startup) — `domTreeEngine.js` and `groupFeatures.js`, also under active concurrent work, are only *imported from*, never edited, by any of this. `groupFeatures.js` (merged in alongside this doc) already solves a related-but-different problem — folding an oversized bucket into nested "open this group" items for *display* — and composes cleanly with `scanTree.js`: a scan tree built over a bucket that already contains group items scans the groups like any other feature, no special-casing needed.
