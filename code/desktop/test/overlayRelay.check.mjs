import { chromium } from 'playwright';
import WebSocket from 'ws';

const base = 'http://127.0.0.1:7777';
const log = [];
let failed = false;
const ok = (name, pass, detail = '') => {
  log.push(`${pass ? 'ok  ' : 'FAIL'} ${name}${detail ? ' — ' + detail : ''}`);
  if (!pass) failed = true;
};

function openPhone() {
  const ws = new WebSocket(base.replace('http', 'ws') + '/ws?room=DEMO&role=phone');
  const inbox = [];
  const waiters = [];
  ws.on('message', (data) => {
    let msg;
    try { msg = JSON.parse(String(data)); } catch { return; }
    inbox.push(msg);
    for (let i = waiters.length - 1; i >= 0; i--) {
      if (waiters[i].pred(msg)) {
        waiters[i].resolve(msg);
        waiters.splice(i, 1);
      }
    }
  });
  function waitFor(pred, ms = 4000) {
    const hit = inbox.find(pred);
    if (hit) return Promise.resolve(hit);
    return new Promise((resolve, reject) => {
      const t = setTimeout(() => reject(new Error('timeout waiting for ' + pred)), ms);
      waiters.push({ pred, resolve: (msg) => { clearTimeout(t); resolve(msg); } });
    });
  }
  return { ws, waitFor };
}

const browser = await chromium.launch({ headless: true });
const page = await browser.newPage();
try {
  await page.goto(base + '/rail.html', { waitUntil: 'domcontentloaded' });
  await page.waitForSelector('#kai-hud', { timeout: 4000 });
  ok('hud shows room', (await page.locator('#kai-hud .kai-room').innerText()).trim() === 'DEMO');
  await page.waitForFunction(() => document.querySelector('#kai-hud')?.dataset.online === '1', null, { timeout: 5000 });
  ok('page joined room', true);
  const health = await (await fetch(base + '/health')).json();
  ok('health lists DEMO', health.rooms.includes('DEMO'), JSON.stringify(health.rooms));
  ok('region outlines', (await page.locator('#kai-overlay .kai-region').count()) >= 2);

  const phone = openPhone();
  const joined = await phone.waitFor((m) => m.type === 'joined');
  ok('phone joined with page peer', joined.peer === true);
  const pushed = await phone.waitFor((m) => m.type === 'state' && m.screen === 'search');
  ok('search state', pushed.interactions?.length > 0);
  phone.ws.send(JSON.stringify({ type: 'focus', id: 'search' }));
  await page.waitForSelector('#kai-overlay .kai-focus', { timeout: 3000 });
  ok('focus highlight', true);
  phone.ws.send(JSON.stringify({
    type: 'focus',
    id: 'class-SL',
    phase: 'group',
    groupIds: ['class-SL', 'class-3A', 'class-2A', 'class-CC'],
  }));
  await page.waitForFunction(() => {
    const overlay = document.getElementById('kai-overlay');
    return overlay?.classList.contains('kai-has-focus') &&
      overlay.querySelectorAll('.kai-scan').length >= 1 &&
      overlay.querySelectorAll('.kai-focus').length === 0;
  }, null, { timeout: 3000 });
  ok('group highlight without item', true);
  phone.ws.send(JSON.stringify({
    type: 'focus',
    id: 'class-3A',
    phase: 'item',
    groupIds: ['class-SL', 'class-3A', 'class-2A', 'class-CC'],
  }));
  await page.waitForFunction(() => {
    const overlay = document.getElementById('kai-overlay');
    return overlay?.querySelectorAll('.kai-scan').length >= 1 &&
      overlay.querySelectorAll('.kai-focus').length >= 1;
  }, null, { timeout: 3000 });
  ok('item highlight with group', true);
  phone.ws.send(JSON.stringify({ type: 'act', id: 'search' }));
  const acted = await phone.waitFor((m) => m.type === 'acted' && m.id === 'search');
  ok('search act', acted.ok === true);
  await page.waitForFunction(() => document.title.includes('results'), null, { timeout: 4000 });
  ok('navigated to results', true);
  phone.ws.close();
} catch (err) {
  ok('script', false, err.message);
} finally {
  await browser.close();
}
console.log(log.join('\n'));
process.exit(failed ? 1 : 0);
