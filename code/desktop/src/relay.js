// Demo relay — the phone<->mock link for the preprogrammed demo.
//
// This is deliberately NOT the DOM path. `server.js` (Playwright + the DOM
// tree engine + the inspector) is frozen for the demo per the scope change:
// the mock authors its own interactions (code/mock/interactions.js) and this
// process only moves JSON between the two clients and serves the static mock.
// Nothing here imports browserSession/domTreeEngine, so the frozen half can
// keep changing without touching the demo.
//
// Topology — two clients join the same room:
//
//   mock page  --(role=page)-->  relay  <--(role=phone)--  phone app
//
//   page  -> phone : { type:'state',  screen, title, regions, interactions }
//   phone -> page  : { type:'focus',  id }            (highlight, no act)
//   phone -> page  : { type:'act',    id, value? }    (do it)
//   phone -> page  : { type:'inputMethod', method, arity, vocabulary }
//   page  -> phone : { type:'acted',  id, ok, note }  (action echo)
//
// Every other message type is forwarded verbatim, so adding a message never
// means editing this file.
//
// Usage:
//   npm run relay                  (serves code/mock on :7777, ws on /ws)
//   npm run relay -- --port 8080
//
// Local demo:  page http://localhost:7777/rail.html   phone ws://<lan-ip>:7777/ws
// Deployed:    mock on Vercel, this process on any always-on host, wss://<host>/ws
// (Vercel cannot host the socket itself — serverless functions do not hold
// long-lived connections, and an https page cannot open a plain ws:// URL.)

import http from 'node:http';
import fs from 'node:fs';
import path from 'node:path';
import { WebSocketServer } from 'ws';

const args = process.argv.slice(2);
const flag = (name, fallback) => {
  const i = args.indexOf('--' + name);
  return i === -1 ? fallback : args[i + 1];
};
const port = Number(flag('port', process.env.PORT ?? 7777));
const mockDir = path.resolve(import.meta.dirname, '../../mock');

const MIME = {
  '.html': 'text/html', '.css': 'text/css', '.js': 'text/javascript',
  '.png': 'image/png', '.svg': 'image/svg+xml', '.json': 'application/json',
};

const httpServer = http.createServer((req, res) => {
  const url = new URL(req.url, 'http://localhost');

  // Health check — a hosted relay on a sleeping free tier needs a warm-up
  // ping before the demo, and this is what you point that ping at.
  if (url.pathname === '/health') {
    res.writeHead(200, { 'content-type': 'application/json' });
    return res.end(JSON.stringify({ ok: true, rooms: [...rooms.keys()], at: Date.now() }));
  }

  // Static mock. Path is resolved and then confirmed to stay inside mockDir,
  // so a `..` in the URL cannot walk out of it.
  const rel = url.pathname === '/' ? '/index.html' : url.pathname;
  const file = path.resolve(mockDir, '.' + rel);
  if (!file.startsWith(mockDir)) {
    res.writeHead(403); return res.end('forbidden');
  }
  fs.readFile(file, (err, body) => {
    if (err) { res.writeHead(404); return res.end('not found'); }
    res.writeHead(200, {
      'content-type': MIME[path.extname(file)] ?? 'application/octet-stream',
      'cache-control': 'no-store',
    });
    res.end(body);
  });
});

/** room -> { page: ws|null, phones: Set<ws>, lastState: object|null } */
const rooms = new Map();

function room(name) {
  if (!rooms.has(name)) rooms.set(name, { page: null, phones: new Set(), lastState: null });
  return rooms.get(name);
}

function sendTo(ws, msg) {
  if (ws && ws.readyState === ws.OPEN) ws.send(JSON.stringify(msg));
}

const wss = new WebSocketServer({ server: httpServer, path: '/ws' });

wss.on('connection', (ws, req) => {
  const url = new URL(req.url, 'http://localhost');
  // Room code keeps two people rehearsing at once from landing in each
  // other's demo — with a public relay there is no network boundary doing it.
  const name = (url.searchParams.get('room') || 'DEMO').toUpperCase();
  const role = url.searchParams.get('role') === 'page' ? 'page' : 'phone';
  const r = room(name);

  ws.roomName = name;
  ws.role = role;

  if (role === 'page') {
    // Last page wins: a reloaded mock replaces the stale socket rather than
    // both getting acts.
    if (r.page && r.page !== ws) sendTo(r.page, { type: 'replaced' });
    r.page = ws;
  } else {
    r.phones.add(ws);
    // A phone joining mid-demo should not sit blank until the next screen
    // change, so replay whatever the page last said.
    if (r.lastState) sendTo(ws, r.lastState);
  }

  sendTo(ws, { type: 'joined', room: name, role, peer: role === 'page' ? r.phones.size > 0 : !!r.page });
  // Tell the other side someone arrived, so both can show a live/offline dot.
  const peers = { type: 'peer', page: !!r.page, phones: r.phones.size };
  sendTo(r.page, peers);
  for (const p of r.phones) sendTo(p, peers);

  ws.on('message', (data) => {
    let msg;
    try { msg = JSON.parse(String(data)); } catch { return; }
    if (!msg || typeof msg !== 'object') return;

    if (role === 'page') {
      if (msg.type === 'state') r.lastState = msg;
      for (const p of r.phones) sendTo(p, msg);
    } else {
      sendTo(r.page, msg);
    }
  });

  ws.on('close', () => {
    if (role === 'page' && r.page === ws) { r.page = null; r.lastState = null; }
    else r.phones.delete(ws);
    const after = { type: 'peer', page: !!r.page, phones: r.phones.size };
    sendTo(r.page, after);
    for (const p of r.phones) sendTo(p, after);
    if (!r.page && r.phones.size === 0) rooms.delete(name);
  });
});

httpServer.listen(port, () => {
  console.log(`relay   http://localhost:${port}        (serving code/mock)`);
  console.log(`socket  ws://localhost:${port}/ws?room=DEMO&role=page|phone`);
  console.log(`demo    http://localhost:${port}/rail.html`);
});
