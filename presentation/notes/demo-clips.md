# Demo clips needed

Rule: **every clip is 5–10 seconds, max.** If it needs longer to make the point, the point is wrong for a clip — cut it or split it.

**15-minute total budget** for presentation + demo + Q&A (see [docs/idea/21](../../docs/idea/21-meeting-notes-presentation-prep.md)) — every clip below competes with live demo time, so cut anything not essential rather than trimming the live demo.

Two kinds of clips:
- **(A) Problem clips** — show an existing tool failing/struggling, to make the gap visible instead of just claimed.
- **(B) Prior-art / solution clips** — show something that supports our approach (Dasher) or our own demo working.

| # | Clip | Type | Shows | Source | Status |
|---|---|---|---|---|---|
| 1 | TalkBack navigating a normal app | A | A screen-reader user has to swipe through several elements linearly just to reach one button — slow even when it "works," and assumes the swipe gestures themselves are reliably operable | Screen-record Android TalkBack live (Settings → Accessibility → TalkBack) on any app | Needed (or live on stage — per [docs/idea/21](../../docs/idea/21-meeting-notes-presentation-prep.md), the plan is to first show this tool succeeding for one clean impairment, before showing the combination-impairment gap) |
| 2 | Voice Access misrecognizing unclear/slow speech | A | A command failing or needing repeats — the exact "took a lot of manual practice to get 'call amma' recognized" anecdote, shown not told | Screen-record Android Voice Access with deliberately slow/unclear speech input | Needed (or live on stage — same rationale as clip 1) |
| 3 | Dasher zooming text entry | B | The zooming, continuous-steer text entry model — pure prior art for "free text without speech or fine taps" | Live WASM demo: https://dasher-project.github.io/dasher-web/ — screen-record ~7s of it in use | Needed (see [docs/tech/research/07-dasher-integration.md](../../docs/tech/research/07-dasher-integration.md) for why this is cited, not integrated) |
| 4 | Our calibration flow, one profile | B | The phone measuring a user's actual touch/scroll precision, live | Record from `code/app` or `code/mock` once calibration flow is demoable | Needed |
| 5 | Our system switching rendered input for two different profiles on the same task | B | The core claim: same task, two profiles, two different composed input surfaces | Record from `code/app`/`code/mock` | Needed |
| 6 | Proactive narration example (WhatsApp new-message or Bluetooth-toggle worked example) | B | Output-side composition — system speaks unprompted, minimal inferred choice, not a full generic screen readout | Needs the narration layer built first, or a scripted screen-recording standing in for it | Blocked on build |

## Where clips slot into the deck

Map each clip number above to a slide in [outline.md](outline.md) once slide numbers are final — keep the mapping in `outline.md` itself (each slide entry names its clip #), not duplicated here.

## Capture notes

- Record at whatever resolution the deck will project at — don't upscale later.
- Trim dead air at the start/end of every clip before dropping it in `media/`; the 5–10s budget is the *usable* clip, not the raw recording.
- Silent/muted clips are fine and often better — narrate live over them rather than relying on clip audio.
