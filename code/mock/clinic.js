const SPECS = ['General', 'Ortho', 'ENT', 'Paediatrics', 'Skin'];

const DOCS = [
  { id: 'nair', name: 'Dr. Latha Nair', spec: 'General', years: 14, next: 'Today' },
  { id: 'menon', name: 'Dr. Arun Menon', spec: 'General', years: 9, next: 'Tomorrow' },
  { id: 'rao', name: 'Dr. Priya Rao', spec: 'Ortho', years: 11, next: 'Wed' },
  { id: 'ibrahim', name: 'Dr. Samir Ibrahim', spec: 'ENT', years: 8, next: 'Today' },
  { id: 'george', name: 'Dr. Hannah George', spec: 'Paediatrics', years: 16, next: 'Thu' },
  { id: 'das', name: 'Dr. Kavya Das', spec: 'Skin', years: 7, next: 'Tomorrow' },
];

const SLOTS = ['09:00', '09:30', '10:15', '11:00', '14:00', '14:45', '16:10', '17:00'];

const S = {
  spec: 'General',
  doc: null,
  day: 12,
  slot: null,
  patient: '',
  phone: '',
  reason: '',
};

function initials(name) {
  return name.replace('Dr. ', '').split(' ').map((w) => w[0]).join('').slice(0, 2);
}

function doctorsView() {
  const list = DOCS.filter((d) => d.spec === S.spec);
  return `
    <h1>Find a doctor</h1>
    <p class="lede">Choose a specialty, then a doctor. Next you’ll pick a day and a time.</p>
    <div class="chips" role="tablist" aria-label="Specialty">
      ${SPECS.map((s) =>
        `<button type="button" role="tab" class="chip ${S.spec === s ? 'on' : ''}" aria-selected="${S.spec === s}" onclick="setSpec('${s}')">${s}</button>`
      ).join('')}
    </div>
    <div class="row" style="margin-top:14px">
      ${list.map((d) => `
        <button type="button" class="list-btn" onclick="pickDoc('${d.id}')">
          <span class="doc">
            <span class="avatar" aria-hidden="true">${initials(d.name)}</span>
            <span><strong>${Aperture.escapeHtml(d.name)}</strong><br>
            <span class="meta">${d.spec} · ${d.years} yrs · next ${d.next}</span></span>
          </span>
          <span class="meta">Book</span>
        </button>
      `).join('')}
    </div>
  `;
}

function setSpec(s) { S.spec = s; draw(); }
function pickDoc(id) { S.doc = DOCS.find((d) => d.id === id); go('cal'); }

function calView() {
  const dows = ['Su', 'Mo', 'Tu', 'We', 'Th', 'Fr', 'Sa'];
  const first = 2; // Sep 2026 starts Tuesday
  const days = 30;
  const cells = [];
  for (const d of dows) cells.push(`<div class="dow">${d}</div>`);
  for (let i = 0; i < first; i++) cells.push('<span></span>');
  for (let n = 1; n <= days; n++) {
    const past = n < 6;
    cells.push(
      `<button type="button" class="day ${S.day === n ? 'on' : ''}" ${past ? 'disabled' : ''}
        aria-label="September ${n}${S.day === n ? ', selected' : ''}" onclick="pickDay(${n})">${n}</button>`
    );
  }
  return `
    <button class="btn" onclick="go('doctors')">← Doctors</button>
    <h1 style="margin-top:16px">${Aperture.escapeHtml(S.doc.name)}</h1>
    <p class="lede">September 2026 · pick a day, then a slot.</p>
    <div class="panel">
      <div class="cal" role="grid" aria-label="September 2026">${cells.join('')}</div>
      <p class="lede" style="margin:14px 0 8px">Times on the ${S.day}th</p>
      <div class="chips" role="group" aria-label="Time slots">
        ${SLOTS.map((t) =>
          `<button type="button" class="chip ${S.slot === t ? 'on' : ''}" aria-pressed="${S.slot === t}" onclick="pickSlot('${t}')">${t}</button>`
        ).join('')}
      </div>
      <div class="actions">
        <button type="button" class="btn primary" ${S.slot ? '' : 'disabled'} onclick="go('patient')">Continue</button>
      </div>
    </div>
  `;
}

function pickDay(n) { S.day = n; draw(); }
function pickSlot(t) { S.slot = t; draw(); }

function patientView() {
  return `
    <button class="btn" onclick="go('cal')">← Calendar</button>
    <h1 style="margin-top:16px">Patient details</h1>
    <p class="lede">${S.doc.name} · 12 Sep is a sample; you picked the ${S.day}th at ${S.slot}.</p>
    <form class="panel row" onsubmit="onPatient(event)">
      <label class="field" for="patient">Patient name
        <input id="patient" name="patient" required value="${Aperture.escapeHtml(S.patient)}" />
      </label>
      <label class="field" for="phone">Phone
        <input id="phone" name="phone" inputmode="numeric" required value="${Aperture.escapeHtml(S.phone)}" />
      </label>
      <label class="field" for="reason">Reason for visit
        <textarea id="reason" name="reason" rows="3">${Aperture.escapeHtml(S.reason)}</textarea>
      </label>
      <div class="actions">
        <button type="submit" class="btn primary">Confirm appointment</button>
      </div>
    </form>
  `;
}

function onPatient(e) {
  e.preventDefault();
  const fd = new FormData(e.target);
  S.patient = fd.get('patient');
  S.phone = fd.get('phone');
  S.reason = fd.get('reason');
  go('done');
}

function doneView() {
  return `
    <div class="panel done">
      <span class="badge">Booked</span>
      <div class="big">${S.slot} · ${S.day} Sep</div>
      <p>${Aperture.escapeHtml(S.patient)} with ${Aperture.escapeHtml(S.doc.name)}</p>
      <p class="lede">${S.doc.spec} · token will show at the desk. Mock only.</p>
      <div class="actions">
        <a class="btn primary" href="clinic.html">Book another</a>
        <a class="btn" href="index.html">Back to Daily</a>
      </div>
    </div>
  `;
}

function mineView() {
  return `
    <h1>My visits</h1>
    <p class="lede">Empty until you book in this tab. After a booking, open this from the hub with the same browser.</p>
    <div class="panel"><p class="lede" style="margin:0">No saved visits on this mock — the last confirmation is the record.</p></div>
  `;
}

const views = { doctors: doctorsView, cal: calView, patient: patientView, done: doneView, mine: mineView };

function go(screen) {
  S.screen = screen;
  Aperture.gotoScreen(screen);
  draw();
}

function draw() {
  let screen = views[S.screen] ? S.screen : (Aperture.screenParam() || 'doctors');
  if (!views[screen]) screen = 'doctors';
  if (['cal', 'patient', 'done'].includes(screen) && !S.doc) screen = 'doctors';
  S.screen = screen;
  document.title = `ClinicSlot — ${S.screen}`;
  document.getElementById('app').innerHTML = views[S.screen]();
}

Aperture.bindPop((s) => { S.screen = s || 'doctors'; draw(); });
S.screen = Aperture.screenParam() || 'doctors';
draw();
