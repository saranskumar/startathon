// Node-side half of new-page/state-change detection
// (docs/tech/research/08-feature-ranking-auxiliary-tree.md §4). Wires up
// pageWatcher.client.js inside the page and forwards its two signals —
// a history-API navigation, or a MutationObserver-detected major DOM
// change — to a single onChange callback, so the caller can decide when
// to regenerate the auxiliary tree instead of doing it on a fixed timer
// or after every single interaction regardless of whether anything
// page-shaped actually happened.

import path from 'node:path';

const CLIENT_SCRIPT = path.resolve(import.meta.dirname, './inject/pageWatcher.client.js');

/**
 * @param page - a Playwright Page, not yet navigated (call before page.goto()).
 * @param onChange - ({ trigger: 'history'|'dom-mutation', ...details }) => void
 */
export async function attachPageWatcher(page, onChange) {
  await page.exposeFunction('__onNavEvent', (type, href) => {
    onChange({ trigger: 'history', type, href });
  });
  await page.exposeFunction('__onMajorChange', (fingerprintJson) => {
    onChange({ trigger: 'dom-mutation', fingerprint: JSON.parse(fingerprintJson) });
  });
  await page.addInitScript({ path: CLIENT_SCRIPT });
}
