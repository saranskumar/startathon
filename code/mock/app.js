// Mock UI — Interaction Pattern Demo.
// Deliberately NOT dressed up as a real app: the home menu honestly
// offers two demo modes rather than pretending to be a product.
//  - "simple": one isolated UI pattern per step (Back/Next).
//  - "complex": a small, generic multi-screen app (persistent nav,
//    list -> detail -> edit, settings tabs) to show a more realistic,
//    interconnected flow than the isolated patterns allow.

const state = {
  mode: 'menu', // 'menu' | 'simple' | 'complex'
  step: 0,
  scrollValue: 5,
  cardChoice: null,
  activeTab: 'a',
  tapTargets: [],
  tapResult: null,
  text: '',
  complex: {
    screen: 'list',
    items: [
      { id: 1, title: 'Item one', note: '' },
      { id: 2, title: 'Item two', note: '' },
      { id: 3, title: 'Item three', note: '' },
      { id: 4, title: 'Item four', note: '' },
    ],
    selectedId: null,
    draftNote: '',
    settingsTab: 'a',
  },
};

const STEPS = [
  { key: 'scroll', name: 'Scroll selector', render: renderScroll },
  { key: 'cards', name: 'Card grid', render: renderCards },
  { key: 'tabs', name: 'Tab switcher', render: renderTabs },
  { key: 'point', name: 'Free tap', render: renderPoint },
  { key: 'text', name: 'Text entry', render: renderText },
  { key: 'review', name: 'Confirm / review', render: renderReview },
];

// ---------- Menu ----------

function renderMenu() {
  return `
    <div class="menu-grid">
      <div class="menu-card" onclick="enterMode('simple')">
        <div class="kicker">Option A</div>
        <h3>Simple patterns</h3>
        <p>One isolated UI pattern per step: scroll selector, card grid, tabs, free tap, text entry, confirm/review.</p>
      </div>
      <div class="menu-card" onclick="enterMode('complex')">
        <div class="kicker">Option B</div>
        <h3>App-like flow</h3>
        <p>A small, generic multi-screen app with persistent navigation — closer to using a real product than one pattern at a time.</p>
      </div>
    </div>
  `;
}

function enterMode(mode) {
  state.mode = mode;
  if (mode === 'simple') state.step = 0;
  if (mode === 'complex') state.complex.screen = 'list';
  render();
}

function exitToMenu() { state.mode = 'menu'; render(); }

// ---------- Simple pattern steps ----------

function renderScroll() {
  return `
    <p class="pattern-name">Scroll selector</p>
    <p class="pattern-hint">A continuous, drag-to-adjust control.</p>
    <div class="widget scroll-select">
      <input type="range" min="0" max="10" value="${state.scrollValue}" oninput="onScroll(this.value)" />
      <span class="value">${state.scrollValue}</span>
    </div>
  `;
}
function onScroll(v) { state.scrollValue = Number(v); render(); }

function renderCards() {
  const labels = ['A', 'B', 'C', 'D', 'E', 'F'];
  return `
    <p class="pattern-name">Card grid</p>
    <p class="pattern-hint">A discrete choice among several options.</p>
    <div class="widget card-grid">
      ${labels.map(l => `<div class="pattern-card ${state.cardChoice === l ? 'selected' : ''}" onclick="onCard('${l}')">${l}</div>`).join('')}
    </div>
  `;
}
function onCard(l) { state.cardChoice = l; render(); }

function renderTabs() {
  const tabs = [{ id: 'a', label: 'One' }, { id: 'b', label: 'Two' }, { id: 'c', label: 'Three' }];
  return `
    <p class="pattern-name">Tab switcher</p>
    <p class="pattern-hint">A discrete choice between sections.</p>
    <div class="widget">
      <div class="tabbar">
        ${tabs.map(t => `<button class="${state.activeTab === t.id ? 'active' : ''}" onclick="onTab('${t.id}')">${t.label}</button>`).join('')}
      </div>
      <div class="tab-panel">Panel content for tab "${tabs.find(t => t.id === state.activeTab).label}".</div>
    </div>
  `;
}
function onTab(id) { state.activeTab = id; render(); }

// Free tap: 3 randomly-placed targets, so a tap can be scored against
// an intended point rather than being ambiguous freeform placement.
const FIELD_W = 100, FIELD_H = 100, MARGIN = 15;

function ensureTapTargets() {
  if (state.tapTargets.length) return;
  for (let i = 0; i < 3; i++) {
    state.tapTargets.push({
      id: i + 1,
      x: MARGIN + Math.random() * (FIELD_W - 2 * MARGIN),
      y: MARGIN + Math.random() * (FIELD_H - 2 * MARGIN),
    });
  }
}

function renderPoint() {
  ensureTapTargets();
  const hitId = state.tapResult && state.tapResult.hitId;
  return `
    <p class="pattern-name">Free tap</p>
    <p class="pattern-hint">Tap the target closest to where you meant to point — this is how a real accuracy check tells an intentional tap from a random one.</p>
    <div class="widget pointfield" onclick="onPoint(event)">
      ${state.tapTargets.map(t => `<div class="target ${hitId === t.id ? 'hit' : ''}" style="left:${t.x}%;top:${t.y}%;">${t.id}</div>`).join('')}
      ${state.tapResult ? `<div class="marker" style="left:${state.tapResult.x}%;top:${state.tapResult.y}%;"></div>` : ''}
    </div>
    <p class="tap-result ${hitId ? 'hit' : ''}">${tapResultText()}</p>
  `;
}

function tapResultText() {
  if (!state.tapResult) return 'No tap yet.';
  const r = state.tapResult;
  return r.hitId
    ? `Hit target ${r.hitId} — ${r.distance.toFixed(1)}% off center.`
    : `Missed — nearest was target ${r.nearestId}, ${r.distance.toFixed(1)}% away.`;
}

function onPoint(e) {
  const rect = e.currentTarget.getBoundingClientRect();
  const x = ((e.clientX - rect.left) / rect.width) * 100;
  const y = ((e.clientY - rect.top) / rect.height) * 100;
  let nearest = null, nearestDist = Infinity;
  for (const t of state.tapTargets) {
    const d = Math.hypot(t.x - x, t.y - y);
    if (d < nearestDist) { nearestDist = d; nearest = t; }
  }
  const HIT_RADIUS = 8; // % of field
  state.tapResult = {
    x, y,
    nearestId: nearest.id,
    distance: nearestDist,
    hitId: nearestDist <= HIT_RADIUS ? nearest.id : null,
  };
  render();
}

function renderText() {
  return `
    <p class="pattern-name">Text entry</p>
    <p class="pattern-hint">Free-form content input.</p>
    <div class="widget field">
      <input placeholder="Type something" value="${escapeHtml(state.text)}" oninput="onText(this.value)" />
    </div>
  `;
}
function onText(v) { state.text = v; render(); }

function renderReview() {
  return `
    <p class="pattern-name">Confirm / review</p>
    <p class="pattern-hint">A summary of what was picked, before anything is confirmed.</p>
    <div class="widget">
      <div class="summary-row"><span>Scroll selector</span><strong>${state.scrollValue}</strong></div>
      <div class="summary-row"><span>Card grid</span><strong>${state.cardChoice || '—'}</strong></div>
      <div class="summary-row"><span>Tab switcher</span><strong>${state.activeTab.toUpperCase()}</strong></div>
      <div class="summary-row"><span>Free tap</span><strong>${state.tapResult ? tapResultText() : '—'}</strong></div>
      <div class="summary-row"><span>Text entry</span><strong>${escapeHtml(state.text) || '—'}</strong></div>
    </div>
  `;
}

function nextStep() { state.step = Math.min(STEPS.length - 1, state.step + 1); render(); }
function prevStep() { state.step = Math.max(0, state.step - 1); render(); }

// ---------- Complex, app-like flow ----------

function renderComplex() {
  const c = state.complex;
  const body = c.screen === 'list' ? renderComplexList()
    : c.screen === 'detail' ? renderComplexDetail()
    : renderComplexSettings();
  return `
    <div class="app-shell">
      <div class="app-nav">
        <button class="${c.screen === 'list' || c.screen === 'detail' ? 'active' : ''}" onclick="complexGoto('list')">Directory</button>
        <button class="${c.screen === 'settings' ? 'active' : ''}" onclick="complexGoto('settings')">Settings</button>
      </div>
      ${body}
    </div>
  `;
}

function complexGoto(screen) { state.complex.screen = screen; render(); }

function renderComplexList() {
  const c = state.complex;
  return `
    <p class="pattern-name" style="text-align:left">Directory</p>
    <p class="pattern-hint" style="text-align:left;margin-bottom:16px">Tap an item to open it.</p>
    ${c.items.map(it => `
      <div class="list-item" onclick="openComplexItem(${it.id})">
        <span>${escapeHtml(it.title)}</span>
        <span class="meta">${it.note ? 'edited' : 'no note'}</span>
      </div>
    `).join('')}
  `;
}

function openComplexItem(id) {
  const c = state.complex;
  c.selectedId = id;
  c.draftNote = c.items.find(i => i.id === id).note;
  c.screen = 'detail';
  render();
}

function renderComplexDetail() {
  const c = state.complex;
  const item = c.items.find(i => i.id === c.selectedId);
  return `
    <button class="back-link" onclick="complexGoto('list')">&larr; Back to directory</button>
    <p class="pattern-name" style="text-align:left">${escapeHtml(item.title)}</p>
    <div class="field" style="margin:16px 0">
      <textarea rows="3" placeholder="Add a note" oninput="onComplexNote(this.value)">${escapeHtml(c.draftNote)}</textarea>
    </div>
    <div style="display:flex;gap:10px">
      <button class="btn" onclick="complexGoto('list')">Cancel</button>
      <button class="btn primary" onclick="saveComplexNote()">Save</button>
    </div>
  `;
}

function onComplexNote(v) { state.complex.draftNote = v; }

function saveComplexNote() {
  const c = state.complex;
  const item = c.items.find(i => i.id === c.selectedId);
  item.note = c.draftNote;
  c.screen = 'list';
  render();
}

function renderComplexSettings() {
  const c = state.complex;
  const tabs = [{ id: 'a', label: 'Display' }, { id: 'b', label: 'About' }];
  return `
    <p class="pattern-name" style="text-align:left">Settings</p>
    <div class="tabbar" style="margin-top:16px">
      ${tabs.map(t => `<button class="${c.settingsTab === t.id ? 'active' : ''}" onclick="onComplexTab('${t.id}')">${t.label}</button>`).join('')}
    </div>
    <div class="tab-panel">${c.settingsTab === 'a' ? 'Display settings placeholder.' : 'A small generic app used to demo a multi-screen flow.'}</div>
  `;
}

function onComplexTab(id) { state.complex.settingsTab = id; render(); }

// ---------- Shared ----------

function escapeHtml(s) {
  return String(s ?? '').replace(/[&<>"']/g, c => ({'&':'&amp;','<':'&lt;','>':'&gt;','"':'&quot;',"'":'&#39;'}[c]));
}

function render() {
  const nav = document.getElementById('nav');
  const indicator = document.getElementById('step-indicator');

  if (state.mode === 'menu') {
    indicator.textContent = 'Choose a demo mode';
    nav.style.display = 'none';
    document.getElementById('screen').innerHTML = renderMenu();
    return;
  }

  if (state.mode === 'complex') {
    indicator.textContent = 'App-like flow';
    nav.style.display = 'flex';
    document.getElementById('screen').innerHTML = renderComplex();
    document.getElementById('btn-back').disabled = false;
    document.getElementById('btn-back').textContent = 'Exit to menu';
    document.getElementById('btn-back').onclick = exitToMenu;
    document.getElementById('btn-next').style.display = 'none';
    document.getElementById('dots').innerHTML = '';
    return;
  }

  // simple mode
  const total = STEPS.length;
  nav.style.display = 'flex';
  document.getElementById('btn-next').style.display = 'inline-block';
  indicator.textContent = `Step ${state.step + 1} of ${total}`;
  document.getElementById('screen').innerHTML = STEPS[state.step].render();
  const backBtn = document.getElementById('btn-back');
  backBtn.disabled = false;
  backBtn.textContent = state.step === 0 ? 'Exit to menu' : 'Back';
  backBtn.onclick = state.step === 0 ? exitToMenu : prevStep;
  document.getElementById('btn-next').textContent = state.step === total - 1 ? 'Done' : 'Next';
  document.getElementById('btn-next').onclick = state.step === total - 1 ? exitToMenu : nextStep;
  document.getElementById('dots').innerHTML = STEPS.map((_, i) =>
    `<span class="${i === state.step ? 'active' : ''}"></span>`
  ).join('');
}

// Deep-link support for screenshots/demos: ?mode=simple&step=2, ?mode=complex
const params = new URLSearchParams(location.search);
const modeParam = params.get('mode');
if (modeParam === 'simple' || modeParam === 'complex') {
  state.mode = modeParam;
  const stepParam = Number(params.get('step'));
  if (Number.isInteger(stepParam) && stepParam >= 0 && stepParam < STEPS.length) {
    state.step = stepParam;
  }
}
render();
