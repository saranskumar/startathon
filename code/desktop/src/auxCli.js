// Terminal front-end for the DOM tree engine — the same BrowserSession the
// desktop inspector (server.js) drives, printed instead of rendered. Useful
// when a browser window for the inspector itself is one window too many, or
// for piping a snapshot into something else.
//
// No LLM anywhere in this path — ranking is the tier-1 heuristic formula in
// domTreeEngine.js plus a persisted usage-frequency boost (usageStore.js).
// Selecting a navigation item dispatches a real Playwright action; the
// auxiliary tree is then regenerated automatically, but only when
// pageWatcher.js decides a real navigation/state-change happened, per
// docs/tech/research/08-feature-ranking-auxiliary-tree.md §4's "watch the
// effect, don't classify the element" design.
//
// Usage:
//   npm run aux                          (loads code/mock/index.html)
//   npm run aux -- https://example.com
//   npm run aux -- --headless
//   npm run aux -- --once
//   npm run aux -- --json                (one machine-readable scan, then exit)

import { pathToFileURL } from 'node:url';
import path from 'node:path';
import readline from 'node:readline';
import { BrowserSession } from './browserSession.js';

const args = process.argv.slice(2);
const headless = args.includes('--headless');
const once = args.includes('--once');
const json = args.includes('--json');
const target = args.find(a => !a.startsWith('--'));

const defaultMockPath = path.resolve(import.meta.dirname, '../../mock/index.html');
const url = target ?? pathToFileURL(defaultMockPath).href;

function formatFeature(f) {
  const label = f.label ? '"' + f.label + '"' : '(unnamed)';
  const level = f.level ? ' [h' + f.level + ']' : '';
  const flags = [f.isAmbiguous ? 'no-role' : null, f.offscreen ? 'offscreen' : null]
    .filter(Boolean).join(',');
  return '  ' + String(f.rank).padStart(2) + '. [' + f.score.toFixed(2) + '] ' +
    f.role + level + ' ' + label + (flags ? ' (' + flags + ')' : '');
}

function print(state) {
  console.log('\n=== auxiliary tree === ' + state.url);
  console.log('-- Navigation --');
  if (state.navigation.length === 0) console.log('  (none)');
  state.navigation.forEach(f => console.log(formatFeature(f)));
  console.log('-- Information --');
  if (state.information.length === 0) console.log('  (none)');
  state.information.forEach(f => console.log(formatFeature(f)));
  const s = state.stats;
  console.log('   ' + s.keptNodes + ' kept / ' + s.prunedNodes + ' pruned of ' + s.rawNodes +
    ' nodes · ' + state.scanMs + 'ms');
  if (state.ambiguity.needsReview) {
    console.log('-- Tier 1 unsure (a narrow LLM call would go here) --');
    state.ambiguity.reasons.forEach(r => console.log('  ! ' + r));
  }
  console.log('=======================\n');
}

const session = new BrowserSession({ headless: headless && !json ? true : headless });
session.onEvent(event => {
  if (event.type === 'watcher') console.log('\n[pageWatcher] ' + event.detail + ' — regenerating auxiliary tree');
  if (event.type === 'scan' && event.reason === 'watcher') print(session.state);
  if (event.type === 'selection') console.log('Recorded selection of ' + event.signature + ' (seen ' + event.count + 'x).');
  if (event.type === 'act' && !event.ok) console.log('(action failed: ' + event.message + ')');
});

await session.start(url);

if (json) {
  const { raw, ...rest } = session.state;
  console.log(JSON.stringify(rest, null, 2));
  await session.close();
  process.exit(0);
}

print(session.state);

if (once) {
  await session.close();
  process.exit(0);
}

console.log('Watching ' + url);
console.log('Commands: "n<rank>" acts on a Navigation item, "i<rank>" marks an Information item as viewed,');
console.log('Enter to force a re-scan, "q" to quit.');
console.log('An action only re-prints the tree once pageWatcher detects a real navigation/state change.');

const rl = readline.createInterface({ input: process.stdin, output: process.stdout });
rl.on('line', (raw) => {
  // Lines can arrive faster than they are processed (paste, or piped input in
  // tests); the session's own queue serializes them so a "q" cannot race a
  // click that is still in flight.
  session.run(async () => {
    const line = raw.trim();
    if (line === 'q') {
      rl.close();
      await session.close();
      process.exit(0);
    }
    const match = /^([ni])(\d+)$/.exec(line);
    if (match) {
      const bucket = match[1] === 'n' ? 'navigation' : 'information';
      const rank = Number(match[2]);
      const feature = (session.state[bucket] ?? []).find(f => f.rank === rank);
      if (!feature) return console.log('No ' + bucket + ' item ranked ' + rank + '.');
      return session.act({ ref: feature.ref, signature: feature.signature, action: bucket === 'information' ? 'view' : undefined });
    }
    print(await session.scan('manual'));
  }).catch(err => console.log('(failed: ' + err.message + ')'));
});

session.onEvent(event => { if (event.type === 'closed') process.exit(0); });
