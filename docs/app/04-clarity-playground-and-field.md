# 04 — Option clarity, field overlay, section highlight, playground

Planning note for the next phone-app pass. **Issue #20 is already shipped** (`f6aa6bb`, Live discrete paging + Floor dwell). This doc records the follow-on work and the extra requirements that came with it.

**Status:** implemented (overlay passthrough, shared selection cells, Live highlight for pick/fill/confirm, gear-menu Playground hub). Issue #20 paging/dwell unchanged.

**Code today:** `code/app/lib/live/` (Live lists), `runtime/discrete_view.dart` (paging + joystick section highlight), `vision/field_shell.dart` (tunnel / peripheral veil), `runtime/preview_screen.dart` (post-calibration controller preview), `main.dart` settings sheet.

---

## 1. Button / option clarity

**Problem:** On Live (and any dense discrete grid), users cannot tell what they are selecting. Seat buttons clip to `"Se"`, and the focused region does not make the *current option* obvious. The same ambiguity shows up on calibration / demo / runtime screens whenever many options share a narrow grid.

**Planned fix (match existing language — no new visual system):**

- Labels must stay readable: wrap or grow the cell, never clip to two letters.
- Visible option count stays profile-derived (`visibleOptionCount` / `visibleCountForHeight`) so targets stay large enough for the text.
- The **focused / selected option** gets the same highlight language already used for joystick focus (border + contrast), not a second affordance style.
- Apply across Live, calibration, demo, and runtime discrete surfaces that share the option-list helper.

Issue #20 already caps Live pages so labels *can* fit. This item is the remaining layout/affordance work so users can actually read each option and see which one is current.

---

## 2. Tunnel vision overlay — removed for now, further scope

**Now:** Remove the tunnel-vision overlay (yellow square + dimmed outside) from `field_shell.dart` / Live / demo chrome. It is confusing as a scan highlight and is not the real field-loss layout.

**Later (not this pass):** Re-implement tunnel vision as a **layout**, not a dimming veil. Once it exists:

- All buttons, text, and options live **inside that square**.
- Nothing important is spread across the rest of the screen.
- The square is the working window, not a spotlight over a full-screen grid.

That matches [tech/research/14](../tech/research/14-visual-field-loss-tunnel-and-peripheral-vision.md) (condense into one region, spatial continuity). Peripheral / central-loss mode stays roadmap too. Calibration may still *record* `visualField`; the overlay is just not shown until the real layout ships.

---

## 3. Section highlighting for every input mode

**Today:** Joystick mode highlights the active section when the user switches sections. Other modes (switch scan, voice, hold, trackpad, vision, buttons) do not reuse that highlight.

**Planned:** Use the **existing joystick section-highlight implementation** as the single system. When any mode’s active section changes, the same highlight paints that section. Do not invent a parallel overlay (and do not reuse the removed tunnel veil for this).

---

## 4. Playground mode (gear menu)

The post-calibration Preview (“Your controllers”) stays. This is a **new** entry from the gear / settings sheet.

**Flow:**

1. Settings (gear) → **Playground**.
2. A normal menu: **2-wide grid of cards**, one card per input mode (illustration + name).
3. Opening a card offers **Calibration** or **Demo**.
4. **Calibration** reuses the existing step for that mode.
5. **Demo** is a lightweight, clearly labeled options list that demonstrates that input method only — not the full calibration flow and not the full task chain.

Wire into existing navigation, calibration, and input-mode infrastructure.

---

## 5. Issue #20 — Live discrete lists (already decided / shipped)

On the **phone Live UI** (RailLink-driven), long discrete lists (especially the seat map) showed too many buttons and clipped labels.

Locked decisions (keep):

- **Scope: Live only.** Offline demo discrete lists stay as they are unless they share a helper that must stay Live-gated.
- Cap size is **dynamic** from target size / reach / profile — not a single hard-coded 6.
- Remaining options **auto-advance to the next page** after a full scan/pass over the current page (manual More is not enough).
- Floor switch-scan dwell is ~**2.5s** per step (clearly slower than the old ~1.6s).

Acceptance (code already aims at these):

- Seat map and other large Live discrete screens do not clip option text.
- On-screen option count respects the profile-derived cap.
- After a finished page (scan pass / equivalent), the next page appears automatically.
- Floor preset switch dwell is noticeably slower (~2.5s).

The clarity work in §1 finishes the “never clips / user can tell what they are selecting” part on the surfaces that still look like the clipped seat grid.

---

## 6. Out of this pass

- Real tunnel-vision / peripheral layout (§2 later).
- Agent filling a real form / laptop wire (still out of scope; demo still logs locally).
- New illustration style — reuse existing assets or simple placeholders that match the app.
