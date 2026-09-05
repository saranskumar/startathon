# Tech / Implementation Notes

Most implementation decisions haven't been made yet — this is a short, honest tracker of what's assumed vs. what still needs deciding, not a real spec. See [../idea/](../idea/README.md) for the product idea itself.

## Known / assumed
- Phone is a thin client / remote control, not a native accessibility OS shell ([idea/05-scope.md](../idea/05-scope.md), [idea/07-architecture.md](../idea/07-architecture.md)).
- Agent execution layer: an existing open-source agent-that-controls-a-computer framework (e.g. OpenClaw) — not building this from scratch.
- Voice output: some TTS engine, not yet chosen, for narration.
- Intent/inference: an LLM API, not yet chosen, for parsing fused touch+voice input and filling inference gaps.

## Not yet decided
- Native mobile app vs. web/React view for the touch surface — matters for how raw touch coordinates/timing are captured for calibration scoring ([idea/03-input-calibration.md](../idea/03-input-calibration.md)).
- Which speech-to-text API, and whether it exposes per-utterance confidence directly or needs a self-computed word-error-rate.
- Which TTS engine/voice for narration output.
- Which LLM provider/model for intent inference.
- How calibration scores and the capability profile are persisted (local storage vs. a backend).
- How the agent connects to the actual target app being controlled (e.g. WhatsApp) — official API vs. accessibility-tree automation vs. screen-scraping.

## Deployed pieces
- `code/mock/` — Aperture, the mock target-website (plain HTML/CSS/JS). Auto-deploys to Vercel via [.github/workflows/deploy-mock-web.yml](../../.github/workflows/deploy-mock-web.yml) on every push to that folder. **Needs a Vercel project created (Root Directory: `code/mock`) and a `VERCEL_PROJECT_ID_MOCK` repo secret before this workflow will succeed** — it reuses the existing `VERCEL_ORG_ID`/`VERCEL_TOKEN`.
- `code/app/` — the Flutter phone/remote-control app, deployed the same way via [.github/workflows/deploy-flutter-web.yml](../../.github/workflows/deploy-flutter-web.yml).

## Next steps
Once tech choices are made, add one doc per component (client, agent, speech, TTS) here rather than expanding this file further.
