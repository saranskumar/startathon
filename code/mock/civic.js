const SERVICES = [
  { id: 'income', name: 'Income certificate', days: '7 working days' },
  { id: 'reside', name: 'Residence certificate', days: '5 working days' },
  { id: 'caste', name: 'Caste certificate', days: '12 working days' },
  { id: 'birth', name: 'Birth certificate copy', days: '3 working days' },
];

const S = {
  service: null,
  fullName: '',
  parent: '',
  dob: '1998-04-11',
  aadhaar: '',
  mobile: '',
  email: '',
  house: '',
  street: '',
  village: '',
  district: 'Thiruvananthapuram',
  pincode: '',
  purpose: '',
  declare: false,
  captcha: '',
  appNo: 'CD-2026-18441',
};

function servicesView() {
  return `
    <h1>Choose a service</h1>
    <p class="lede">Village-office certificates. Pick one service to start an application.</p>
    <div class="row">
      ${SERVICES.map((s) => `
        <button type="button" class="list-btn" onclick="pickService('${s.id}')">
          <span><strong>${Aperture.escapeHtml(s.name)}</strong><br><span class="meta">Village office · ${s.days}</span></span>
          <span class="meta">Apply</span>
        </button>
      `).join('')}
    </div>
  `;
}

function pickService(id) {
  S.service = SERVICES.find((s) => s.id === id);
  go('form');
}

function formView() {
  return `
    <button class="btn" onclick="go('services')">← Services</button>
    <h1 style="margin-top:16px">${Aperture.escapeHtml(S.service.name)}</h1>
    <p class="lede">Fields marked <span class="req">*</span> are required. Particulars must match your records.</p>
    <form class="panel" onsubmit="onForm(event)">
      <p class="section-title">Applicant</p>
      <div class="row two">
        <label class="field" for="fullName">Full name <span class="req">*</span>
          <input id="fullName" name="fullName" required value="${Aperture.escapeHtml(S.fullName)}" />
        </label>
        <label class="field" for="parent">Parent / guardian <span class="req">*</span>
          <input id="parent" name="parent" required value="${Aperture.escapeHtml(S.parent)}" />
        </label>
        <label class="field" for="dob">Date of birth <span class="req">*</span>
          <input id="dob" name="dob" type="date" required value="${S.dob}" />
        </label>
        <label class="field" for="aadhaar">Aadhaar (dummy) <span class="req">*</span>
          <input id="aadhaar" name="aadhaar" inputmode="numeric" maxlength="12" required value="${Aperture.escapeHtml(S.aadhaar)}" />
        </label>
        <label class="field" for="mobile">Mobile <span class="req">*</span>
          <input id="mobile" name="mobile" inputmode="numeric" required value="${Aperture.escapeHtml(S.mobile)}" />
        </label>
        <label class="field" for="email">Email
          <input id="email" name="email" type="email" value="${Aperture.escapeHtml(S.email)}" />
        </label>
      </div>
      <p class="section-title">Address</p>
      <div class="row two">
        <label class="field" for="house">House / ward <span class="req">*</span>
          <input id="house" name="house" required value="${Aperture.escapeHtml(S.house)}" />
        </label>
        <label class="field" for="street">Street
          <input id="street" name="street" value="${Aperture.escapeHtml(S.street)}" />
        </label>
        <label class="field" for="village">Village / city <span class="req">*</span>
          <input id="village" name="village" required value="${Aperture.escapeHtml(S.village)}" />
        </label>
        <label class="field" for="district">District <span class="req">*</span>
          <select id="district" name="district">
            ${['Thiruvananthapuram', 'Kollam', 'Pathanamthitta', 'Alappuzha', 'Kottayam', 'Ernakulam'].map((d) =>
              `<option ${S.district === d ? 'selected' : ''}>${d}</option>`
            ).join('')}
          </select>
        </label>
        <label class="field" for="pincode">PIN code <span class="req">*</span>
          <input id="pincode" name="pincode" inputmode="numeric" maxlength="6" required value="${Aperture.escapeHtml(S.pincode)}" />
        </label>
        <label class="field" for="purpose">Purpose <span class="req">*</span>
          <input id="purpose" name="purpose" required value="${Aperture.escapeHtml(S.purpose)}" placeholder="Bank loan, school admission…" />
        </label>
      </div>
      <p class="section-title">Upload (mock)</p>
      <label class="field" for="proof">Address proof
        <input id="proof" name="proof" type="file" />
      </label>
      <div class="actions">
        <button type="submit" class="btn primary">Review application</button>
      </div>
    </form>
  `;
}

function onForm(e) {
  e.preventDefault();
  const fd = new FormData(e.target);
  for (const k of ['fullName', 'parent', 'dob', 'aadhaar', 'mobile', 'email', 'house', 'street', 'village', 'district', 'pincode', 'purpose']) {
    S[k] = fd.get(k);
  }
  go('review');
}

function reviewView() {
  const rows = [
    ['Service', S.service.name],
    ['Name', S.fullName],
    ['Parent', S.parent],
    ['DOB', S.dob],
    ['Aadhaar', S.aadhaar],
    ['Mobile', S.mobile],
    ['Address', `${S.house}, ${S.village}, ${S.district} ${S.pincode}`],
    ['Purpose', S.purpose],
  ];
  return `
    <button class="btn" onclick="go('form')">← Edit form</button>
    <h1 style="margin-top:16px">Review and declare</h1>
    <p class="lede">Type the code <strong>K7M2</strong>, tick the declaration, then submit. That is the consequential action.</p>
    <div class="panel">
      ${rows.map(([k, v]) => `
        <div style="display:flex;justify-content:space-between;gap:12px;padding:8px 0;border-bottom:1px solid var(--line)">
          <span class="lede" style="margin:0">${k}</span><strong>${Aperture.escapeHtml(v)}</strong>
        </div>
      `).join('')}
      <form style="margin-top:16px" onsubmit="onReview(event)">
        <label class="field" for="captcha">Type the code K7M2
          <input id="captcha" name="captcha" required value="${Aperture.escapeHtml(S.captcha)}" autocomplete="off" />
        </label>
        <label style="display:flex;gap:8px;align-items:flex-start;margin:14px 0;font-size:0.9rem">
          <input type="checkbox" name="declare" ${S.declare ? 'checked' : ''} />
          I declare the particulars are true to the best of my knowledge.
        </label>
        <button type="submit" class="btn primary">Submit application</button>
      </form>
    </div>
  `;
}

function onReview(e) {
  e.preventDefault();
  const fd = new FormData(e.target);
  if (String(fd.get('captcha')).toUpperCase() !== 'K7M2') {
    alert('The code is K7M2 on this mock.');
    return;
  }
  if (!fd.get('declare')) {
    alert('Tick the declaration to submit.');
    return;
  }
  S.captcha = fd.get('captcha');
  S.declare = true;
  go('done');
}

function doneView() {
  return `
    <div class="panel done">
      <span class="badge">Filed</span>
      <div class="big">${S.appNo}</div>
      <p>${Aperture.escapeHtml(S.service.name)} for ${Aperture.escapeHtml(S.fullName)}</p>
      <p class="lede">Village office · expected in ${S.service.days}. Nothing was sent anywhere.</p>
      <div class="actions">
        <a class="btn primary" href="civic.html">New application</a>
        <a class="btn" href="index.html">Back to Daily</a>
      </div>
    </div>
  `;
}

function statusView() {
  return `
    <h1>Track application</h1>
    <form class="panel" onsubmit="event.preventDefault(); go('done')">
      <label class="field" for="app">Application number
        <input id="app" value="${S.appNo}" />
      </label>
      <div class="actions"><button class="btn primary" type="submit">Track</button></div>
    </form>
  `;
}

const views = { services: servicesView, form: formView, review: reviewView, done: doneView, status: statusView };

function go(screen) {
  S.screen = screen;
  Aperture.gotoScreen(screen);
  draw();
}

function draw() {
  let screen = views[S.screen] ? S.screen : (Aperture.screenParam() || 'services');
  if (!views[screen]) screen = 'services';
  if (['form', 'review'].includes(screen) && !S.service) screen = 'services';
  if (screen === 'done' && !S.service) S.service = SERVICES[0];
  S.screen = screen;
  document.title = `CivicDesk — ${S.screen}`;
  document.getElementById('app').innerHTML = views[S.screen]();
}

Aperture.bindPop((s) => { S.screen = s || 'services'; draw(); });
S.screen = Aperture.screenParam() || 'services';
draw();
