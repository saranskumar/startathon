// One Playwright-controlled browser, wrapped so every consumer — the CLI
// (auxCli.js), the desktop inspector (server.js), and the phone-facing API
// that comes next — drives it through the same object instead of each
// re-implementing launch/scan/act.
//
// The contract is deliberately small and transport-agnostic: goto, scan, act,
// screenshot, plus an event stream. Turning this into an HTTP/WebSocket API is
// then a matter of mapping routes onto these five methods, not restructuring
// anything.

import { chromium } from 'playwright';
import { buildAuxiliaryTree } from './domTreeEngine.js';
import { loadUsageCounts, recordSelection } from './usageStore.js';
import { loadRankingModel, recordRankingExample } from './rankingModel.js';
import { attachPageWatcher } from './pageWatcher.js';

const DEFAULT_VIEWPORT = { width: 1280, height: 720 };

export class BrowserSession {
  constructor({ headless = false, viewport = DEFAULT_VIEWPORT, limit = 12 } = {}) {
    this.headless = headless;
    this.viewport = viewport;
    this.limit = limit;
    this.browser = null;
    this.page = null;
    this.state = null;
    // Root scan buckets before any group drill-in. Focus stack holds opened
    // groups so act({ action: 'open' }) / back can change the visible list
    // without touching the page.
    this.rootNavigation = null;
    this.rootInformation = null;
    this.focusStack = [];
    this.listeners = new Set();
    this.log = [];
    // Serializes everything that touches the page. Without it a scan triggered
    // by the watcher can land mid-navigation and throw, or two clicks from the
    // UI can interleave.
    this.queue = Promise.resolve();
    this.scanCounter = 0;
  }

  onEvent(listener) {
    this.listeners.add(listener);
    return () => this.listeners.delete(listener);
  }

  emit(event) {
    const entry = { ...event, at: Date.now() };
    this.log.push(entry);
    if (this.log.length > 200) this.log.shift();
    for (const listener of this.listeners) {
      try { listener(entry); } catch { /* a dead SSE client must not break the session */ }
    }
  }

  /** Run fn with exclusive access to the page. */
  run(fn) {
    const next = this.queue.then(fn, fn);
    // Keep the chain alive after a rejection so one failed action doesn't
    // wedge every later one.
    this.queue = next.then(() => {}, () => {});
    return next;
  }

  async start(url) {
    this.browser = await chromium.launch({ headless: this.headless });
    const context = await this.browser.newContext({ viewport: this.viewport });
    this.page = await context.newPage();

    // Must be installed before the first navigation — addInitScript only
    // applies to documents loaded after it is registered.
    await attachPageWatcher(this.page, (event) => this.handleWatcherEvent(event));

    this.browser.on('disconnected', () => this.emit({ type: 'closed' }));
    this.page.on('framenavigated', (frame) => {
      if (frame === this.page.mainFrame()) this.emit({ type: 'navigated', url: frame.url() });
    });

    await this.goto(url);
    return this;
  }

  // Regenerate only when pageWatcher says something page-shaped actually
  // happened, not on a fixed timer and not just because a click occurred.
  // Debounced against duplicate signals (a real router commonly fires both a
  // history event and a matching DOM mutation for one navigation).
  handleWatcherEvent(event) {
    const now = Date.now();
    if (now - (this.lastTriggerAt ?? 0) < 250) return;
    this.lastTriggerAt = now;
    this.emit({ type: 'watcher', trigger: event.trigger, detail: describeTrigger(event) });
    this.run(() => this.scan('watcher')).catch(err =>
      this.emit({ type: 'error', message: 'rescan failed: ' + err.message }));
  }

  async goto(url) {
    this.emit({ type: 'goto', url });
    await this.page.goto(url, { waitUntil: 'domcontentloaded' });
    return this.scan('goto');
  }

  /**
   * Read the raw accessibility tree and rank it. The raw tree is kept
   * alongside the ranked output — the inspector shows both, and "what did the
   * engine throw away" is only answerable with both in hand.
   */
  async scan(reason = 'manual') {
    const startedAt = Date.now();
    const raw = await this.page.ariaSnapshotJSON({ mode: 'ai', boxes: true });
    const usageCounts = loadUsageCounts();
    // Retrained offline (see rankingModel.js's trainAndSaveRankingModel) --
    // loaded fresh each scan so a newly-trained model takes effect on the
    // next page read without restarting the session. Null until something
    // has actually been trained; buildAuxiliaryTree treats that as a no-op.
    const rankingModel = loadRankingModel();
    const aux = buildAuxiliaryTree(raw, {
      usageCounts,
      rankingModel,
      limit: this.limit,
      viewport: this.viewport,
    });

    this.rootNavigation = aux.navigation;
    this.rootInformation = aux.information;
    this.focusStack = [];

    this.state = {
      id: ++this.scanCounter,
      reason,
      url: this.page.url(),
      title: await this.page.title().catch(() => ''),
      viewport: this.viewport,
      raw,
      usageCounts,
      scanMs: Date.now() - startedAt,
      at: Date.now(),
      focus: [],
      ...aux,
    };
    this.emit({ type: 'scan', reason, id: this.state.id, ms: this.state.scanMs, stats: aux.stats });
    return this.state;
  }

  /** Visible breadcrumb of opened groups (labels only). */
  focusPath() {
    return this.focusStack.map(g => g.label ?? g.name ?? 'group');
  }

  /**
   * Re-expose a group's members as the current Navigation (or Information)
   * list. No Playwright call — only the choice set changes.
   */
  openGroup(feature, bucket = 'navigation') {
    if (!feature?.isGroup) throw new Error('not a group');
    const members = (feature.members ?? []).map((f, i) => ({ ...f, rank: i + 1 }));
    this.focusStack.push({ ...feature, bucket });
    if (bucket === 'information') this.state.information = members;
    else this.state.navigation = members;
    this.state.focus = this.focusPath();
    this.emit({
      type: 'focus',
      action: 'open',
      label: feature.label,
      depth: this.focusStack.length,
      focus: this.state.focus,
    });
    return this.state;
  }

  /** Pop one group focus level, or return to the root buckets. */
  backFocus() {
    if (!this.state) throw new Error('no scan yet');
    if (this.focusStack.length === 0) return this.state;

    this.focusStack.pop();
    if (this.focusStack.length === 0) {
      this.state.navigation = this.rootNavigation;
      this.state.information = this.rootInformation;
    } else {
      const top = this.focusStack[this.focusStack.length - 1];
      const members = (top.members ?? []).map((f, i) => ({ ...f, rank: i + 1 }));
      if (top.bucket === 'information') this.state.information = members;
      else this.state.navigation = members;
    }
    this.state.focus = this.focusPath();
    this.emit({
      type: 'focus',
      action: 'back',
      depth: this.focusStack.length,
      focus: this.state.focus,
    });
    return this.state;
  }

  /**
   * Locate a feature from the last scan. `aria-ref` is exact (it addresses the
   * very node the snapshot described) but only valid until the next snapshot;
   * identity then signature are stable across snapshots. Try the precise one
   * first, fall back to the stable ones.
   */
  locate(feature) {
    if (feature.ref) return this.page.locator('aria-ref=' + feature.ref);
    if (feature.name) {
      // Prefer an exact role+name match; when the page repeats a label the
      // first match may be wrong — identity is carried for callers that need
      // disambiguation, but Playwright has no identity selector, so name is
      // still the fallback.
      return this.page.getByRole(feature.role, { name: feature.name, exact: true }).first();
    }
    throw new Error('feature has neither a ref nor a name to locate it by');
  }

  findFeature({ ref, signature, identity, bucket, rank }) {
    if (!this.state) throw new Error('no scan yet');
    const all = [
      ...this.state.navigation,
      ...this.state.information,
      ...flattenGroups(this.rootNavigation ?? []),
      ...flattenGroups(this.rootInformation ?? []),
    ];
    if (ref) {
      const found = all.find(f => f.ref === ref) ?? findInTree(this.state.tree, f => f.ref === ref);
      if (found) return found;
    }
    if (identity) {
      const found = all.find(f => f.identity === identity);
      if (found) return found;
    }
    if (signature) {
      const found = all.find(f => f.signature === signature);
      if (found) return found;
    }
    if (bucket && rank) {
      const found = (this.state[bucket] ?? []).find(f => f.rank === Number(rank));
      if (found) return found;
    }
    throw new Error('no feature matched ' + JSON.stringify({ ref, signature, identity, bucket, rank }));
  }

  /**
   * Dispatch a real interaction — or open/back a group without touching the
   * page. The auxiliary tree is NOT regenerated on page acts: that is
   * pageWatcher's job (docs/tech/research/08 §4).
   */
  async act({ ref, signature, identity, bucket, rank, action, value }) {
    if (action === 'back') {
      this.backFocus();
      return { feature: null, verb: 'back', ok: true };
    }

    const feature = this.findFeature({ ref, signature, identity, bucket, rank });
    const verb = action ?? feature.action ?? 'click';

    if (verb === 'open' || feature.isGroup) {
      this.openGroup(feature, bucket ?? 'navigation');
      return { feature, verb: 'open', ok: true };
    }

    if (feature.signature) {
      const count = recordSelection(feature.signature);
      this.emit({ type: 'selection', signature: feature.signature, count });
      // The picked feature is a positive example; every other candidate
      // shown in the same scan (same bucket) is a negative -- a full
      // training batch out of one real selection, no extra instrumentation.
      const candidates = bucket ? (this.state?.[bucket] ?? []) : [
        ...(this.state?.navigation ?? []), ...(this.state?.information ?? []),
      ];
      if (candidates.length > 1) {
        recordRankingExample(feature, candidates.filter(c => !c.isGroup));
      }
    }

    if (verb === 'view') {
      this.emit({ type: 'act', verb, name: feature.label ?? feature.name, role: feature.role, ok: true });
      return { feature, verb, ok: true };
    }

    const locator = this.locate(feature);
    try {
      if (verb === 'fill') await locator.fill(String(value ?? ''), { timeout: 5000 });
      else if (verb === 'check') await locator.setChecked(value !== false, { timeout: 5000 });
      else if (verb === 'select') await locator.selectOption(String(value ?? ''), { timeout: 5000 });
      else if (verb === 'set') await locator.fill(String(value ?? ''), { timeout: 5000 });
      else await locator.click({ timeout: 5000 });
      this.emit({ type: 'act', verb, name: feature.label ?? feature.name, role: feature.role, ok: true });
      return { feature, verb, ok: true };
    } catch (err) {
      this.emit({ type: 'act', verb, name: feature.label ?? feature.name, role: feature.role, ok: false, message: err.message });
      return { feature, verb, ok: false, error: err.message };
    }
  }

  async screenshot() {
    return this.page.screenshot({ type: 'png' });
  }

  async close() {
    if (this.browser?.isConnected()) await this.browser.close();
  }
}

export function describeTrigger(event) {
  if (event.trigger === 'history') return 'history.' + event.type + ' -> ' + event.href;
  const changed = event.fingerprint?.changed ?? [];
  const what = changed.length ? changed.join(', ') : 'DOM';
  const now = event.fingerprint?.heading || event.fingerprint?.title || '';
  return 'new screen — ' + what + ' changed' + (now ? ' (now "' + now + '")' : '');
}

function findInTree(nodes, predicate) {
  for (const node of nodes ?? []) {
    if (predicate(node)) return node;
    const found = findInTree(node.children, predicate);
    if (found) return found;
  }
  return null;
}

function flattenGroups(items) {
  const out = [];
  for (const item of items ?? []) {
    out.push(item);
    if (item.isGroup) out.push(...flattenGroups(item.members));
  }
  return out;
}
