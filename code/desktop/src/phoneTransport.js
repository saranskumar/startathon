// The phone↔agent transport flagged as "still unstarted" in docs/tech/README.md
// ("Built so far (desktop side)"), designed per
// docs/tech/research/05-mobile-remote-architecture.md §1's verdict: a raw
// WebSocket on the same process that already hosts the Playwright session,
// not a third-party realtime service. This is the seam
// docs/idea/29-phone-desktop-integration.md calls "connecting the DOM thing to
// the input thing" — everything domTreeEngine.js/regions.js/scanTree.js
// compute is inert until a phone is actually attached to receive it and send
// intent back.
//
// Message shapes (both directions are plain JSON text frames):
//
//   -> phone  { type: 'state', regions, navigation, information,
//               ambiguity, url, at }
//     Sent on connect and after every scan (session.onEvent 'scan'/'goto'/
//     'navigated'). `regions` groups navigation/information features under
//     their top-level landmark (regions.js) so the phone can show/announce
//     "which panel" before "which item".
//
//   -> phone  { type: 'scanTree', arity, root, paths, narration }
//     Sent in reply to a `requestScanTree` message, or automatically after
//     every 'state' push when the last-known input method was switchScan or
//     voiceGrid (see `setInputMethod` below) — the desktop should not make a
//     phone using buttons pay for scan-tree computation it will never render.
//     `root` is the raw ScanNode tree (JSON-safe — feature objects only, no
//     functions); `paths` is `[{ path: [...indices], feature }]`, flattened
//     because a Map doesn't survive JSON; `narration` is `describe(root)`.
//
//   <- phone  { type: 'inputMethod', method: 'buttons'|'joystick'|'trackpad'
//               |'switchScan'|'voiceGrid', arity?, vocabulary? }
//     The calibration handshake (docs/idea/29 §2): the phone, not the
//     desktop, knows the user's CapabilityProfile, so it tells the desktop
//     which rendering to prepare. `arity` is the button/swipe-direction count
//     for switchScan; `vocabulary` is the calibrated word list for voiceGrid.
//
//   <- phone  { type: 'act', ref?, signature?, bucket?, rank?, action?, value? }
//     Forwarded verbatim to `session.act` (browserSession.js) — identical
//     shape to POST /api/act, so the inspector and the phone dispatch through
//     the exact same call.
//
//   <- phone  { type: 'requestScanTree', arity?, bucket? }
//     Ask for a scan tree over `bucket` ('navigation' by default) at a given
//     arity, independent of the standing `inputMethod` (e.g. re-requesting at
//     a different arity while the user tries a second input surface).
//
// Every inbound message is one JSON object per WebSocket text frame — no
// batching, no length-prefixing needed at this scale.

import { WebSocketServer } from 'ws';
import { extractRegions } from './regions.js';
import { buildScanTree, pathsOf, describe, assignVocabulary } from './scanTree.js';

const DEFAULT_ARITY = 2;

/**
 * Wire a phone-facing WebSocket endpoint onto an existing HTTP server and
 * BrowserSession. Returns a handle with `close()`, mirroring the shape
 * `server.close()` already has so shutdown stays symmetric.
 *
 * @param {import('node:http').Server} httpServer
 * @param {import('./browserSession.js').BrowserSession} session
 */
export function attachPhoneTransport(httpServer, session) {
  const wss = new WebSocketServer({ server: httpServer, path: '/phone' });

  /** @type {Map<import('ws').WebSocket, { method: string|null, arity: number, vocabulary: string[] }>} */
  const clients = new Map();

  function stateMessage() {
    const state = session.state;
    if (!state) return null;
    const regions = extractRegions(state.tree);
    return {
      type: 'state',
      url: state.url ?? null,
      regions,
      navigation: state.navigation,
      information: state.information,
      ambiguity: state.ambiguity,
      at: Date.now(),
    };
  }

  function scanTreeMessage(bucket, arity, vocabulary) {
    const state = session.state;
    if (!state) return null;
    const features = bucket === 'information' ? state.information : state.navigation;
    const root = buildScanTree(features, { arity });
    if (!root) return { type: 'scanTree', arity, bucket, root: null, paths: [], narration: '' };
    const paths = [...pathsOf(root).entries()].map(([feature, path]) => ({ feature, path }));
    const vocabularyMap = vocabulary?.length ? assignVocabulary(root, vocabulary) : {};
    return { type: 'scanTree', arity, bucket, root, paths, narration: describe(root), vocabularyMap };
  }

  function send(ws, message) {
    if (ws.readyState === ws.OPEN) ws.send(JSON.stringify(message));
  }

  function broadcastState() {
    const message = stateMessage();
    if (!message) return;
    for (const [ws, prefs] of clients) {
      send(ws, message);
      if (prefs.method === 'switchScan' || prefs.method === 'voiceGrid') {
        const bucket = 'navigation';
        const tree = scanTreeMessage(bucket, prefs.arity, prefs.vocabulary);
        if (tree) send(ws, tree);
      }
    }
  }

  // 'scan' is the only event that means `session.state` actually changed —
  // 'goto'/'navigated' fire before/during navigation, ahead of the rescan
  // that follows them, so listening to those too would broadcast a stale or
  // half-updated state.
  const offEvent = session.onEvent(event => {
    if (event.type === 'scan') broadcastState();
  });

  wss.on('connection', ws => {
    clients.set(ws, { method: null, arity: DEFAULT_ARITY, vocabulary: [] });
    const initial = stateMessage();
    if (initial) send(ws, initial);

    ws.on('message', async raw => {
      let message;
      try { message = JSON.parse(raw.toString()); } catch { return; }

      const prefs = clients.get(ws);
      if (message.type === 'inputMethod') {
        clients.set(ws, {
          method: message.method ?? null,
          arity: Number.isInteger(message.arity) && message.arity >= 2 ? message.arity : DEFAULT_ARITY,
          vocabulary: Array.isArray(message.vocabulary) ? message.vocabulary : [],
        });
        if (message.method === 'switchScan' || message.method === 'voiceGrid') {
          const tree = scanTreeMessage('navigation', clients.get(ws).arity, clients.get(ws).vocabulary);
          if (tree) send(ws, tree);
        }
        return;
      }

      if (message.type === 'requestScanTree') {
        const arity = Number.isInteger(message.arity) && message.arity >= 2
          ? message.arity : prefs?.arity ?? DEFAULT_ARITY;
        const tree = scanTreeMessage(message.bucket ?? 'navigation', arity, prefs?.vocabulary ?? []);
        if (tree) send(ws, tree);
        return;
      }

      if (message.type === 'act') {
        const { type, ...action } = message;
        try {
          const result = await session.run(() => session.act(action));
          send(ws, { type: 'actResult', ...result });
        } catch (err) {
          send(ws, { type: 'actResult', ok: false, error: err.message });
        }
        return;
      }
    });

    ws.on('close', () => clients.delete(ws));
  });

  return {
    close() {
      offEvent();
      for (const ws of clients.keys()) ws.close();
      wss.close();
    },
  };
}
