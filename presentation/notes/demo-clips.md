# Demo — 5 minutes (live) + slide 1 clips

Event split: 5 min slides + 5 min demo. Q&A starts at 10:00.

**Product:** KAI — Capability Awareness Interface.

## Slide 1 clips (current systems — Problem insight)

These are **not** the product demo. They exist so judges see why TalkBack / Voice Access fail a user with overlapping motor + speech limits.

| File | Length | Must show |
|---|---|---|
| `presentation/media/02-talkback.mp4` | 5–8s | TalkBack working for a sighted/motor-OK path (swipes, explore-by-touch), then the same gesture failing if the hand cannot land the swipe. |
| `presentation/media/03-voice-access.mp4` | 5–8s | Voice Access needing a clear command; then a slurred / slow / incomplete phrase that the tool misses or times out. |

Play under the **Gap** row on slide 1. Do not narrate over the whole clip — one sentence before, one after.

If clips are not ready, **do the same contrast live** on a spare phone: one clean swipe, then “he cannot land that”; one clear command, then “his speech is not recognized.” Faster than a missing file.

Hardware (MouthPad, foot trackball): **say it**, do not demo it. Photo optional. Point: extra devices exist; we use the phone he already has.

Brother photo: `presentation/media/01-origin.jpg` (wired on slide 1; omitted if the file is missing).

## Live product demo (5 min)

**One workflow.** Do not tour features.

1. Phone calibration (or a preset matching him: large targets, one reachable region, partial speech). Name the skip if you use a preset. **Show more than one input mode** (calibration results + buttons, then stick or switch).
2. One complete task: discrete choice → confirm, then text (touch selects, simulated voice fills). Show confirm + interrupt.
3. Optional, if time: laptop on one `code/mock` page. Ranked actions, one real click. Say whether the phone relay is driving this run.

## Say once, at the start of the product demo

| Status | What |
|---|---|
| Simulated | Speech recognition (`SimulatedSpeechSource`) |
| Not the 30-hour product | Full on-device accessible phone OS; trained ASR; native OS app control |
| Self-built | Aperture Daily mocks — not WhatsApp, not a live third-party app |
| Functional | Setup (tap/hold), caregiver training, calibration, profile, 4×4 input matrix, fusion UI, desktop ranking + act, demo relay |

Backup if live calibration fails: recorded calibration, then live task views.
