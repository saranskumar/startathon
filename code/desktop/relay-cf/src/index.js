// Always-on wss:// host for the demo relay.
// Same contract as code/desktop/src/relay.js — one Durable Object per room.
//
//   GET  /health
//   GET  /ws?room=DEMO&role=page|phone   (Upgrade: websocket)
//
// Deploy:  cd code/desktop/relay-cf && npx wrangler deploy
// Then open the Vercel mock as:
//   https://<mock>/rail.html?relay=wss://<this-worker>

import { DurableObject } from 'cloudflare:workers';

export class RelayRoom extends DurableObject {
  constructor(ctx, env) {
    super(ctx, env);
    this.lastState = null;
    this.ctx.getWebSockets().forEach((ws) => {
      const att = ws.deserializeAttachment() || {};
      if (att.lastState) this.lastState = att.lastState;
    });
  }

  async fetch(request) {
    const url = new URL(request.url);
    const room = (url.searchParams.get('room') || 'DEMO').toUpperCase();
    const role = url.searchParams.get('role') === 'page' ? 'page' : 'phone';
    const pair = new WebSocketPair();
    const [client, server] = Object.values(pair);
    this.ctx.acceptWebSocket(server);
    server.serializeAttachment({ role });

    const peers = this._peers();
    if (role === 'page') {
      for (const ws of this.ctx.getWebSockets()) {
        const att = ws.deserializeAttachment() || {};
        if (att.role === 'page' && ws !== server) {
          this._send(ws, { type: 'replaced' });
          ws.close(4000, 'replaced');
        }
      }
    } else if (this.lastState) {
      this._send(server, this.lastState);
    }

    this._send(server, {
      type: 'joined',
      room,
      role,
      peer: role === 'page' ? peers.phones > 0 : peers.page,
    });
    this._broadcastPeers();

    return new Response(null, { status: 101, webSocket: client });
  }

  async webSocketMessage(ws, message) {
    let msg;
    try { msg = JSON.parse(String(message)); } catch { return; }
    if (!msg || typeof msg !== 'object') return;
    const att = ws.deserializeAttachment() || {};
    if (att.role === 'page') {
      if (msg.type === 'state') {
        this.lastState = msg;
        ws.serializeAttachment({ ...att, lastState: msg });
      }
      for (const other of this.ctx.getWebSockets()) {
        const oa = other.deserializeAttachment() || {};
        if (oa.role === 'phone') this._send(other, msg);
      }
    } else {
      for (const other of this.ctx.getWebSockets()) {
        const oa = other.deserializeAttachment() || {};
        if (oa.role === 'page') this._send(other, msg);
      }
    }
  }

  async webSocketClose(ws) {
    const att = ws.deserializeAttachment() || {};
    if (att.role === 'page') this.lastState = null;
    this._broadcastPeers();
  }

  _peers() {
    let page = false;
    let phones = 0;
    for (const ws of this.ctx.getWebSockets()) {
      const att = ws.deserializeAttachment() || {};
      if (att.role === 'page') page = true;
      else phones++;
    }
    return { page, phones };
  }

  _broadcastPeers() {
    const after = { type: 'peer', ...this._peers() };
    for (const ws of this.ctx.getWebSockets()) this._send(ws, after);
  }

  _send(ws, msg) {
    try { ws.send(JSON.stringify(msg)); } catch { /* closed */ }
  }
}

export default {
  async fetch(request, env) {
    const url = new URL(request.url);
    const cors = {
      'access-control-allow-origin': '*',
      'access-control-allow-methods': 'GET, OPTIONS',
    };
    if (request.method === 'OPTIONS') return new Response(null, { headers: cors });

    if (url.pathname === '/health') {
      return Response.json({ ok: true, at: Date.now() }, { headers: cors });
    }

    if (url.pathname === '/ws') {
      if (request.headers.get('Upgrade') !== 'websocket') {
        return new Response('upgrade required', { status: 426 });
      }
      const room = (url.searchParams.get('room') || 'DEMO').toUpperCase();
      const stub = env.RELAY_ROOM.getByName(room);
      return stub.fetch(request);
    }

    return new Response(
      'KAI demo relay. GET /health or GET /ws?room=DEMO&role=page|phone\n',
      { headers: { 'content-type': 'text/plain' } },
    );
  },
};
