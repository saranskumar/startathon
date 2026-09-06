// RailLink overlay — the page-side half of the preprogrammed demo link.
//
// Loaded after rail.js + interactions.js. Does not monkey-patch rail.js:
// screen changes are detected with a MutationObserver on #app (rAF-debounced)
// plus popstate. Selectors from the authored map are used only to locate an
// element once an act has already been decided.
//
// Connects as role=page. Relay URL:
//   same origin by default (npm run relay)
//   ?relay=wss://host   when the mock is on https:// (mixed-content blocks ws://)
//   ?room=CODE          (default DEMO)

(function () {
  const params = new URLSearchParams(location.search);
  const ROOM = (params.get('room') || 'DEMO').toUpperCase();

  const state = {
    ws: null,
    timer: null,
    backoff: 400,
    online: false,
    phones: 0,
    arity: 2,
    method: 'buttons',
    vocabulary: [],
    focusId: null,
    scanGroup: null,
    lastSnap: null,
    lastScreen: null,
    flashId: null,
    flashUntil: 0,
    pushTimer: 0,
  };

  function socketUrl() {
    const explicit = params.get('relay') || localStorage.getItem('aperture.relay');
    let host = explicit;
    if (!host) {
      if (location.protocol === 'https:') host = '';
      else host = 'ws://' + location.host;
    }
    if (!host) return '';
    host = host.replace(/\/$/, '');
    if (host.startsWith('http://')) host = 'ws://' + host.slice(7);
    if (host.startsWith('https://')) host = 'wss://' + host.slice(8);
    if (!/^wss?:\/\//.test(host)) {
      host = (location.protocol === 'https:' ? 'wss://' : 'ws://') + host;
    }
    return host + '/ws?room=' + encodeURIComponent(ROOM) + '&role=page';
  }

  function send(msg) {
    if (state.ws && state.ws.readyState === WebSocket.OPEN) {
      state.ws.send(JSON.stringify(msg));
    }
  }

  function boxOf(sel, nth) {
    if (!sel) return null;
    const el = document.querySelectorAll(sel)[nth || 0];
    if (!el) return null;
    const r = el.getBoundingClientRect();
    if (!r.width && !r.height) return null;
    return {
      x: Math.round(r.left),
      y: Math.round(r.top),
      w: Math.round(r.width),
      h: Math.round(r.height),
    };
  }

  function withBoxes(snap) {
    return {
      ...snap,
      regions: (snap.regions || []).map((r) => ({ ...r, box: boxOf(r.sel, 0) })),
      interactions: (snap.interactions || []).map((it) => ({
        ...it,
        box: boxOf(it.sel, it.nth),
      })),
    };
  }

  function snapshot() {
    if (typeof Interactions === 'undefined') return null;
    return withBoxes(Interactions.snapshot(state.arity));
  }

  function pushState() {
    const snap = snapshot();
    if (!snap) return;
    state.lastSnap = snap;
    state.lastScreen = snap.screen;
    send({ type: 'state', ...snap });
    draw();
  }

  function requestPush() {
    if (state.pushTimer) return;
    state.pushTimer = requestAnimationFrame(() => {
      state.pushTimer = 0;
      pushState();
    });
  }

  function findInteraction(id) {
    return (state.lastSnap && state.lastSnap.interactions || [])
      .find((it) => it.id === id) || null;
  }

  function findEl(it) {
    if (!it || !it.sel) return null;
    return document.querySelectorAll(it.sel)[it.nth || 0] || null;
  }

  function executeAct(msg) {
    const it = findInteraction(msg.id);
    if (!it) {
      send({ type: 'acted', id: msg.id, ok: false, note: 'unknown id' });
      return;
    }
    if (it.consequential && !msg.confirm) {
      send({ type: 'acted', id: it.id, ok: false, note: 'needs confirm' });
      return;
    }
    const el = findEl(it);
    if (!el) {
      send({ type: 'acted', id: it.id, ok: false, note: 'element not on this screen' });
      return;
    }
    try {
      if (it.act === 'set') {
        const value = msg.value == null ? '' : String(msg.value);
        if ('value' in el) el.value = value;
        el.dispatchEvent(new Event('input', { bubbles: true }));
        el.dispatchEvent(new Event('change', { bubbles: true }));
      } else {
        el.click();
      }
      flash(it.id);
      send({ type: 'acted', id: it.id, ok: true, note: it.act });
    } catch (err) {
      send({ type: 'acted', id: it.id, ok: false, note: String(err && err.message || err) });
    }
  }

  function flash(id) {
    state.flashId = id;
    state.flashUntil = Date.now() + 520;
    draw();
    setTimeout(draw, 540);
  }

  function onMessage(raw) {
    let msg;
    try { msg = JSON.parse(raw); } catch { return; }
    if (!msg || typeof msg !== 'object') return;

    if (msg.type === 'joined') {
      state.online = true;
      paintHud();
      pushState();
      return;
    }
    if (msg.type === 'peer') {
      state.phones = msg.phones || 0;
      paintHud();
      return;
    }
    if (msg.type === 'replaced') {
      state.online = false;
      paintHud();
      return;
    }
    if (msg.type === 'focus') {
      state.focusId = msg.id || null;
      if (msg.group != null) state.scanGroup = msg.group;
      else state.scanGroup = groupOf(state.focusId);
      draw();
      return;
    }
    if (msg.type === 'act') {
      state.focusId = msg.id || state.focusId;
      executeAct(msg);
      return;
    }
    if (msg.type === 'inputMethod') {
      const nextArity = Math.max(2, Number(msg.arity) || state.arity);
      const arityChanged = nextArity !== state.arity;
      state.method = msg.method || state.method;
      state.arity = nextArity;
      state.vocabulary = Array.isArray(msg.vocabulary) ? msg.vocabulary : [];
      if (msg.group != null) state.scanGroup = msg.group;
      if (arityChanged) pushState();
      else draw();
    }
  }

  function groupOf(id) {
    if (!id || !state.lastSnap) return null;
    const g = (state.lastSnap.scanGroups || []).find((x) => (x.ids || []).includes(id));
    return g ? g.group : null;
  }

  function connect() {
    const url = socketUrl();
    paintHud();
    if (!url) return;
    try {
      state.ws = new WebSocket(url);
    } catch {
      scheduleReconnect();
      return;
    }
    state.ws.addEventListener('open', () => { state.backoff = 400; });
    state.ws.addEventListener('message', (ev) => onMessage(ev.data));
    state.ws.addEventListener('close', () => {
      state.online = false;
      state.phones = 0;
      paintHud();
      scheduleReconnect();
    });
    state.ws.addEventListener('error', () => {
      try { state.ws.close(); } catch { /* already dead */ }
    });
  }

  function scheduleReconnect() {
    clearTimeout(state.timer);
    state.timer = setTimeout(connect, state.backoff);
    state.backoff = Math.min(state.backoff * 2, 8000);
  }

  function ensureHud() {
    let hud = document.getElementById('kai-hud');
    if (hud) return hud;
    hud = document.createElement('aside');
    hud.id = 'kai-hud';
    hud.setAttribute('aria-live', 'polite');
    document.body.appendChild(hud);
    return hud;
  }

  function paintHud() {
    const hud = ensureHud();
    const url = socketUrl();
    let peer;
    if (!url && location.protocol === 'https:') peer = 'set ?relay=wss://…';
    else if (!state.online) peer = 'connecting';
    else if (state.phones > 0) peer = state.phones === 1 ? 'phone live' : state.phones + ' phones';
    else peer = 'no phone';
    const live = state.online && state.phones > 0;
    hud.dataset.live = live ? '1' : '0';
    hud.dataset.online = state.online ? '1' : '0';
    hud.innerHTML =
      '<span class="kai-dot" data-live="' + (live ? '1' : '0') + '" data-online="' +
      (state.online ? '1' : '0') + '"></span>' +
      '<span class="kai-room">' + escapeHtml(ROOM) + '</span>' +
      '<span class="kai-peer">' + escapeHtml(peer) + '</span>';
  }

  function escapeHtml(s) {
    return String(s).replace(/&/g, '&amp;').replace(/</g, '&lt;').replace(/>/g, '&gt;');
  }

  function ensureLayers() {
    let root = document.getElementById('kai-overlay');
    if (root) return root;
    root = document.createElement('div');
    root.id = 'kai-overlay';
    root.setAttribute('aria-hidden', 'true');
    document.body.appendChild(root);
    return root;
  }

  function boxStyle(box) {
    if (!box) return 'display:none';
    return 'left:' + box.x + 'px;top:' + box.y + 'px;width:' + box.w + 'px;height:' + box.h + 'px;';
  }

  function unionBox(boxes) {
    const live = boxes.filter(Boolean);
    if (!live.length) return null;
    let x1 = Infinity, y1 = Infinity, x2 = -Infinity, y2 = -Infinity;
    for (const b of live) {
      x1 = Math.min(x1, b.x);
      y1 = Math.min(y1, b.y);
      x2 = Math.max(x2, b.x + b.w);
      y2 = Math.max(y2, b.y + b.h);
    }
    return { x: x1, y: y1, w: x2 - x1, h: y2 - y1 };
  }

  function draw() {
    const root = ensureLayers();
    const snap = state.lastSnap || snapshot();
    if (!snap) { root.innerHTML = ''; return; }
    const parts = [];
    const flashing = state.flashUntil > Date.now() ? state.flashId : null;
    const showScan = state.method === 'switchScan' || state.method === 'voice';

    for (const region of snap.regions || []) {
      if (!region.box) continue;
      parts.push(
        '<div class="kai-region" style="' + boxStyle(region.box) + '">' +
          '<span class="kai-region-label">' +
            escapeHtml(region.name) + ' · ' + (region.count || 0) + ' items' +
          '</span></div>'
      );
    }

    if (showScan && state.scanGroup != null) {
      const group = (snap.scanGroups || []).find((g) => g.group === state.scanGroup);
      if (group) {
        const boxes = (group.ids || []).map((id) => {
          const it = snap.interactions.find((x) => x.id === id);
          return it && it.box;
        });
        const box = unionBox(boxes);
        if (box) {
          parts.push(
            '<div class="kai-scan" style="' + boxStyle(box) + '">' +
              '<span class="kai-scan-caption">' + escapeHtml(group.caption || '') + '</span></div>'
          );
        }
      }
    }

    for (const it of snap.interactions || []) {
      if (!it.box) continue;
      const focused = it.id === state.focusId;
      const hit = it.id === flashing;
      if (!focused && !hit) continue;
      parts.push(
        '<div class="kai-focus' + (hit ? ' kai-flash' : '') + '" style="' +
          boxStyle(it.box) + '"></div>'
      );
    }

    root.innerHTML = parts.join('');
    paintHud();
  }

  function watchScreen() {
    const app = document.getElementById('app');
    if (app) {
      const mo = new MutationObserver(() => requestPush());
      mo.observe(app, { childList: true, subtree: true });
    }
    window.addEventListener('popstate', () => requestPush());
    window.addEventListener('resize', () => requestPush());
    window.addEventListener('scroll', () => requestPush(), true);
  }

  function injectCss() {
    if (document.getElementById('kai-overlay-css')) return;
    const css = document.createElement('style');
    css.id = 'kai-overlay-css';
    css.textContent = `
      #kai-overlay {
        position: fixed; inset: 0; pointer-events: none; z-index: 9998;
        font-family: -apple-system, "Segoe UI", Roboto, Arial, sans-serif;
      }
      #kai-overlay .kai-region {
        position: fixed; border: 2px dashed rgba(14, 116, 144, 0.7);
        border-radius: 10px; box-sizing: border-box;
      }
      #kai-overlay .kai-region-label {
        position: absolute; left: 8px; top: -11px;
        background: #0e7490; color: #fff;
        font-size: 11px; font-weight: 700; letter-spacing: 0.02em;
        padding: 1px 7px; border-radius: 999px; white-space: nowrap;
      }
      #kai-overlay .kai-focus {
        position: fixed; border: 3px solid #f59e0b; border-radius: 10px;
        box-shadow: 0 0 0 4px rgba(245, 158, 11, 0.28), inset 0 0 0 999px rgba(245, 158, 11, 0.12);
        box-sizing: border-box;
      }
      #kai-overlay .kai-flash {
        border-color: #16a34a;
        box-shadow: 0 0 0 6px rgba(22, 163, 74, 0.35), inset 0 0 0 999px rgba(22, 163, 74, 0.16);
      }
      #kai-overlay .kai-scan {
        position: fixed; border: 3px solid #7c3aed; border-radius: 12px;
        box-shadow: 0 0 0 4px rgba(124, 58, 237, 0.2);
        box-sizing: border-box;
      }
      #kai-overlay .kai-scan-caption {
        position: absolute; left: 8px; bottom: -12px;
        background: #7c3aed; color: #fff;
        font-size: 11px; font-weight: 700;
        padding: 2px 8px; border-radius: 999px; white-space: nowrap;
      }
      #kai-hud {
        position: fixed; right: 12px; bottom: 12px; z-index: 9999;
        display: flex; align-items: center; gap: 8px;
        background: rgba(20, 18, 14, 0.88); color: #f3efe2;
        font: 700 12px/1 -apple-system, "Segoe UI", Roboto, Arial, sans-serif;
        letter-spacing: 0.04em; padding: 8px 12px; border-radius: 999px;
        pointer-events: none; box-shadow: 0 6px 20px rgba(0,0,0,0.25);
      }
      #kai-hud .kai-dot {
        width: 9px; height: 9px; border-radius: 50%;
        background: #737373; box-shadow: 0 0 0 3px rgba(115,115,115,0.25);
      }
      #kai-hud .kai-dot[data-online="1"] { background: #eab308; box-shadow: 0 0 0 3px rgba(234,179,8,0.28); }
      #kai-hud .kai-dot[data-live="1"] { background: #22c55e; box-shadow: 0 0 0 3px rgba(34,197,94,0.28); }
      #kai-hud .kai-room { text-transform: uppercase; }
      #kai-hud .kai-peer { font-weight: 600; opacity: 0.78; text-transform: lowercase; }
    `;
    document.head.appendChild(css);
  }

  function boot() {
    injectCss();
    paintHud();
    watchScreen();
    connect();
    state.lastSnap = snapshot();
    draw();
  }

  if (document.readyState === 'loading') document.addEventListener('DOMContentLoaded', boot);
  else boot();
})();
