# 05. Mobile Remote Architecture — Phone ↔ Agent Backend

Research thread for the "Adaptive Capability-Profile Access Layer" build. Scope: the Flutter phone app (`code/app`) is a pure I/O remote — it calibrates the user, composes the adaptive UI, and sends **fused user intent** to a separate AI-agent backend that drives a Playwright browser against the mock target (`code/mock`, deployed to Vercel). This doc covers comms channel, Flutter UI packages, precedent, calibration-data persistence, and a concrete recommendation. Context read: [idea/07-architecture.md](../../idea/07-architecture.md), [tech/README.md](../README.md), [idea/15-brain-dump.md §15.6](../../idea/15-brain-dump.md), `code/app/pubspec.yaml` (currently the unmodified `flutter create` template — no networking, no UI, no speech packages added yet), and `code/mock/` (plain HTML/CSS/JS "Aperture" mock site, Vercel-deployed).

---

## 1. Communication channel: phone ↔ agent backend

**Requirement:** low-latency, two-way — phone sends fused intent (touch selection + voice text), backend pushes back narration/confirmation prompts and results, mid-task, while the agent is running.

| Option | Setup time (30h build) | Two-way / push | Latency | Notes |
|---|---|---|---|---|
| **Raw WebSocket** (`web_socket_channel` on phone + `ws`/`socket.io` or FastAPI `websockets` on backend) | Low — a few hours | Native, symmetric | Lowest | You own the backend anyway (it hosts the Playwright agent), so a WS endpoint on that same process is one extra route, not a new service. |
| HTTP polling | Low, but wrong shape | Client-pull only | High (poll interval) | Wrong fit for "proactive narration" — the whole point of output composition is the agent pushing unprompted updates. Would need short-interval polling to feel live, which is wasteful and janky for a demo. |
| gRPC streaming | Medium-high | Native, symmetric | Low | Needs `.proto` definitions, codegen on both Flutter and backend, and Dart gRPC tooling is less battle-tested for quick hackathon iteration than plain WS. Overkill for a single phone ↔ single backend link. |
| Firebase Realtime DB / Firestore | Low-medium | Push via listeners | Low-medium | Fast to wire (mature Flutter SDK, `cloud_firestore`/`firebase_database` packages), but it's a **data-sync** primitive, not a session/RPC primitive — you'd be modeling "send a command" and "receive narration" as document writes/listeners, plus you need a Firebase project, auth rules, and it adds a third party (Google) in the loop between two machines that are already going to be on the same LAN/tunnel for the demo. |
| Supabase Realtime | Low-medium | Push via Postgres change feed / broadcast channels | Low-medium | Same shape as Firebase but Postgres-backed; `supabase_flutter` package is solid. Same objection: you're bending a DB-sync tool into an RPC channel when the backend process can just open a socket directly. |

**Verdict: Strong feasibility — raw WebSocket.** The backend already has to run a persistent Node/Python process to drive Playwright, so it can trivially also host a WebSocket endpoint that the phone connects to directly. This avoids provisioning any third-party realtime service, avoids auth/rules setup, and gives true bidirectional push with the least moving parts. Firebase/Supabase Realtime become *more* attractive only if the team later wants durable multi-session history or wants to decouple phone and agent-backend uptime — not needed for a live single-session demo. Use `web_socket_channel` (pub.dev, tools.dart.dev-published, 1.64k likes, 150 pub points) on the Flutter side; a plain `ws`/`socket.io` (Node) or `websockets`/FastAPI (Python) server alongside the Playwright agent process on the backend.

---

## 2. Flutter packages for adaptive UI primitives

| Need | Package | Maturity / last updated | Notes |
|---|---|---|---|
| Virtual joystick | [`flutter_joystick`](https://pub.dev/packages/flutter_joystick) | v0.2.2, 150 pub points, 68 likes, last published ~17 months ago | Provides `Joystick` and `JoystickArea` widgets, snapping to circular/rectangular bases, customizable decoration. Small package, low likes, but does exactly the primitive needed and is simple enough to fork/patch in a pinch if a bug surfaces. |
| Draggable trackpad-style pointer surface | No dedicated pub.dev package found that matches "relative-drag trackpad" exactly. | — | Build directly on Flutter's own `GestureDetector`/`Listener` with `onPanUpdate`, translating drag deltas into relative cursor-move messages. This is genuinely a ~30-40 line custom widget (a `Container` + `GestureDetector` tracking cumulative `Offset` deltas) — not worth a dependency. Flutter's built-in `PointerDeviceKind.trackpad` handling (via `ScrollBehavior.dragDevices`) is for physical trackpad *input* to the phone, not what's needed here (rendering a trackpad *surface* for the user to drag a finger across), so it doesn't reduce the work. |
| Calibration / target-acquisition test UI | No dedicated pub.dev package. | — | This is inherently custom (show N targets at varying sizes/positions, time-to-acquire, hit/miss, jitter) — no package abstracts "accessibility calibration mini-games." Build with basic `Stack` + `AnimatedPositioned`/`GestureDetector` targets; track timestamps and hit accuracy in local state, write results into the capability profile. |
| Speech-to-text | [`speech_to_text`](https://pub.dev/packages/speech_to_text) | v7.4.0, 150 pub points, 1.62k likes, 523k weekly downloads, published ~3 months ago | Actively maintained, wraps native on-device recognition (Android `SpeechRecognizer`, iOS `SFSpeechRecognizer`). Supports Android/iOS/macOS/Web/Windows for speech (Linux build-only, no recognition). Good fit — on-device, no separate STT API key needed for the phone side, matches the "not yet decided" STT question in tech/README.md by giving a zero-cost default. |
| Text-to-speech | [`flutter_tts`](https://pub.dev/packages/flutter_tts) | v4.2.5, 150 pub points, 1.6k likes, published ~8 months ago | Actively maintained, wraps native TTS (Android/iOS/macOS/Web/Windows). Matches "voice output: some TTS engine, not yet chosen" — this is the lowest-effort default (no API key, on-device synthesis) though voice quality is platform-default rather than a premium cloud voice. |

**Verdict: Strong feasibility for joystick/STT/TTS** (all real, maintained pub.dev packages with straightforward APIs); **Moderate feasibility for trackpad and calibration UI**, since both require custom widget code — not a blocker, but budget real build hours for them rather than assuming a package handles it. None of the four are "solved and forget" — even `flutter_joystick`'s low like-count means allocate a fallback plan (a raw `GestureDetector`-based joystick is also trivial to hand-roll if the package proves awkward).

---

## 3. Precedent: phone-as-adaptive-input-remote controlling a separate surface

- **AT&T U-verse app / similar TV remote apps** — phone as remote control for a separate execution surface (the TV/set-top box) is an extremely well-trodden *consumer* pattern (AT&T, Google Home, Roku, etc.), but these are simple command-relay remotes, not adaptive/profile-driven ones — no calibration step, no capability-profile-driven composition. Useful only as proof that "phone sends commands over network to a box that does the real work" is a mature, low-risk architectural shape; not useful for the adaptive-input angle.
- **Sesame Enable / "Open Sesame"** (Tel Aviv, founded 2013) — touch-free control of the *phone itself* using head-tracking via the front camera, letting users with limited hand mobility operate an Android phone hands-free. This is the closest accessibility precedent for "camera/motion-driven input calibrated to the user," but it controls the phone directly rather than acting as a remote for a separate machine — so it validates the calibration-and-adapt half of this project's idea, not the phone-as-remote-controlling-a-computer half.
- **Google Switch Access** — established pattern for scanning/switch-based control of a device, including over Bluetooth switches; conceptually closest to the "single-switch scanning" fallback flagged as an open thread in the brain-dump (§15.7), but again controls the local device, not a remote one.
- No public precedent was found that is architecturally identical to this project: "phone runs calibration + composes an adaptive UI, then a *separate* AI agent on a different machine executes the task and streams narration back." This appears to be a genuinely novel combination (profile-driven adaptive input + remote AI-agent execution), which is worth stating plainly in the pitch — it is not "a known pattern implemented," it's a new composition of two known patterns (accessible input calibration + agent-driven browser automation).

**Verdict: Weak feasibility for finding a directly reusable reference architecture** — nothing to copy wholesale. **Moderate feasibility as validation**: the sub-patterns (phone-as-remote for a separate device; calibrated/adaptive local input) are each independently proven, which de-risks the *concept* even though no single existing app proves the *combination*.

---

## 4. Calibration data persistence

`tech/README.md` flags this explicitly as "not yet decided": local storage vs. a backend.

| Option | Setup effort | Fit |
|---|---|---|
| `shared_preferences` | Minutes | Official Flutter-team package (2.5.5, 160 pub points, 10.6k likes, actively maintained). Fine for a handful of scalar values, but the capability profile shown in the architecture diagram (touch method scores, zone, size, steadiness, max_controls, speech clarity, vision mode) is a nested object — shared_preferences stores only primitives/strings, so it'd mean hand-serializing to a JSON string, which works but is a code smell for structured data. |
| `Hive` | Low, but **stale**: latest stable 2.2.3 was published ~4 years ago; pub.dev's own listing now points users toward Isar for new projects. Not disqualifying for a 30-hour throwaway build, but not the package to bet on if anything breaks and needs a fix mid-hackathon. |
| Just encode the profile as JSON and write it with `shared_preferences` (`setString('profile', jsonEncode(profile))`) | Minutes | This sidesteps the "which local DB" question entirely — one key, one JSON blob, trivial to version/reset by clearing the key. Effectively free serialization since the profile is already a Dart object with a natural `toJson`/`fromJson`. |
| Firebase / Supabase backend persistence | Medium (project setup, schema/rules, auth) | Only worth it if calibration must survive app reinstall/device swap, or multiple team members need to view/compare profiles centrally during the demo. Neither is a stated requirement — calibration happens "once, per user," on that user's own phone, immediately before the demo run. |

**Verdict: Strong feasibility for the lean path.** There is no real product requirement forcing a backend here — the profile only needs to persist across the calibration screen and the task screen on the *same device* in the *same demo session*. `shared_preferences` storing one JSON-encoded profile string is the simplest correct answer and resolves the "not yet decided" item with the least code. Skip Hive (stale) and skip a backend DB (unnecessary network dependency for a value that only the local phone needs to read).

---

## 5. Concrete recommendation for the hackathon build

**Leanest realistic stack, given the existing skeleton (`code/app` is still the default `flutter create` template — nothing added yet) and the mock UI (`code/mock`, Vercel-deployed per `tech/README.md`):**

- **Comms:** `web_socket_channel` on the phone, talking directly to a WebSocket route added to whatever process hosts the Playwright agent (Node or Python — match whatever the agent backend ends up being built in). No Firebase/Supabase — the agent backend is already a long-lived server process, so this is zero extra infrastructure.
- **Adaptive UI:**
  - Buttons: plain Flutter widgets, no package.
  - Joystick: `flutter_joystick`.
  - Trackpad: hand-rolled `GestureDetector`/`onPanUpdate` widget (~30-40 lines).
  - Calibration/target-acquisition test screens: hand-rolled (`Stack` + timed targets), no package exists for this.
  - Voice input: `speech_to_text`.
  - Voice output/narration: `flutter_tts`.
- **Persistence:** `shared_preferences`, one JSON-encoded capability-profile blob, keyed per local device (no backend DB).
- **Networking beyond WS:** none needed — the mock target site is driven by the agent's Playwright browser on the backend machine, not by the phone directly, so the phone never talks to `code/mock`/Vercel at all; it only talks to the agent backend over the WebSocket.

**Biggest integration risk to flag:** the WebSocket link is the single point where three independently-built pieces (Flutter phone app, agent backend logic, Playwright browser automation) have to agree on a message contract (what "fused user intent" looks like as JSON, what "narration/confirmation" messages look like coming back) — and per `tech/README.md`'s stated build order, phone UI work (step 2) happens *after* browser/agent automation (step 1), meaning the message schema will likely be designed once around the agent's needs and then the phone has to conform to it under time pressure. Nail down and write down the WS message schema (event names + JSON shape for both directions) as the very first artifact of the networking work, before either side is deep into implementation, so the two halves don't drift and require a late rewrite to reconcile. Secondary risk: network reachability between the phone (real device, likely on venue WiFi) and the backend machine (a laptop on the same network) — test the actual phone-to-laptop WS connection early (e.g., over a shared hotspot or `ngrok`/similar tunnel as fallback) rather than assuming it "just works" on demo day.

---

## Sources

- [pub.dev — web_socket_channel](https://pub.dev/packages/web_socket_channel)
- [pub.dev — flutter_joystick](https://pub.dev/packages/flutter_joystick)
- [pub.dev — speech_to_text](https://pub.dev/packages/speech_to_text)
- [pub.dev — flutter_tts](https://pub.dev/packages/flutter_tts)
- [pub.dev — shared_preferences](https://pub.dev/packages/shared_preferences)
- [pub.dev — hive](https://pub.dev/packages/hive)
- [Flutter docs — Communicate with WebSockets](https://docs.flutter.dev/cookbook/networking/web-sockets)
- [Flutter docs — Taps, drags, and other gestures](https://docs.flutter.dev/ui/interactivity/gestures)
- [Flutter docs — Trackpad gestures breaking change](https://docs.flutter.dev/release/breaking-changes/trackpad-gestures)
- [Sesame Enable / Open Sesame — Accessibility Services](https://accessibilityservices.com/open-sesame/)
- [Sesame Enable overview — ABILITY Magazine](https://abilitymagazine.com/sesame-enable/)
- [Google Play — Switch Access](https://play.google.com/store/apps/details/Switch+Access?id=com.google.android.accessibility.switchaccess&hl=en_US)
- [AT&T U-verse Easy Remote for Android — User Guide](https://www.att.com/media/att/2013/support/pdf/easy_remote_android_user_guide.pdf)
- [Medium — Supabase vs Firebase for Flutter (2025)](https://medium.com/@sparklewebhelp/supabase-vs-firebase-for-flutter-which-one-should-you-pick-in-2025-ef8310c75114)
- [Flutter Gems — Voice Assistant, ASR, TTS & STT category](https://fluttergems.dev/packages/flutter_tts/)
