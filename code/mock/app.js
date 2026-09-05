// Mock UI — Interaction Pattern Demo.
// Deliberately NOT dressed up as a real app: this is a sequence of
// isolated, honestly-labeled UI patterns (one component per step),
// stepped through with Back/Next. Each step is one of the task
// shapes from docs/idea/03-input-calibration.md.

const state = {
  step: 0,
  scrollValue: 5,
  cardChoice: null,
  activeTab: 'a',
  tapPoint: null,
  text: '',
};

const STEPS = [
  { key: 'scroll', name: 'Scroll selector', render: renderScroll },
  { key: 'cards', name: 'Card grid', render: renderCards },
  { key: 'tabs', name: 'Tab switcher', render: renderTabs },
  { key: 'point', name: 'Free tap', render: renderPoint },
  { key: 'text', name: 'Text entry', render: renderText },
  { key: 'review', name: 'Confirm / review', render: renderReview },
];

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

function renderPoint() {
  return `
    <p class="pattern-name">Free tap</p>
    <p class="pattern-hint">Free 2D pointing — tap anywhere in the field.</p>
    <div class="widget pointfield" onclick="onPoint(event)">
      <div class="marker" style="${state.tapPoint ? `display:block;left:${state.tapPoint.x}%;top:${state.tapPoint.y}%;` : ''}"></div>
    </div>
  `;
}
function onPoint(e) {
  const rect = e.currentTarget.getBoundingClientRect();
  state.tapPoint = {
    x: ((e.clientX - rect.left) / rect.width) * 100,
    y: ((e.clientY - rect.top) / rect.height) * 100,
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
      <div class="summary-row"><span>Free tap</span><strong>${state.tapPoint ? `${state.tapPoint.x.toFixed(0)}%, ${state.tapPoint.y.toFixed(0)}%` : '—'}</strong></div>
      <div class="summary-row"><span>Text entry</span><strong>${escapeHtml(state.text) || '—'}</strong></div>
    </div>
  `;
}

function escapeHtml(s) {
  return String(s ?? '').replace(/[&<>"']/g, c => ({'&':'&amp;','<':'&lt;','>':'&gt;','"':'&quot;',"'":'&#39;'}[c]));
}

function nextStep() { state.step = Math.min(STEPS.length - 1, state.step + 1); render(); }
function prevStep() { state.step = Math.max(0, state.step - 1); render(); }

function render() {
  const total = STEPS.length;
  document.getElementById('step-indicator').textContent = `Step ${state.step + 1} of ${total}`;
  document.getElementById('screen').innerHTML = STEPS[state.step].render();
  document.getElementById('btn-back').disabled = state.step === 0;
  document.getElementById('btn-next').textContent = state.step === total - 1 ? 'Done' : 'Next';
  document.getElementById('btn-next').onclick = state.step === total - 1 ? () => { state.step = 0; render(); } : nextStep;
  document.getElementById('dots').innerHTML = STEPS.map((_, i) =>
    `<span class="${i === state.step ? 'active' : ''}"></span>`
  ).join('');
}

const stepParam = Number(new URLSearchParams(location.search).get('step'));
if (Number.isInteger(stepParam) && stepParam >= 0 && stepParam < STEPS.length) {
  state.step = stepParam;
}
render();
