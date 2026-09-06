# Phone app — feature record and Expo port

The Flutter phone app lives in [`code/app/`](../../code/app/). This folder is the **feature record** of that app: what it actually does, how adaptation works, and how the same product should be rebuilt in Expo without repeating Flutter’s combinatorial trap.

| Doc | Covers |
|---|---|
| [01 — Feature inventory](01-feature-inventory.md) | Every screen, calibration step, input surface, task pattern, theme, and stub |
| [02 — Adaptation is not a screen gallery](02-adaptation-vs-screens.md) | Why you do **not** design every user variant in Flutter (or Expo) |
| [03 — Expo port map](03-expo-port.md) | What to copy as data/logic, what to rebuild as UI, suggested layout |
| [04 — Clarity, field, highlight, playground](04-clarity-playground-and-field.md) | Planned: readable options, remove tunnel overlay (layout later), section highlight for all modes, gear-menu Playground |

Wireframes of the locked flow: [desgin/ui-ux-phone-flow.md](../desgin/ui-ux-phone-flow.md). Voice/text classification: [desgin/desgin.md](../desgin/desgin.md). Product model: [idea/02-core-model.md](../idea/02-core-model.md) and [idea/03-input-calibration.md](../idea/03-input-calibration.md).

---

## Direct answer

**You are wrong that adapting to users means designing each and every interface in Flutter.**

The product is a **capability profile plus a small runtime that composes primitives**. Calibration measures a person. The runtime then:

1. picks **which input surface** (buttons / joystick / trackpad / switch / voice)
2. applies **continuous layout knobs** (target size, reach zone, text scale, option count, field mask)
3. uses that surface’s **native pattern** for the current task shape

You design those primitives and knobs **once**. You do not design a unique Flutter screen for Profile A, another for Profile B, another for tunnel vision, another for Malayalam, and so on.

**Current follow-on plan** (not built yet): [04](04-clarity-playground-and-field.md). Option labels must stay readable and the focused option obvious; the tunnel-vision *overlay* is being removed and the real tunnel layout (everything inside one square) is further scope; section highlighting should follow the joystick implementation for every input mode; Playground is a new gear-menu entry with a 2-wide mode grid, then Calibration or a lightweight Demo. Issue #20 (Live paging + Floor ~2.5s dwell) is already shipped.

Flutter feels brittle because the current app **did** encode a lot of that as hand-written `switch` trees inside each task view (the 4 task shapes × 4 methods matrix). That is an implementation smell, not a requirement of the idea. Expo will be just as brittle if we port that matrix as 16 screens. It will flex if we port the **profile + primitives + mapping** instead.

See [02](02-adaptation-vs-screens.md).
