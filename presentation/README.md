# Presentation

**KAI — Capability Awareness Interface.** Event template: **5 minutes · 5 slides**, then **5 minutes demo**, then **5 minutes Q&A**. Talk + demo hard-stop at 10:00. Refer to the person as **the user**.

Journey the slides follow: Problem insight → What we tested → Solution / scope → What you can try → What next. Scorecard letters A–D and F are the slide tags; E (team) is Q&A only.

- **[slides.html](slides.html)** — 5 slides, self-contained HTML. Open in a browser or `npx serve presentation`.
- **[notes/outline.md](notes/outline.md)** — spoken script. Edit this first, then match `slides.html`.
- **[notes/demo-clips.md](notes/demo-clips.md)** — live 5-minute demo script (one workflow) and what must be disclosed as simulated.
- **[notes/sources.md](notes/sources.md)** — traceability map back to `docs/idea/` and `docs/tech/research/` for every claim used in the deck, so a fact only has one owning file.
- **[media/](media/)** — actual image/video assets referenced by `slides.html`. Not committed until real clips exist; see `media/README.md` for naming.

## Rule for keeping this in sync with `docs/`

`docs/idea/` and `docs/tech/research/` remain the **source of truth** for the product idea and technical research — they're used for more than the pitch (architecture decisions, event-submission forms, roadmap). Nothing there was moved here.

What *did* move here: `ppt.html` (the root-level placeholder note — it only ever said "we make the ppt in this file" and had no other purpose or references, so it's now `slides.html`).

Everything else in this directory is either new (the deck itself, the clip list) or a **concise pull-quote copy** of pitch-relevant material that already lives in `docs/` — each such copy is logged in `notes/sources.md` with the exact source file/section it came from. If you update the underlying doc (e.g. a market-research number changes, or the brain-dump narrative gets revised), re-sync the corresponding note listed in `sources.md` — don't edit the two independently or they'll drift.
