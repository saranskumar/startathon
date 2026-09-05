// Standalone accessibility-tree viewer — build order step 1 in
// docs/tech/README.md ("browser/agent automation") and the loop shape
// recommended in docs/tech/research/04-agent-execution-layer.md §5.
//
// Launches a Playwright-controlled Chromium instance, loads a target
// page (defaults to the Aperture mock UI), and prints its accessibility
// tree (role/name/value/children) to the terminal. Not wired up as an
// API/server yet — this is just the "read the tree" half of the loop,
// run directly so the tree shape can be inspected while the mock UI's
// screens/widgets are exercised by hand.
//
// Usage:
//   npm run snapshot                          (loads code/mock/index.html)
//   npm run snapshot -- https://example.com
//   npm run snapshot -- --headless
//   npm run snapshot -- --once                (snapshot once, then exit)

import { chromium } from 'playwright';
import { pathToFileURL } from 'node:url';
import path from 'node:path';
import readline from 'node:readline';

const args = process.argv.slice(2);
const headless = args.includes('--headless');
const once = args.includes('--once');
const target = args.find(a => !a.startsWith('--'));

const defaultMockPath = path.resolve(import.meta.dirname, '../../mock/index.html');
const url = target ?? pathToFileURL(defaultMockPath).href;

async function printSnapshot(page) {
  // Same primitive Playwright MCP's `browser_snapshot` uses (see
  // docs/tech/research/04-agent-execution-layer.md) — YAML role/name tree
  // with [ref=eN] node references, ready for an LLM tool-call step later.
  const tree = await page.ariaSnapshot({ mode: 'ai' });
  console.log('\n--- accessibility tree ---');
  console.log(tree || '(empty — page may be blank or not yet loaded)');
  console.log('--------------------------\n');
}

const browser = await chromium.launch({ headless });
const page = await browser.newPage();
await page.goto(url);
await printSnapshot(page);

if (once) {
  await browser.close();
  process.exit(0);
}

console.log(`Watching ${url}`);
console.log('Interact with the page in the opened browser window, then press Enter here to re-snapshot ("q" + Enter to quit).');

const rl = readline.createInterface({ input: process.stdin, output: process.stdout });
rl.on('line', async (line) => {
  if (line.trim() === 'q' || page.isClosed() || browser.isConnected() === false) {
    rl.close();
    if (browser.isConnected()) await browser.close();
    process.exit(0);
  }
  try {
    await printSnapshot(page);
  } catch (err) {
    console.log(`(snapshot failed: ${err.message})`);
  }
});

browser.on('disconnected', () => process.exit(0));
