# Presentation

Everything for the live pitch deck lives here, separate from `docs/` (which is the product/tech record, not pitch material).

## Layout

- **[slides.html](slides.html)** — the actual deck. Self-contained HTML, one `<section class="slide">` per slide, each with a slot for an image or short video clip. Open directly in a browser or `npx serve presentation`.
- **[notes/outline.md](notes/outline.md)** — slide-by-slide script: what's on the slide, what gets said, max ~2 sentences per slide. Edit this first when the pitch structure changes, then update `slides.html` to match.
- **[notes/demo-clips.md](notes/demo-clips.md)** — every video/screen-capture clip needed, each capped at 5–10s: what it must show, where it comes from, current status (needed / recorded / cut in).
- **[notes/sources.md](notes/sources.md)** — traceability map back to `docs/idea/` and `docs/tech/research/` for every claim used in the deck, so a fact only has one owning file.
- **[media/](media/)** — actual image/video assets referenced by `slides.html`. Not committed until real clips exist; see `media/README.md` for naming.

## Rule for keeping this in sync with `docs/`

`docs/idea/` and `docs/tech/research/` remain the **source of truth** for the product idea and technical research — they're used for more than the pitch (architecture decisions, event-submission forms, roadmap). Nothing there was moved here.

What *did* move here: `ppt.html` (the root-level placeholder note — it only ever said "we make the ppt in this file" and had no other purpose or references, so it's now `slides.html`).

Everything else in this directory is either new (the deck itself, the clip list) or a **concise pull-quote copy** of pitch-relevant material that already lives in `docs/` — each such copy is logged in `notes/sources.md` with the exact source file/section it came from. If you update the underlying doc (e.g. a market-research number changes, or the brain-dump narrative gets revised), re-sync the corresponding note listed in `sources.md` — don't edit the two independently or they'll drift.
