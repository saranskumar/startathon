// Inspector front-end. Reads only from the server's API (/api/state,
// /api/act, /api/events) — the same routes the phone client will use, so
// anything this page can show, the API can already answer.

import { DasherView } from '/dasher.js';

const $ = (id) => document.getElementById(id);

const els = {
  url: $('url'), goForm: $('go-form'), rescan: $('rescan'), stats: $('stats'), conn: $('conn'),
  ambiguity: $('ambiguity'), shot: $('shot'), shotWrap: $('shot-wrap'), overlay: $('overlay'),
  showBoxes: $('show-boxes'), showPruned: $('show-pruned'), filter: $('filter'), tree: $('tree'),
  navigation: $('navigation'), information: $('information'),
  navCount: $('nav-count'), infoCount: $('info-count'), log: $('log'),
  dasherPane: $('dasher-pane'), dasher: $('dasher'),
  modeList: $('mode-list'), modeDasher: $('mode-dasher'),
};

let state = null;
let collapsed = new Set();
let activeKey = null;

// ---------- data ----------

async function api(route, options) {
  const res = await fetch(route, {
    method: options ? 'POST' : 'GET',
    headers: options ? { 'content-type': 'application/json' } : undefined,
    body: options ? JSON.stringify(options) : undefined,
  });
  const body = await res.json();
  if (!res.ok) throw new Error(body.error ?? res.statusText);
  return body;
}

async function refresh() {
  const { state: next, log } = await api('/api/state');
  if (!next) return;
  const isNewPage = state?.url !== next.url;
  state = next;
  if (isNewPage) collapsed = new Set();
  render();
  // The navigator re-reads its tree on every scan, so a page that changed under
  // it never leaves you steering at options that are no longer there.
  dasherView.setScan(next);
  if (log) { els.log.replaceChildren(); log.forEach(appendLog); }
  reloadScreenshot();
}

function reloadScreenshot() {
  els.shot.src = '/api/screenshot.png?t=' + Date.now();
}

// ---------- render ----------

function render() {
  if (!state) return;
  els.url.value = state.url;
  renderStats();
  renderAmbiguity();
  renderBuckets();
  renderTree();
  renderOverlay();
}

function renderStats() {
  const s = state.stats;
  const chips = [
    ['nodes', s.rawNodes],
    ['kept', s.keptNodes],
    ['pruned', s.prunedNodes],
    ['interactive', s.interactive],
    ['landmarks', s.landmarks],
    ['headings', s.headings],
    ['scan', state.scanMs + 'ms'],
  ];
  els.stats.replaceChildren(...chips.map(([label, value]) => {
    const el = document.createElement('span');
    el.className = 'chip';
    el.innerHTML = label + ' <b></b>';
    el.querySelector('b').textContent = value;
    return el;
  }));
}

function renderAmbiguity() {
  const a = state.ambiguity;
  els.ambiguity.hidden = !a?.needsReview;
  if (!a?.needsReview) return;
  els.ambiguity.replaceChildren();
  const head = document.createElement('b');
  head.textContent = 'Tier 1 is unsure here — this is where a single narrow LLM call would be spent:';
  const list = document.createElement('ul');
  for (const reason of a.reasons) {
    const li = document.createElement('li');
    li.textContent = reason;
    list.append(li);
  }
  els.ambiguity.append(head, list);
}

function keyOf(feature) {
  return feature.ref ?? feature.identity ?? feature.path ?? feature.label;
}

function renderBuckets() {
  els.navCount.textContent = state.navigation.length + ' of ' + state.stats.interactive;
  els.infoCount.textContent = state.information.length + ' shown';
  paintFocus();
  paintBucket(els.navigation, state.navigation, 'navigation');
  paintBucket(els.information, state.information, 'information');
}

function paintFocus() {
  let bar = $('focus-bar');
  if (!bar) {
    bar = document.createElement('div');
    bar.id = 'focus-bar';
    bar.className = 'focus-bar';
    const aux = els.navigation.parentElement;
    aux.insertBefore(bar, aux.querySelector('.bucket-head'));
  }
  const focus = state.focus ?? [];
  if (focus.length === 0) {
    bar.hidden = true;
    bar.replaceChildren();
    return;
  }
  bar.hidden = false;
  bar.replaceChildren();
  const crumb = document.createElement('span');
  crumb.className = 'focus-crumb';
  crumb.textContent = focus.join(' › ');
  const back = document.createElement('button');
  back.type = 'button';
  back.className = 'act';
  back.textContent = '← back';
  back.onclick = async () => {
    try {
      await api('/api/act', { action: 'back' });
      await refresh();
    } catch (err) {
      appendLog({ type: 'error', message: err.message, at: Date.now() });
    }
  };
  bar.append(crumb, back);
}

function paintBucket(container, features, bucket) {
  container.replaceChildren();
  if (features.length === 0) {
    const li = document.createElement('li');
    li.className = 'empty';
    li.textContent = 'nothing ranked in this bucket';
    container.append(li);
    return;
  }
  for (const feature of features) container.append(featureCard(feature, bucket));
}

function featureCard(feature, bucket) {
  const li = document.createElement('li');
  li.className = 'feature' + (bucket === 'information' ? ' is-info' : '') + (feature.isGroup ? ' is-group' : '');
  li.dataset.key = keyOf(feature);

  const top = document.createElement('div');
  top.className = 'feature-top';

  const rank = document.createElement('span');
  rank.className = 'rank';
  rank.textContent = feature.rank + '.';

  const score = document.createElement('button');
  score.className = 'score';
  score.type = 'button';
  score.title = 'show the score breakdown';
  score.textContent = feature.score.toFixed(2);

  const label = document.createElement('span');
  label.className = 'label';
  const title = document.createElement('span');
  title.className = 't';
  title.textContent = feature.label ?? feature.name ?? '(unnamed)';
  if (feature.name && feature.label !== feature.name) title.title = feature.name;
  const sub = document.createElement('span');
  sub.className = 's';
  if (feature.isGroup) {
    sub.textContent = 'group · ' + (feature.memberCount ?? feature.members?.length ?? '?') + ' items';
  } else {
    sub.textContent = feature.role + (feature.level ? ' h' + feature.level : '') +
      (feature.taskShape ? ' · ' + feature.taskShape : '') +
      (feature.ref ? ' · ' + feature.ref : '');
  }
  label.append(title, sub);
  if (feature.isAmbiguous) label.append(tag('no role'));
  if (feature.offscreen) label.append(tag('offscreen'));
  if (feature.isGroup) label.append(tag('group'));

  top.append(rank, score, label);

  const act = document.createElement('button');
  act.className = 'act';
  act.type = 'button';
  if (feature.isGroup) act.textContent = 'open';
  else act.textContent = bucket === 'navigation' ? (feature.action ?? 'click') : 'mark seen';
  act.onclick = () => dispatch(feature, bucket);
  top.append(act);

  const parts = document.createElement('div');
  parts.className = 'parts';
  parts.hidden = true;
  for (const part of feature.parts ?? []) {
    const row = document.createElement('div');
    const name = document.createElement('span');
    name.textContent = part.label;
    const value = document.createElement('span');
    value.className = part.value < 0 ? 'neg' : 'pos';
    value.textContent = (part.value > 0 ? '+' : '') + part.value.toFixed(2);
    row.append(name, value);
    parts.append(row);
  }
  const total = document.createElement('div');
  total.innerHTML = '<span>total</span>';
  const totalValue = document.createElement('span');
  totalValue.textContent = feature.score.toFixed(2);
  total.append(totalValue);
  parts.append(total);
  score.onclick = () => { parts.hidden = !parts.hidden; };

  li.append(top, parts);
  li.onmouseenter = () => setActive(keyOf(feature));
  li.onmouseleave = () => setActive(null);
  return li;
}

function tag(text) {
  const el = document.createElement('span');
  el.className = 'tag';
  el.textContent = text;
  return el;
}

async function dispatch(feature, bucket) {
  const verb = feature.isGroup ? 'open'
    : bucket === 'navigation' ? (feature.action ?? 'click') : 'view';
  let value;
  if (verb === 'fill' || verb === 'set' || verb === 'select') {
    value = prompt('Value for ' + (feature.name ?? feature.role) + ':', feature.value ?? '');
    if (value === null) return;
  }
  try {
    await api('/api/act', {
      ref: feature.ref,
      signature: feature.signature,
      identity: feature.identity,
      bucket,
      rank: feature.rank,
      action: verb,
      value,
    });
    if (verb === 'open' || verb === 'back') await refresh();
  } catch (err) {
    appendLog({ type: 'error', message: err.message, at: Date.now() });
  }
  // A click may or may not count as a new screen — that call belongs to
  // pageWatcher, not to us. Only the picture is refreshed unconditionally.
  setTimeout(reloadScreenshot, 250);
}

// ---------- raw tree ----------

function renderTree() {
  const query = els.filter.value.trim().toLowerCase();
  els.tree.replaceChildren();
  for (const node of state.tree) {
    const el = treeNode(node, query);
    if (el) els.tree.append(el);
  }
  if (!els.tree.firstChild) {
    const empty = document.createElement('div');
    empty.className = 'empty';
    empty.textContent = query ? 'no node matches "' + query + '"' : 'empty tree';
    els.tree.append(empty);
  }
}

function matches(node, query) {
  if (!query) return true;
  return node.role.toLowerCase().includes(query) || (node.name ?? '').toLowerCase().includes(query);
}

function treeNode(node, query) {
  const showPruned = els.showPruned.checked;
  const children = (node.children ?? [])
    .map(child => treeNode(child, query))
    .filter(Boolean);

  const self = matches(node, query) && (showPruned || node.kept);
  if (!self && children.length === 0) return null;

  const wrap = document.createElement('div');
  const key = keyOf(node);

  const row = document.createElement('div');
  row.className = 'row' + (node.kept ? '' : ' pruned');
  row.dataset.key = key;

  const twist = document.createElement('span');
  twist.className = 'twist';
  twist.textContent = children.length ? (collapsed.has(key) ? '▸' : '▾') : '';
  if (children.length) {
    twist.onclick = () => {
      if (collapsed.has(key)) collapsed.delete(key); else collapsed.add(key);
      renderTree();
    };
  }

  const role = document.createElement('span');
  role.className = 'role' +
    (node.isLandmark ? ' landmark' : '') +
    (node.isInteractive ? ' interactive' : '') +
    (node.isHeading ? ' heading' : '');
  role.textContent = node.role + (node.level ? '/h' + node.level : '');

  const name = document.createElement('span');
  name.className = 'nm';
  name.textContent = node.name ? '"' + truncate(node.name, 60) + '"' : '';
  if (node.name) name.title = node.name;

  const score = document.createElement('span');
  score.className = 'sc';
  score.textContent = node.score.toFixed(2);

  const meta = document.createElement('span');
  meta.className = 'meta';
  meta.textContent = [
    node.ref,
    node.kept ? null : 'pruned: ' + (node.prunedBecause ?? 'wrapper'),
    node.disabled ? 'disabled' : null,
    node.hidden ? 'hidden' : null,
    node.offscreen ? 'offscreen' : null,
  ].filter(Boolean).join(' · ');

  row.append(twist, role, name, score, meta);
  row.onmouseenter = () => setActive(key);
  row.onmouseleave = () => setActive(null);
  wrap.append(row);

  if (children.length) {
    const kids = document.createElement('div');
    kids.className = 'kids';
    kids.hidden = collapsed.has(key);
    kids.append(...children);
    wrap.append(kids);
  }
  return wrap;
}

function truncate(text, max) {
  return text.length > max ? text.slice(0, max - 1) + '…' : text;
}

// ---------- overlay ----------

function renderOverlay() {
  els.overlay.replaceChildren();
  if (!els.showBoxes.checked) return;
  const scale = els.shot.clientWidth / (state.viewport?.width ?? 1280);
  if (!Number.isFinite(scale) || scale <= 0) return;

  const draw = (feature, cls) => {
    if (!feature.box || feature.box.width === 0) return;
    const el = document.createElement('div');
    el.className = 'hot ' + cls;
    el.dataset.key = keyOf(feature);
    el.style.left = feature.box.x * scale + 'px';
    el.style.top = feature.box.y * scale + 'px';
    el.style.width = feature.box.width * scale + 'px';
    el.style.height = feature.box.height * scale + 'px';
    const badge = document.createElement('span');
    badge.textContent = feature.rank;
    el.append(badge);
    els.overlay.append(el);
  };
  state.navigation.forEach(f => draw(f, 'nav'));
  state.information.forEach(f => draw(f, 'info'));
  if (activeKey) setActive(activeKey);
}

function setActive(key) {
  activeKey = key;
  for (const el of document.querySelectorAll('[data-key]')) {
    const on = key != null && el.dataset.key === key;
    el.classList.toggle('active', on);
    if (el.classList.contains('row')) el.classList.toggle('hit', on);
  }
}

// ---------- events ----------

function appendLog(event) {
  const li = document.createElement('li');
  const time = document.createElement('time');
  time.textContent = new Date(event.at).toLocaleTimeString([], { hour12: false });
  const kind = document.createElement('span');
  kind.className = 'kind' + (event.type === 'error' ? ' err' : '') + (event.type === 'watcher' ? ' watcher' : '');
  kind.textContent = event.type;
  const text = document.createElement('span');
  text.textContent = describe(event);
  li.append(time, kind, text);
  els.log.append(li);
  while (els.log.children.length > 120) els.log.firstChild.remove();
  els.log.scrollTop = els.log.scrollHeight;
}

function describe(event) {
  switch (event.type) {
    case 'scan': return event.reason + ' · ' + event.stats.keptNodes + ' kept of ' + event.stats.rawNodes + ' · ' + event.ms + 'ms';
    case 'watcher': return event.detail;
    case 'act': return (event.ok ? '' : 'FAILED ') + event.verb + ' ' + event.role + ' "' + (event.name ?? '') + '"' + (event.message ? ' — ' + event.message : '');
    case 'selection': return event.signature + ' → ' + event.count + 'x';
    case 'focus': return (event.action === 'back' ? 'back' : 'open ' + (event.label ?? '')) +
      (event.focus?.length ? ' · ' + event.focus.join(' › ') : ' · root');
    case 'goto': case 'navigated': return event.url;
    case 'error': return event.message;
    default: return JSON.stringify(event);
  }
}

// ---------- zooming navigator ----------

const dasherView = new DasherView(els.dasher, {
  act: (request) => api('/api/act', request),
  onLog: appendLog,
});

function setMode(mode) {
  const on = mode === 'dasher';
  document.body.classList.toggle('dasher-mode', on);
  els.dasherPane.hidden = !on;
  els.modeDasher.classList.toggle('on', on);
  els.modeList.classList.toggle('on', !on);
  // Nothing animates while the pane is hidden — no point burning a frame loop
  // on a canvas nobody can see.
  if (on) dasherView.start(); else dasherView.stop();
}

// Debug handle: the navigator animates on requestAnimationFrame, which a
// hidden tab never delivers, so stepping it by hand is the only way to exercise
// it from a console or an automated check.
window.__inspector = { dasherView, api, getState: () => state };

function connect() {
  const source = new EventSource('/api/events');
  source.onopen = () => els.conn.classList.add('live');
  source.onerror = () => els.conn.classList.remove('live');
  source.onmessage = (message) => {
    const event = JSON.parse(message.data);
    appendLog(event);
    // A scan is the only event that changes what is on screen; everything else
    // is just a line in the log.
    if (event.type === 'scan') refresh();
    if (event.type === 'focus') refresh();
    if (event.type === 'act' || event.type === 'navigated') setTimeout(reloadScreenshot, 300);
  };
}

// ---------- wiring ----------

els.goForm.onsubmit = async (e) => {
  e.preventDefault();
  // No refresh() here: the scan that follows arrives as an SSE event, and the
  // stream's handler is the single place that re-renders.
  try { await api('/api/goto', { url: els.url.value }); }
  catch (err) { appendLog({ type: 'error', message: err.message, at: Date.now() }); }
};
els.rescan.onclick = () => api('/api/scan', {})
  .catch(err => appendLog({ type: 'error', message: err.message, at: Date.now() }));
els.modeList.onclick = () => setMode('list');
els.modeDasher.onclick = () => setMode('dasher');
els.filter.oninput = renderTree;
els.showPruned.onchange = renderTree;
els.showBoxes.onchange = renderOverlay;
els.shot.onload = renderOverlay;
window.addEventListener('resize', renderOverlay);

connect();
refresh();
