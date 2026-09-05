# Tech / Implementation Notes

Most implementation decisions haven't been made yet — this is a short, honest tracker of what's assumed vs. what still needs deciding, not a real spec. See [../idea/](../idea/README.md) for the product idea itself.

## Known / assumed
- Phone is a thin client / remote control, not a native accessibility OS shell ([idea/05-scope.md](../idea/05-scope.md), [idea/07-architecture.md](../idea/07-architecture.md)).
- Agent execution layer: an existing open-source agent-that-controls-a-computer framework (e.g. OpenClaw) — not building this from scratch.
- Voice output: some TTS engine, not yet chosen, for narration.
- Intent/inference: an LLM API, not yet chosen, for parsing fused touch+voice input and filling inference gaps.

## Decided
- **Target automation = browser accessibility tree, not native OS apps.** The agent drives a dedicated Playwright-controlled browser instance (Chromium), reading each page's accessibility tree (role/name/value/children) and dispatching actions (click/fill/selectOption) on the node the LLM matches against the fused user intent. The LLM reasons over the raw tree directly — no separate matching/search layer.
- This is not a limitation for the demo: neither Aperture nor the Google Form need the disabled user's own personal browser session/login, so a dedicated agent-controlled browser window (visible on a monitor for the demo) is the right shape, not a workaround.
- Playwright is cross-platform for the agent backend itself (Node/Python/Java/.NET bindings, bundles its own Chromium/Firefox/WebKit) — no OS-specific backend work needed.
- **Native desktop app control (Windows UI Automation / macOS AXUIElement / Linux AT-SPI) is explicitly out of scope for this event** — browser automation covers both demo surfaces entirely. See [idea/12-roadmap.md](../idea/12-roadmap.md).
- **Build order:** (1) browser/agent automation against Aperture + the Google Form, (2) perfect the Flutter phone interface (calibration + adaptive rendering), (3) native-app control is future work, not attempted this event.

## Not yet decided
- Which speech-to-text API, and whether it exposes per-utterance confidence directly or needs a self-computed word-error-rate.
- Which TTS engine/voice for narration output.
- Which LLM provider/model for intent inference.
- How calibration scores and the capability profile are persisted (local storage vs. a backend).

## Deployed pieces
- `code/mock/` — Aperture, the mock target-website (plain HTML/CSS/JS). Auto-deploys to Vercel via [.github/workflows/deploy-mock-web.yml](../../.github/workflows/deploy-mock-web.yml) on every push to that folder. **Needs a Vercel project created (Root Directory: `code/mock`) and a `VERCEL_PROJECT_ID_MOCK` repo secret before this workflow will succeed** — it reuses the existing `VERCEL_ORG_ID`/`VERCEL_TOKEN`.
- `code/app/` — the Flutter phone/remote-control app, deployed the same way via [.github/workflows/deploy-flutter-web.yml](../../.github/workflows/deploy-flutter-web.yml).

## Next steps
Once tech choices are made, add one doc per component (client, agent, speech, TTS) here rather than expanding this file further.

## Research

Deep-dive research briefs (viability, existing solutions, implementation options) for each major component — see [research/README.md](research/README.md).
