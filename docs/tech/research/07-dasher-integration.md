# 07. Dasher Integration Assessment

Research thread on whether [Dasher](https://github.com/dasher-project/dasher) — the Cambridge/GNOME zooming text-entry interface for assistive input — is usable as a real component in this project's build, or only as prior art for the pitch.

---

## 7.1 What Dasher actually is

**Dasher** is a *zooming predictive text-entry system*, originally from David MacKay's Inference Group at Cambridge, later adopted by GNOME. Its own description: "a zooming predictive text entry system, designed for situations where keyboard input is impractical (for instance, accessibility or PDAs)."

**Interaction model:** Text entry is framed as navigating a conceptual "library containing all possible books, ordered alphabetically on a single shelf." The user continuously steers (via whatever pointing device they have) into a letter, which expands into its possible continuations sized by a language model's predicted probability — more likely next letters get bigger, easier-to-hit regions. The user keeps zooming through nested probability-weighted regions until the intended text has been "flown into." There are no discrete keystrokes at all — it's pure continuous steering, driven by an n-gram/PPM-style language model that adapts probable-letter sizing as you type.

**Input devices supported:** mouse, touchscreen, eye-tracking (with dwell-time/accuracy settings), and **switch access** (scanning speed + switch configuration) — i.e. single-switch scanning is a first-class, already-solved input mode inside Dasher itself, not a bolt-on. Any device that produces a continuous 1D or 2D directional signal can drive it (joystick-style input included, in spirit — the docs describe it as accommodating "any mechanism allowing directional control").

**Speed adaptation:** Dasher has a manual **Speed Control** (beginner/intermediate/advanced zoom-rate presets) rather than an automatic, measured calibration score. It's user-tunable adaptation, not an auto-detected ability measurement like this project's `method_scores`.

**Platforms / tech stack:**
- Canonical engine (`DasherCore`) is **C++**, built via Autotools, with native frontends for Linux (GTK+), Windows (native, optional MS Speech/Tablet API), macOS (Xcode native + GTK2), and an Android port. Repo: [github.com/GNOME/dasher](https://github.com/GNOME/dasher) (canonical, mirrored from GNOME's GitLab) — **actively maintained**, pushed as recently as March 2026, GPL-2.0.
- The `dasher-project/dasher` GitHub repo (the one the user linked) is a **fork** of GNOME/dasher, last pushed May 2023 — effectively a stale mirror/fork, not the live upstream.
- **Critically, there is a separate, actively maintained web port: [dasher-project/dasher-web](https://github.com/dasher-project/dasher-web)** — a **WebAssembly build of the native DasherCore C++ engine**, compiled via Emscripten, with data files (alphabets, training text, localized strings) preloaded into the WASM virtual filesystem and a JavaScript wrapper (`dasher-wasm-wrapper.js`) exposing a canvas-rendering, mouse/touch-driven API. It's explicitly described by its own maintainers as **"a demo of the Dasher engine on the web, not a supported product."** MIT licensed. Live demos: https://dasher-project.github.io/dasher-web/ and a JS playground at https://dasher-project.github.io/dasher-web/js-demo/.
- No official Flutter/Dart or native mobile-app-embeddable package was found. (A "flutter-dasher" repo turned up in search but is an unrelated Flutter app that happens to be named "Dasher" — a delivery-app clean-architecture sample, not this Dasher. Do not confuse the two.)

---

## 7.2 Mapping onto this project's actual gaps

### (a) Trackpad/joystick fallback pattern (§3.3 free-pointing / large-N discrete choice)
Dasher's zooming mechanism *is* fundamentally a continuous-pointing, probability-weighted narrowing interaction — structurally the same shape as this project's §3.2 "large-N discrete choice: filter down via progressive narrowing" and the §3.3 free-pointing trackpad/joystick fallback ("coarse-to-fine zone narrowing"). The resemblance is real and worth citing. But Dasher's implementation is *specifically wired to letter/language selection* (it needs a language model, alphabet files, and n-gram training data to size the zoom regions) — it is not a generic "narrow down N arbitrary UI options" widget. Repurposing it for e.g. "pick 1 of 50 contacts" would mean either (i) awkwardly encoding contact names as a fake alphabet/corpus for DasherCore to zoom through, or (ii) not using DasherCore at all and just borrowing the *concept* (probability-sized nested regions, continuous steer-and-commit) to hand-build a purpose-specific widget. Option (ii) is far more tractable.

### (b) Free-text entry gap for poor-speech + poor-tap-but-some-continuous-control users
This is the strongest fit. The current docs (02-core-model.md §2.2 Thesis B, 03-input-calibration.md §3.1) assume voice carries all free-text content and touch only handles selection. Dasher is *literally built for* the user who has neither reliable speech nor reliable discrete tapping but does have some continuous motor control (this is its original clinical use case — locked-in and severely motor-impaired users typing via joystick/eye-tracking/single-switch). This is a genuine, currently-unaddressed gap in the project's model, and Dasher is strong, credible prior art for exactly that gap — arguably more relevant than Ability-Based Design is, since it's the same *specific* problem (free text without speech or fine tapping) rather than a general design philosophy.

### (c) Embeddability into the actual Flutter app / browser mock
- **Flutter app (`code/app`):** No official Dart/Flutter binding exists. The WASM build is a browser artifact (Emscripten + JS wrapper + canvas), not a Flutter plugin. It could theoretically be embedded via a Flutter `webview_flutter`/`flutter_inappwebview` wrapper loading the hosted demo page, but that's a fragile, heavy, and janky integration for a 30-hour build (cross-origin iframe control, event bridging, styling isolation, no guarantee the wrapper API is documented/stable — its own maintainers call it a demo, not a supported product).
- **Browser mock (`code/mock`):** Since `code/mock` is already plain HTML/CSS/JS, the WASM build is *technically* the easiest place to embed Dasher directly — script tag + canvas + the wrapper's mouse/touch API. This is plausible in isolation. But `code/mock` is Aperture, the **target website the agent operates on**, per docs/tech/README.md — it's not the phone-side input surface. Embedding Dasher there wouldn't touch the actual capability-profile/calibration flow this project is being judged on; it would be a demo of Dasher next to the project, not part of it.
- Neither integration path lands inside the actual locked demo scope (05-scope.md), which is phone-side calibration + adaptive rendering for one task with two input methods (03-input-calibration.md §3.4).

### (d) Calibration/speed-adaptation as prior art
Dasher's speed control is a **manual preset** (beginner/intermediate/advanced), not an automatically measured per-user score. It's *conceptually* adjacent to this project's calibration idea (the system should adapt to how fast/precisely a user can steer) but it isn't the same mechanism — this project's `score(method)` computed from success-rate/time/error (03-input-calibration.md §3.1) is a more automated, measured version of what Dasher leaves to manual user choice. Worth a one-line mention as "even Dasher, the most established tool in this space, leaves speed-matching to manual presets — we automate it" — a point that makes this project's calibration look more sophisticated, not derivative.

---

## 7.3 Viability verdicts

**Integration in the actual 30-hour build: Weak.**
- No Flutter-native path exists.
- The WASM build is real but is a demo artifact ("not a supported product"), scoped to letter/language zooming, and would require nontrivial glue work (webview embedding or `code/mock` scripting) that doesn't touch the calibration/composition mechanics actually being judged.
- Repurposing DasherCore's zoom engine for non-alphabet selection tasks (contacts, menu items) would require faking a language-model corpus — more engineering than it saves versus a purpose-built widget.
- Given the locked scope only needs two of the nine possible interaction implementations (03-input-calibration.md §3.4), spending build hours on Dasher integration crowds out that actual scope.

**Citing it as prior art in the pitch: Strong.**
- It's decades-old (Cambridge, MacKay group), GNOME-adopted, actively maintained upstream, GPL-2.0, with a real academic and clinical pedigree in assistive tech — comparable credibility to Ability-Based Design, and arguably more specifically on-point since it targets the *exact* combination this project's Thesis B gap describes (no reliable speech + no reliable discrete tap, but some continuous control).
- Its built-in switch-access mode is also independently useful supporting evidence for §3.5 (single-switch scanning as "not exotic, it's the established minimum" — 15.4/15.7 already flag this tension) — Dasher shipping switch-access as a first-class mode for over a decade backs up the brain-dump's instinct that it's core, not roadmap-only.

---

## 7.4 Recommendation

**(c) — cite Dasher as prior art; do not integrate the library, and do not build a Dasher clone in the hackathon window.**

Reasoning:
1. The actual judged deliverable is the capability-profile/calibration model and its composed input/output behavior, not a text-entry widget — Dasher touches neither the calibration mechanism nor the locked demo's two required interactions (03-input-calibration.md §3.4).
2. Real integration (native lib or WASM+webview) costs hours disproportionate to any demo payoff, and the WASM build's own maintainers disclaim it as unsupported.
3. A "lightweight Dasher-inspired zooming widget built from scratch" (option b) is more build effort than the fallback rule in §3.3 already prescribes (buttons/joystick-cycle/trackpad-drag patterns) for equivalent task coverage in the locked scope — it would be new UI surface for a task shape (free text without speech) that isn't in the two demoed interactions.
4. Where Dasher earns its keep is narrative: it is direct, credible, specific evidence that (i) the free-text-without-speech-or-taps gap identified in this research thread is real and has an established clinical answer, and (ii) single-switch scanning is legitimately core rather than exotic — both strengthen the pitch without costing build time.
5. **Roadmap note worth adding to 12-roadmap.md:** if the project continues past the event, Dasher/DasherCore (via its WASM build) is a legitimate candidate to actually adopt for the free-text-entry gap in (b) above — flag it there as a named future direction rather than dropping the thread.

---

## 7.5 Amendment — what was actually built (revisited after the DOM tree engine landed)

§7.4 recommended **(c)**: cite Dasher as prior art, integrate nothing, and do not build a Dasher clone
in the hackathon window. That recommendation has been partly overturned, and this section records why
rather than quietly rewriting the verdict above.

**Still holds:** no Dasher code is used. The library assessment in §7.1/§7.2(c) is unchanged — no Dart
binding exists, the WASM port is disclaimed by its own maintainers, and neither integration path
touches the calibration mechanics. Nothing was vendored, embedded, or wrapped.

**What changed:** §7.2(a) had already identified option (ii) — borrow the *mechanism* (probability-
sized nested regions, continuous steer-and-commit) and hand-build a purpose-specific widget — as "far
more tractable" than repurposing DasherCore. The single objection raised against it was that sizing
regions for non-alphabet choices would mean "awkwardly encoding [options] as a fake alphabet/corpus."

That objection stopped applying once `code/desktop/src/domTreeEngine.js` existed. It produces a real
score per feature, and `usageStore.js` counts how often each has been picked. Those are genuine
probabilities over exactly the options being navigated — no corpus to fake, because the ranking that
the rest of the system already needed *is* the model. The cost estimate in §7.4(3) was made assuming
that ranking did not exist yet.

**What was built:** `code/desktop/src/dasherModel.js` — a zooming navigator over the auxiliary tree,
steered by one continuous 1D axis, with the dynamics ported from DasherCore's `DasherModel.cpp` (same
coordinate space, same arithmetic-coding interval nesting, same one-step interpolation) rather than
approximated. See [code/desktop/README.md](../../../code/desktop/README.md) for the mechanism and for
the four places it deliberately departs from Dasher — most importantly that a real action sits behind
its own confirm box, because Dasher's model of "entering a node outputs, backing out un-outputs"
assumes a retractable output, and a click on a live page is not retractable.

**§7.2(b) is addressed, not just cited.** Steering into a text field opens an alphabet sized by letter
frequency, so the same single axis that picks options also spells words. That is the free-text-without-
speech-or-tapping gap this doc identified as the strongest Dasher fit and as currently unaddressed by
the project's model. It is an order-0 frequency model, not a reimplementation of PPM.

**§7.4(1) still stands as a caution.** This is a second interface onto the same ranking, not the
judged deliverable, and it does not replace the two interactions the locked scope requires
([05-scope.md](../../idea/05-scope.md), [03-input-calibration.md](../../idea/03-input-calibration.md)
§3.4). It earns its place because it needed no new model and no new input channel: it runs on
`TaskShape.continuous`, which the phone already calibrates for.

**§7.2(d) is unchanged and still the better pitch line.** The speed control here is Dasher's own
three-way manual preset (beginner/intermediate/advanced), precisely because this project's measured
`score(method)` calibration is the more sophisticated mechanism — the contrast is the point.

---

## Sources
- [github.com/dasher-project/dasher](https://github.com/dasher-project/dasher) — user-linked repo; confirmed to be a fork of GNOME/dasher, last pushed 2023-05-22 (via `gh api repos/dasher-project/dasher`)
- [github.com/GNOME/dasher](https://github.com/GNOME/dasher) — canonical upstream mirror (GPL-2.0, C, actively pushed as of 2026-03)
- [github.com/dasher-project/dasher-web](https://github.com/dasher-project/dasher-web) — WebAssembly/JS port of DasherCore (MIT)
- https://dasher-project.github.io/dasher-web/ — live WASM demo
- https://dasher-project.github.io/dasher-web/js-demo/ — JS playground demo
- https://dasher.at/ — Dasher project site
- https://dasher.at/docs/ — documentation index
- https://dasher.at/docs/concepts/how-dasher-works/ — zooming interaction model explainer
- https://dasher.at/docs/getting-started/how-to/manual/ — input device / settings manual
- https://en.wikipedia.org/wiki/Dasher_(software) — background (surfaced in search, not directly cited for facts above)
