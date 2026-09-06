const PEOPLE = [
  { id: 'anaya', name: 'Anaya Krishnan', upi: 'anaya@okbank', last: '₹200 · yesterday' },
  { id: 'farhan', name: 'Farhan Ali', upi: 'farhan@upi', last: '₹50 · Mon' },
  { id: 'meera', name: 'Meera Nair', upi: 'meera@pay', last: '₹1,200 · 12 Aug' },
  { id: 'ravi', name: 'Ravi Kumar', upi: 'ravi@okbank', last: '₹20 · Fri' },
];

const BILLS = [
  { id: 'elec', name: 'KSEB electricity', meta: 'Consumer 1844 2291' },
  { id: 'water', name: 'KWA water', meta: 'Can 33-9021' },
  { id: 'mobile', name: 'Mobile prepaid', meta: '98xxx 44120' },
  { id: 'gas', name: 'LPG refill', meta: 'HP 2291' },
];

const S = {
  payee: null,
  amount: '',
  note: '',
  pin: '',
  ref: 'NP9K2M184',
};

function homeView() {
  return `
    <h1>Send money</h1>
    <p class="lede">People you already pay, and the usual bills.</p>
    <label class="field" for="find">Search payee
      <input id="find" placeholder="Name or UPI ID" oninput="onFind(this.value)" />
    </label>
    <p class="section-title" style="color:var(--brand)">People</p>
    <div class="row" id="people">${peopleList(PEOPLE)}</div>
    <div class="actions">
      <button type="button" class="btn" onclick="go('bills')">Pay a bill</button>
    </div>
  `;
}

function onFind(q) {
  const t = q.trim().toLowerCase();
  const list = PEOPLE.filter((p) => !t || p.name.toLowerCase().includes(t) || p.upi.includes(t));
  document.getElementById('people').innerHTML = peopleList(list);
}

function peopleList(list) {
  if (!list.length) return '<p class="lede">No match.</p>';
  return list.map((p) => `
    <button type="button" class="list-btn" onclick="pickPayee('${p.id}','person')">
      <span><strong>${Aperture.escapeHtml(p.name)}</strong><br><span class="meta">${p.upi}</span></span>
      <span class="meta">${p.last}</span>
    </button>
  `).join('');
}

function billsView() {
  return `
    <button class="btn" onclick="go('home')">← Home</button>
    <h1 style="margin-top:16px">Bills</h1>
    <p class="lede">Four billers. Each one opens the same amount screen.</p>
    <div class="row">
      ${BILLS.map((b) => `
        <button type="button" class="list-btn" onclick="pickPayee('${b.id}','bill')">
          <span><strong>${Aperture.escapeHtml(b.name)}</strong><br><span class="meta">${b.meta}</span></span>
          <span class="meta">Pay</span>
        </button>
      `).join('')}
    </div>
  `;
}

function pickPayee(id, kind) {
  S.payee = kind === 'bill' ? BILLS.find((b) => b.id === id) : PEOPLE.find((p) => p.id === id);
  S.kind = kind;
  go('amount');
}

function amountView() {
  const p = S.payee;
  return `
    <button class="btn" onclick="go(S.kind === 'bill' ? 'bills' : 'home')">← Back</button>
    <h1 style="margin-top:16px">Pay ${Aperture.escapeHtml(p.name)}</h1>
    <p class="lede">${p.upi || p.meta}</p>
    <form class="panel row" onsubmit="onAmount(event)">
      <label class="field" for="amount">Amount (₹)
        <input id="amount" name="amount" inputmode="decimal" required value="${Aperture.escapeHtml(S.amount)}" />
      </label>
      <label class="field" for="note">Note
        <input id="note" name="note" value="${Aperture.escapeHtml(S.note)}" placeholder="Optional" />
      </label>
      <div class="actions">
        <button type="submit" class="btn primary">Continue to PIN</button>
      </div>
    </form>
  `;
}

function onAmount(e) {
  e.preventDefault();
  const fd = new FormData(e.target);
  S.amount = fd.get('amount');
  S.note = fd.get('note');
  S.pin = '';
  go('pin');
}

function pinView() {
  const dots = '•'.repeat(S.pin.length) + '·'.repeat(Math.max(0, 4 - S.pin.length));
  const keys = ['1', '2', '3', '4', '5', '6', '7', '8', '9', '⌫', '0', 'OK'];
  return `
    <button class="btn" onclick="go('amount')">← Amount</button>
    <h1 style="margin-top:16px">Enter UPI PIN</h1>
    <p class="lede">Mock PIN is <strong>2580</strong>. Four digits, then OK.</p>
    <div class="panel">
      <p class="pin-dots" aria-live="polite" aria-label="PIN length ${S.pin.length} of 4">${dots}</p>
      <div class="pin-pad" role="group" aria-label="PIN pad">
        ${keys.map((k) => {
          const label = k === '⌫' ? 'Delete last PIN digit' : k === 'OK' ? 'Confirm PIN' : `PIN digit ${k}`;
          return `<button type="button" class="btn ${k === 'OK' ? 'primary' : ''}" aria-label="${label}" onclick="onPinKey('${k}')">${k}</button>`;
        }).join('')}
      </div>
    </div>
  `;
}

function onPinKey(k) {
  if (k === '⌫') S.pin = S.pin.slice(0, -1);
  else if (k === 'OK') {
    if (S.pin !== '2580') { alert('PIN is 2580 on this mock.'); return; }
    go('done');
    return;
  } else if (S.pin.length < 4) S.pin += k;
  draw();
}

function doneView() {
  return `
    <div class="panel done">
      <span class="badge">Paid</span>
      <div class="big">₹${Aperture.escapeHtml(S.amount)}</div>
      <p>to ${Aperture.escapeHtml(S.payee.name)}</p>
      <p class="lede">Ref ${S.ref}${S.note ? ` · ${Aperture.escapeHtml(S.note)}` : ''}</p>
      <div class="actions">
        <a class="btn primary" href="pay.html">New payment</a>
        <a class="btn" href="index.html">Back to Daily</a>
      </div>
    </div>
  `;
}

const views = { home: homeView, bills: billsView, amount: amountView, pin: pinView, done: doneView };

function go(screen) {
  S.screen = screen;
  Aperture.gotoScreen(screen);
  draw();
}

function draw() {
  let screen = views[S.screen] ? S.screen : (Aperture.screenParam() || 'home');
  if (!views[screen]) screen = 'home';
  if (['amount', 'pin', 'done'].includes(screen) && !S.payee) screen = 'home';
  S.screen = screen;
  document.title = `NagarPay — ${S.screen}`;
  document.getElementById('app').innerHTML = views[S.screen]();
}

Aperture.bindPop((s) => { S.screen = s || 'home'; draw(); });
S.screen = Aperture.screenParam() || 'home';
draw();
