const STATIONS = [
  { id: 'TVC', name: 'Thiruvananthapuram Central' },
  { id: 'ERS', name: 'Ernakulam Jn' },
  { id: 'SRR', name: 'Shoranur Jn' },
  { id: 'MAQ', name: 'Mangaluru Central' },
  { id: 'SBC', name: 'KSR Bengaluru' },
  { id: 'MAS', name: 'Chennai Egmore' },
  { id: 'CSTM', name: 'Mumbai CSMT' },
];

const TRAINS = [
  { no: '16629', name: 'Malabar Express', dep: '19:20', arr: '06:15', dur: '10h 55m', fare: 415 },
  { no: '16345', name: 'Netravati Express', dep: '14:00', arr: '01:40', dur: '11h 40m', fare: 480 },
  { no: '22655', name: 'TV C Superfast', dep: '06:45', arr: '15:10', dur: '8h 25m', fare: 620 },
  { no: '12623', name: 'Trivandrum Mail', dep: '22:30', arr: '09:05', dur: '10h 35m', fare: 390 },
];

const TAKEN = new Set(['2A', '2C', '3B', '4F', '5A', '6D', '7C', '8E']);
const ROWS = 8;
const COLS = ['A', 'B', 'C', '', 'D', 'E', 'F'];

const S = {
  from: 'TVC',
  to: 'ERS',
  date: '2026-09-12',
  klass: 'SL',
  train: null,
  seat: null,
  name: '',
  age: '',
  gender: 'F',
  berth: 'No preference',
  mobile: '',
  otp: '',
  pnr: '4628193750',
};

function stationOptions(selected) {
  return STATIONS.map((st) =>
    `<option value="${st.id}" ${st.id === selected ? 'selected' : ''}>${st.id} — ${Aperture.escapeHtml(st.name)}</option>`
  ).join('');
}

function searchView() {
  return `
    <h1>Book a train</h1>
    <p class="lede">From, to, date, and class — then whatever is running that day.</p>
    <div class="click-div" onclick="alert('Festival specials are a mock banner. Not a real control with a role.')">Festival specials — tap for offers</div>
    <form class="panel row two" onsubmit="onSearch(event)">
      <label class="field" for="from">From
        <select id="from" name="from">${stationOptions(S.from)}</select>
      </label>
      <label class="field" for="to">To
        <select id="to" name="to">${stationOptions(S.to)}</select>
      </label>
      <label class="field" for="date">Journey date
        <input id="date" name="date" type="date" value="${S.date}" />
      </label>
      <fieldset class="field" style="border:0;padding:0">
        <legend style="font-size:0.82rem;font-weight:600;color:var(--muted);margin-bottom:6px">Class</legend>
        <div class="chips" role="group" aria-label="Class">
          ${['SL', '3A', '2A', 'CC'].map((k) =>
            `<button type="button" class="chip ${S.klass === k ? 'on' : ''}" aria-pressed="${S.klass === k}" onclick="setKlass('${k}')">${k}</button>`
          ).join('')}
        </div>
      </fieldset>
      <div class="actions" style="grid-column:1/-1">
        <button type="submit" class="btn primary">Search trains</button>
      </div>
    </form>
  `;
}

function setKlass(k) { S.klass = k; draw(); }

function onSearch(e) {
  e.preventDefault();
  const fd = new FormData(e.target);
  S.from = fd.get('from');
  S.to = fd.get('to');
  S.date = fd.get('date');
  go('results');
}

function resultsView() {
  const from = STATIONS.find((s) => s.id === S.from);
  const to = STATIONS.find((s) => s.id === S.to);
  return `
    <button class="btn" onclick="go('search')">← Change search</button>
    <h1 style="margin-top:16px">${from.id} → ${to.id}</h1>
    <p class="lede">${S.date} · ${S.klass} · ${TRAINS.length} trains</p>
    <div class="row">
      ${TRAINS.map((t) => `
        <button type="button" class="list-btn" onclick="pickTrain('${t.no}')">
          <span>
            <strong>${t.no} ${Aperture.escapeHtml(t.name)}</strong><br>
            <span class="meta">${t.dep} → ${t.arr} · ${t.dur}</span>
          </span>
          <span>₹${t.fare}<br><span class="meta">Book</span></span>
        </button>
      `).join('')}
    </div>
  `;
}

function pickTrain(no) {
  S.train = TRAINS.find((t) => t.no === no);
  go('seats');
}

function seatsView() {
  const cells = [];
  for (let r = 1; r <= ROWS; r++) {
    for (const col of COLS) {
      if (!col) {
        cells.push('<span class="seat aisle" aria-hidden="true"></span>');
        continue;
      }
      const id = `${r}${col}`;
      const taken = TAKEN.has(id);
      const mine = S.seat === id;
      const label = taken ? `Seat ${id} taken` : mine ? `Seat ${id} selected` : `Seat ${id} available`;
      cells.push(
        `<button type="button" class="seat ${taken ? 'taken' : ''} ${mine ? 'mine' : ''}"
          aria-label="${label}" ${taken ? 'disabled' : ''} onclick="pickSeat('${id}')">${id}</button>`
      );
    }
  }
  return `
    <button class="btn" onclick="go('results')">← All trains</button>
    <h1 style="margin-top:16px">${S.train.no} · pick a seat</h1>
    <p class="lede">Coach S1 · tap a seat. Orange is yours.</p>
    <div class="panel">
      <div class="seat-map" role="group" aria-label="Seat map">${cells.join('')}</div>
      <p class="lede" style="margin:0">${S.seat ? `Selected ${S.seat}` : 'No seat yet.'}</p>
      <div class="actions">
        <button type="button" class="btn primary" ${S.seat ? '' : 'disabled'} onclick="go('passenger')">Continue with ${S.seat || 'seat'}</button>
      </div>
    </div>
  `;
}

function pickSeat(id) { S.seat = id; draw(); }

function passengerView() {
  return `
    <button class="btn" onclick="go('seats')">← Seat map</button>
    <h1 style="margin-top:16px">Passenger details</h1>
    <p class="lede">${S.train.name} · seat ${S.seat} · ${S.klass}</p>
    <form class="panel row two" onsubmit="onPassenger(event)">
      <label class="field" for="pname">Full name
        <input id="pname" name="name" required value="${Aperture.escapeHtml(S.name)}" autocomplete="name" />
      </label>
      <label class="field" for="age">Age
        <input id="age" name="age" type="number" min="1" max="120" required value="${Aperture.escapeHtml(S.age)}" />
      </label>
      <label class="field" for="gender">Gender
        <select id="gender" name="gender">
          <option ${S.gender === 'F' ? 'selected' : ''}>F</option>
          <option ${S.gender === 'M' ? 'selected' : ''}>M</option>
          <option ${S.gender === 'X' ? 'selected' : ''}>X</option>
        </select>
      </label>
      <label class="field" for="berth">Berth preference
        <select id="berth" name="berth">
          ${['No preference', 'Lower', 'Middle', 'Upper', 'Side lower'].map((b) =>
            `<option ${S.berth === b ? 'selected' : ''}>${b}</option>`
          ).join('')}
        </select>
      </label>
      <label class="field" for="mobile">Mobile
        <input id="mobile" name="mobile" inputmode="numeric" required value="${Aperture.escapeHtml(S.mobile)}" />
      </label>
      <div class="actions" style="grid-column:1/-1">
        <button type="submit" class="btn primary">Go to payment</button>
      </div>
    </form>
  `;
}

function onPassenger(e) {
  e.preventDefault();
  const fd = new FormData(e.target);
  S.name = fd.get('name');
  S.age = fd.get('age');
  S.gender = fd.get('gender');
  S.berth = fd.get('berth');
  S.mobile = fd.get('mobile');
  go('pay');
}

function payView() {
  return `
    <button class="btn" onclick="go('passenger')">← Passenger</button>
    <h1 style="margin-top:16px">Pay ₹${S.train.fare}</h1>
    <p class="lede">Mock UPI. The OTP is <strong>482193</strong> — typed here so a demo never waits on SMS.</p>
    <form class="panel row" onsubmit="onPay(event)">
      <label class="field" for="upi">UPI ID
        <input id="upi" name="upi" placeholder="name@bank" required />
      </label>
      <label class="field" for="otp">OTP
        <input id="otp" name="otp" inputmode="numeric" maxlength="6" required value="${Aperture.escapeHtml(S.otp)}" />
      </label>
      <div class="actions">
        <button type="submit" class="btn primary">Confirm and pay</button>
      </div>
    </form>
  `;
}

function onPay(e) {
  e.preventDefault();
  const otp = new FormData(e.target).get('otp');
  if (otp !== '482193') {
    alert('OTP is 482193 on this mock.');
    return;
  }
  S.otp = otp;
  go('done');
}

function doneView() {
  const trainLine = S.train
    ? `${S.train.no} ${Aperture.escapeHtml(S.train.name)}`
    : 'Looked up from PNR';
  const who = S.name ? Aperture.escapeHtml(S.name) + ' · ' : '';
  return `
    <div class="panel done">
      <span class="badge">Ticket booked</span>
      <div class="pnr" aria-label="PNR">PNR ${S.pnr}</div>
      <p>${who}${trainLine}</p>
      <p class="lede">${S.from} → ${S.to} · ${S.date}${S.seat ? ` · seat ${S.seat}` : ''} · ${S.klass}</p>
      <div class="actions">
        <a class="btn primary" href="rail.html">Book another</a>
        <a class="btn" href="index.html">Back to Daily</a>
      </div>
    </div>
  `;
}

function pnrView() {
  return `
    <h1>PNR status</h1>
    <p class="lede">Look up a mock ticket. Try ${S.pnr} after a booking, or any 10 digits.</p>
    <form class="panel" onsubmit="event.preventDefault(); go('done')">
      <label class="field" for="pnr">PNR
        <input id="pnr" name="pnr" inputmode="numeric" maxlength="10" value="${S.pnr}" />
      </label>
      <div class="actions"><button class="btn primary" type="submit">Check status</button></div>
    </form>
  `;
}

const views = {
  search: searchView,
  results: resultsView,
  seats: seatsView,
  passenger: passengerView,
  pay: payView,
  done: doneView,
  pnr: pnrView,
};

function go(screen) {
  S.screen = screen;
  Aperture.gotoScreen(screen);
  draw();
}

function draw() {
  let screen = views[S.screen] ? S.screen : (Aperture.screenParam() || 'search');
  if (!views[screen]) screen = 'search';
  if (['seats', 'passenger', 'pay'].includes(screen) && !S.train) screen = 'search';
  S.screen = screen;
  document.title = `RailLink — ${S.screen}`;
  document.getElementById('app').innerHTML = views[S.screen]();
}

Aperture.bindPop((s) => { S.screen = s || 'search'; draw(); });
S.screen = Aperture.screenParam() || 'search';
draw();
