# Agent backend

The "read the tree" half of build-order step (1) in [docs/tech/README.md](../../docs/tech/README.md) —
see [docs/tech/research/04-agent-execution-layer.md](../../docs/tech/research/04-agent-execution-layer.md)
for the design rationale (Playwright accessibility snapshot, no general agent framework).

Not an API/server yet — just a script that launches a Playwright-controlled Chromium instance, loads a
page, and prints its accessibility tree so the tree shape can be inspected against the real mock UI
([code/mock/](../mock/)) before the LLM matching + confirm/dispatch loop is built on top of it.

## Setup

```bash
npm install
npx playwright install chromium
```

## Usage

```bash
npm run snapshot                          # loads code/mock/index.html, headed browser
npm run snapshot -- https://example.com   # snapshot an arbitrary URL instead
npm run snapshot -- --headless            # no visible browser window
npm run snapshot -- --once                # snapshot once and exit (no watch loop)
```

By default it stays open: interact with the mock UI in the opened browser window (switch demo mode,
open a card, change tabs), then press Enter in the terminal to re-snapshot and see the tree update.
Type `q` + Enter to quit.

The snapshot uses `page.ariaSnapshot({ mode: 'ai' })` — the same primitive Playwright MCP's
`browser_snapshot` uses — giving a YAML role/name tree with `[ref=eN]` node references, ready to feed
to an LLM tool-call step later.
