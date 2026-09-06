const MAIL = [
  {
    id: 't1',
    from: 'RailLink',
    subject: 'Your PNR 4628193750 is confirmed',
    preview: 'TVC → ERS · 12 Sep · seat 4A',
    body: 'Hello,\n\nThis is a mock ticket confirmation from RailLink.\n\nPNR 4628193750\nTVC → ERS · 12 Sep · Malabar Express\nSeat 4A · SL\n\nNothing was booked. This inbox is only a target page.',
    time: '08:14',
  },
  {
    id: 't2',
    from: 'NagarPay',
    subject: 'KSEB bill is due in 3 days',
    preview: '₹1,140 · consumer 1844 2291',
    body: 'Your electricity bill of ₹1,140 is due on 9 Sep.\n\nPay it from the NagarPay mock if you want the full money flow.',
    time: 'Yesterday',
  },
  {
    id: 't3',
    from: 'ClinicSlot',
    subject: 'Reminder: Dr. Latha Nair',
    preview: 'Tomorrow 10:15 · General',
    body: 'You have a mock visit with Dr. Latha Nair tomorrow at 10:15.\n\nBring nothing. This clinic does not exist.',
    time: 'Mon',
  },
  {
    id: 't4',
    from: 'CivicDesk',
    subject: 'Application CD-2026-18441 received',
    preview: 'Income certificate · village office',
    body: 'We have your mock income-certificate application.\n\nExpected in 7 working days. No officer will call.',
    time: '12 Aug',
  },
  {
    id: 't5',
    from: 'Amma',
    subject: 'Did you eat?',
    preview: 'Rice is on the stove. Call when you can.',
    body: 'Did you eat?\nRice is on the stove. Call when you can.\n\n(This is the human one in the pile — still a mock.)',
    time: '12 Aug',
  },
];

const S = {
  open: null,
  to: '',
  subject: '',
  body: '',
};

function inboxView() {
  return `
    <div style="display:flex;justify-content:space-between;align-items:baseline;gap:12px">
      <h1>Inbox</h1>
      <button type="button" class="btn primary" onclick="go('compose')">Compose</button>
    </div>
    <p class="lede">Newest first. Open a thread or write a reply.</p>
    <div class="row">
      ${MAIL.map((m) => `
        <button type="button" class="list-btn" onclick="openMail('${m.id}')">
          <span>
            <strong>${Aperture.escapeHtml(m.from)}</strong> · ${Aperture.escapeHtml(m.subject)}<br>
            <span class="meta">${Aperture.escapeHtml(m.preview)}</span>
          </span>
          <span class="meta">${m.time}</span>
        </button>
      `).join('')}
    </div>
  `;
}

function openMail(id) {
  S.open = MAIL.find((m) => m.id === id);
  go('read');
}

function readView() {
  const m = S.open;
  return `
    <button class="btn" onclick="go('inbox')">← Inbox</button>
    <h1 style="margin-top:16px">${Aperture.escapeHtml(m.subject)}</h1>
    <p class="lede">${Aperture.escapeHtml(m.from)} · ${m.time}</p>
    <div class="thread">${Aperture.escapeHtml(m.body)}</div>
    <div class="actions">
      <button type="button" class="btn primary" onclick="replyTo()">Reply</button>
    </div>
  `;
}

function replyTo() {
  S.to = S.open.from.toLowerCase().replace(/\s+/g, '.') + '@mock';
  S.subject = 'Re: ' + S.open.subject;
  S.body = '';
  go('compose');
}

function composeView() {
  return `
    <button class="btn" onclick="go('inbox')">← Inbox</button>
    <h1 style="margin-top:16px">Compose</h1>
    <p class="lede">Three text fields. This is the free-text task the phone already trains.</p>
    <form class="panel row" onsubmit="onSend(event)">
      <label class="field" for="to">To
        <input id="to" name="to" required value="${Aperture.escapeHtml(S.to)}" />
      </label>
      <label class="field" for="subject">Subject
        <input id="subject" name="subject" required value="${Aperture.escapeHtml(S.subject)}" />
      </label>
      <label class="field" for="body">Message
        <textarea id="body" name="body" rows="6" required>${Aperture.escapeHtml(S.body)}</textarea>
      </label>
      <div class="actions">
        <button type="submit" class="btn primary">Send</button>
      </div>
    </form>
  `;
}

function onSend(e) {
  e.preventDefault();
  const fd = new FormData(e.target);
  S.to = fd.get('to');
  S.subject = fd.get('subject');
  S.body = fd.get('body');
  go('sent');
}

function sentView() {
  return `
    <div class="panel done">
      <span class="badge">Sent</span>
      <div class="big">On its way</div>
      <p>To ${Aperture.escapeHtml(S.to)}</p>
      <p class="lede">${Aperture.escapeHtml(S.subject)}</p>
      <div class="actions">
        <a class="btn primary" href="mail.html">Back to inbox</a>
        <a class="btn" href="index.html">Back to Daily</a>
      </div>
    </div>
  `;
}

const views = { inbox: inboxView, read: readView, compose: composeView, sent: sentView };

function go(screen) {
  S.screen = screen;
  Aperture.gotoScreen(screen);
  draw();
}

function draw() {
  let screen = views[S.screen] ? S.screen : (Aperture.screenParam() || 'inbox');
  if (!views[screen]) screen = 'inbox';
  if (screen === 'read' && !S.open) screen = 'inbox';
  S.screen = screen;
  document.title = `PostLane — ${S.screen}`;
  document.getElementById('app').innerHTML = views[S.screen]();
}

Aperture.bindPop((s) => { S.screen = s || 'inbox'; draw(); });
S.screen = Aperture.screenParam() || 'inbox';
draw();
