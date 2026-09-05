// Aperture — a normal, everyday website (video browsing, settings, a
// feedback form). This is the *target application* the real adaptive
// system will eventually operate on — it deliberately has no
// accessibility-profile UI of its own. That logic lives on the
// phone/remote-control side (see docs/idea/07-architecture.md).

const VIDEOS = [
  { id: 1, title: 'Morning walk vlog' },
  { id: 2, title: 'How radios work' },
  { id: 3, title: 'Kitchen tips #12' },
  { id: 4, title: 'City drone tour' },
  { id: 5, title: 'Guitar lesson 3' },
  { id: 6, title: 'Garden update' },
  { id: 7, title: 'Quiz night highlights' },
  { id: 8, title: 'Train journey, Kerala' },
];

const state = {
  route: 'home',
  selectedVideo: null,
  playing: false,
  seek: 20,
  settingsTab: 'display',
  fontStep: 1,
  notifCorner: null,
  searchQuery: '',
  form: { name: '', preference: null, comment: '' },
};

function goto(route) {
  state.route = route;
  location.hash = '/' + route;
  render();
  window.scrollTo({ top: 0, behavior: 'instant' });
}

function routeFromHash() {
  const route = (location.hash || '').replace(/^#\/?/, '').split('/')[0];
  return ROUTES[route] ? route : 'home';
}

window.addEventListener('hashchange', () => {
  state.route = routeFromHash();
  if (state.route === 'player' && !state.selectedVideo) state.selectedVideo = VIDEOS[0];
  render();
});

function skeleton(cls) { return `<div class="skeleton-block ${cls || ''}"></div>`; }

// ---------- Screens ----------

function renderHome() {
  return `
    <h1>Aperture</h1>
    <p class="hint">Watch something, tweak your settings, or send us feedback.</p>
    <h2>Continue watching</h2>
    <div class="grid">
      ${VIDEOS.slice(0, 3).map(videoCard).join('')}
    </div>
    <div class="actions">
      <button class="btn primary" onclick="goto('videos')">Browse all videos</button>
    </div>
  `;
}

function videoCard(v) {
  return `
    <button class="card" onclick="openVideo(${v.id})">
      <div class="thumb skeleton-block"></div>
      <span class="title">${escapeHtml(v.title)}</span>
    </button>
  `;
}

function renderVideos() {
  const items = VIDEOS.filter(v =>
    !state.searchQuery || v.title.toLowerCase().includes(state.searchQuery.toLowerCase())
  );
  return `
    <h1>Videos</h1>
    <div class="searchbar">
      <input placeholder="Search" value="${escapeHtml(state.searchQuery)}" oninput="onSearchInput(this.value)" />
    </div>
    <div class="grid">
      ${items.map(videoCard).join('') || '<p class="hint">No matches.</p>'}
    </div>
  `;
}

function onSearchInput(v) { state.searchQuery = v; render(); }

function openVideo(id) {
  state.selectedVideo = VIDEOS.find(v => v.id === id);
  state.playing = false;
  state.seek = 0;
  goto('player');
}

function renderPlayer() {
  const v = state.selectedVideo;
  if (!v) return renderVideos();
  return `
    <h1>${escapeHtml(v.title)}</h1>
    <div class="player-art skeleton-block"></div>
    <div class="controls-row">
      <button class="btn primary" onclick="togglePlay()">${state.playing ? 'Pause' : 'Play'}</button>
      <span>${state.seek}s</span>
      <input type="range" min="0" max="120" value="${state.seek}" oninput="onSeek(this.value)" />
    </div>
    <div class="actions">
      <button class="btn" onclick="goto('videos')">Back to videos</button>
    </div>
  `;
}

function togglePlay() { state.playing = !state.playing; render(); }
function onSeek(v) { state.seek = Number(v); render(); }

function renderSettings() {
  const tabs = [
    { id: 'display', label: 'Display' },
    { id: 'sound', label: 'Sound' },
    { id: 'notifications', label: 'Notifications' },
    { id: 'about', label: 'About' },
  ];
  return `
    <h1>Settings</h1>
    <div class="tabbar">
      ${tabs.map(t => `<button class="${state.settingsTab === t.id ? 'active' : ''}" onclick="setTab('${t.id}')">${t.label}</button>`).join('')}
    </div>
    ${renderSettingsTab()}
  `;
}

function setTab(id) {
  state.settingsTab = id;
  location.hash = '/settings/' + id;
  render();
}

function renderSettingsTab() {
  if (state.settingsTab === 'display') {
    const sizes = ['Small', 'Medium', 'Large'];
    return `
      <div class="field">
        <label>Text size — ${sizes[state.fontStep]}</label>
        <input type="range" min="0" max="2" value="${state.fontStep}" oninput="onFontStep(this.value)" />
      </div>
    `;
  }
  if (state.settingsTab === 'notifications') {
    return `
      <div class="field">
        <label>Where should notifications appear?</label>
        <div class="pointfield" onclick="onPointTap(event)">
          <div class="marker" id="marker" style="${state.notifCorner ? `display:block;left:${state.notifCorner.x}%;top:${state.notifCorner.y}%;` : ''}"></div>
        </div>
        <p class="hint">Tap anywhere on the preview to place it.</p>
      </div>
    `;
  }
  if (state.settingsTab === 'sound') {
    return `<p class="hint">Sound settings.</p>`;
  }
  return `<p class="hint">Aperture, a small video app built for a demo.</p>`;
}

function onFontStep(v) {
  state.fontStep = Number(v);
  document.documentElement.style.setProperty('font-size', [14, 16, 19][state.fontStep] + 'px');
  render();
}

function onPointTap(e) {
  const rect = e.currentTarget.getBoundingClientRect();
  state.notifCorner = {
    x: ((e.clientX - rect.left) / rect.width) * 100,
    y: ((e.clientY - rect.top) / rect.height) * 100,
  };
  render();
}

function renderForm() {
  return `
    <h1>Feedback</h1>
    <div class="field">
      <label>Name</label>
      <input value="${escapeHtml(state.form.name)}" oninput="onFormField('name', this.value)" />
    </div>
    <div class="field">
      <label>How should we follow up?</label>
      <div class="pref-row">
        ${['Email me', 'Call me', 'No contact'].map(p => `<button class="btn ${state.form.preference === p ? 'selected' : ''}" onclick="onFormField('preference', '${p}')">${p}</button>`).join('')}
      </div>
    </div>
    <div class="field">
      <label>Comment</label>
      <textarea rows="3" oninput="onFormField('comment', this.value)">${escapeHtml(state.form.comment)}</textarea>
    </div>
    <div class="actions">
      <button class="btn primary" onclick="goto('review')">Review</button>
    </div>
  `;
}

function onFormField(field, value) { state.form[field] = value; render(); }

function renderReview() {
  const f = state.form;
  return `
    <h1>Review &amp; submit</h1>
    <div class="summary-row"><span>Name</span><strong>${escapeHtml(f.name) || '—'}</strong></div>
    <div class="summary-row"><span>Follow-up</span><strong>${escapeHtml(f.preference || '—')}</strong></div>
    <div class="summary-row"><span>Comment</span><strong>${escapeHtml(f.comment) || '—'}</strong></div>
    <div class="actions">
      <button class="btn" onclick="goto('form')">Edit</button>
      <button class="btn primary" onclick="onConfirmSubmit()">Submit</button>
    </div>
  `;
}

function onConfirmSubmit() {
  // In the real system, this is where the agent fills + submits the
  // actual Google Form built for the demo (docs/idea/05-scope.md).
  // Not wired here — Aperture is a UI-only stand-in.
  goto('done');
}

function renderDone() {
  return `
    <h1>Thanks!</h1>
    <p class="hint">Your feedback was recorded.</p>
    <button class="btn primary" onclick="resetForm()">Back to home</button>
  `;
}

function resetForm() {
  state.form = { name: '', preference: null, comment: '' };
  goto('home');
}

function escapeHtml(s) {
  return String(s ?? '').replace(/[&<>"']/g, c => ({'&':'&amp;','<':'&lt;','>':'&gt;','"':'&quot;',"'":'&#39;'}[c]));
}

const ROUTES = {
  home: renderHome,
  videos: renderVideos,
  player: renderPlayer,
  settings: renderSettings,
  form: renderForm,
  review: renderReview,
  done: renderDone,
};

function render() {
  document.querySelectorAll('#nav button[data-route]').forEach(b => {
    b.classList.toggle('active', b.dataset.route === state.route);
  });
  document.getElementById('screen').innerHTML = ROUTES[state.route]();
}

state.route = routeFromHash();
if (state.route === 'player' && !state.selectedVideo) state.selectedVideo = VIDEOS[0];
if (state.route === 'settings') state.settingsTab = (location.hash.split('/')[2]) || 'display';
render();
