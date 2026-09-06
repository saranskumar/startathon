// Desktop inspector — a local HTTP server that drives one BrowserSession and
// serves a UI showing everything the DOM tree engine sees: the live page, the
// raw accessibility tree, the pruned/ranked auxiliary tree, the per-node score
// breakdown, and the watcher events that decide when to regenerate.
//
// The routes below are already the shape the phone-facing API needs (state /
// goto / act / events); the UI is just the first client of them, which is why
// the API step after this is wiring a transport to these same handlers rather
// than writing a new layer.
//
// Usage:
//   npm run ui                             (inspects code/mock/index.html)
//   npm run ui -- https://example.com
//   npm run ui -- --port 7788 --headless

import http from 'node:http';
import fs from 'node:fs';
import path from 'node:path';
import { pathToFileURL } from 'node:url';
import { BrowserSession } from './browserSession.js';
import { attachPhoneTransport } from './phoneTransport.js';
import { extractRegions } from './regions.js';
import { buildScanTree, pathsOf, describe } from './scanTree.js';

const args = process.argv.slice(2);
const flag = (name, fallback) => {
  const i = args.indexOf('--' + name);
  return i === -1 ? fallback : args[i + 1];
};
const headless = args.includes('--headless');
const port = Number(flag('port', 7777));
// The first bare argument that isn't the value of --port.
const target = args.find((a, i) => !a.startsWith('--') && args[i - 1] !== '--port');

const defaultMockPath = path.resolve(import.meta.dirname, '../../mock/index.html');
const startUrl = target ?? pathToFileURL(defaultMockPath).href;
const uiDir = path.resolve(import.meta.dirname, './ui');

const MIME = { '.html': 'text/html', '.css': 'text/css', '.js': 'text/javascript', '.svg': 'image/svg+xml' };

const session = new BrowserSession({ headless });
await session.start(startUrl);

function send(res, status, body, type = 'application/json') {
  res.writeHead(status, { 'content-type': type, 'cache-control': 'no-store' });
  res.end(typeof body === 'string' || Buffer.isBuffer(body) ? body : JSON.stringify(body));
}

async function readJsonBody(req) {
  const chunks = [];
  for await (const chunk of req) chunks.push(chunk);
  if (chunks.length === 0) return {};
  try { return JSON.parse(Buffer.concat(chunks).toString('utf8')); } catch { return {}; }
}

// The scan state carries the whole raw tree; strip it for callers that only
// want the ranked view, so the phone doesn't pay for the full snapshot.
function publicState(state, { includeRaw = true } = {}) {
  if (!state) return null;
  const { raw, ...rest } = state;
  return includeRaw ? { raw, ...rest } : rest;
}

const server = http.createServer(async (req, res) => {
  const url = new URL(req.url, 'http://localhost');
  const route = url.pathname;

  try {
    if (route === '/api/state' && req.method === 'GET') {
      const includeRaw = url.searchParams.get('raw') !== '0';
      return send(res, 200, { state: publicState(session.state, { includeRaw }), log: session.log.slice(-50) });
    }

    if (route === '/api/scan' && req.method === 'POST') {
      const state = await session.run(() => session.scan('manual'));
      return send(res, 200, { state: publicState(state) });
    }

    if (route === '/api/goto' && req.method === 'POST') {
      const { url: nextUrl } = await readJsonBody(req);
      if (!nextUrl) return send(res, 400, { error: 'url is required' });
      const state = await session.run(() => session.goto(normalizeTarget(nextUrl)));
      return send(res, 200, { state: publicState(state) });
    }

    if (route === '/api/act' && req.method === 'POST') {
      const body = await readJsonBody(req);
      const result = await session.run(() => session.act(body));
      return send(res, 200, result);
    }

    // The three-panel view (docs/idea/29-phone-desktop-integration.md §1):
    // top-level landmarks with their ranked features grouped underneath.
    if (route === '/api/regions' && req.method === 'GET') {
      if (!session.state) return send(res, 200, { regions: [] });
      return send(res, 200, { regions: extractRegions(session.state.tree) });
    }

    // The N-ary switch/voice-grid partition over one bucket, per scanTree.js.
    // ?arity=2 (default) for two-button/two-switch scanning, higher for more
    // swipe directions or a numbered voice grid; ?bucket=information for the
    // read-content tree instead of the default navigation/interactive one.
    if (route === '/api/scan-tree' && req.method === 'GET') {
      if (!session.state) return send(res, 200, { root: null, paths: [], narration: '' });
      const arity = Number(url.searchParams.get('arity') ?? 2);
      const bucket = url.searchParams.get('bucket') === 'information' ? 'information' : 'navigation';
      const features = session.state[bucket];
      const root = buildScanTree(features, { arity });
      const paths = root ? [...pathsOf(root).entries()].map(([feature, path]) => ({ feature, path })) : [];
      return send(res, 200, { arity, bucket, root, paths, narration: root ? describe(root) : '' });
    }

    if (route === '/api/screenshot.png' && req.method === 'GET') {
      const png = await session.run(() => session.screenshot());
      res.writeHead(200, { 'content-type': 'image/png', 'cache-control': 'no-store' });
      return res.end(png);
    }

    // Server-sent events: the UI never polls for scans, it is told.
    if (route === '/api/events') {
      res.writeHead(200, {
        'content-type': 'text/event-stream',
        'cache-control': 'no-store',
        connection: 'keep-alive',
      });
      res.write('retry: 1000\n\n');
      const off = session.onEvent(event => res.write('data: ' + JSON.stringify(event) + '\n\n'));
      const keepAlive = setInterval(() => res.write(': ping\n\n'), 15000);
      req.on('close', () => { clearInterval(keepAlive); off(); });
      return undefined;
    }

    // The zooming navigator's model is pure ESM with no Node dependencies, and
    // it runs in both places: Node imports it for the tests, the browser
    // imports this. Serving the one file keeps them from drifting.
    if (route === '/dasherModel.js') {
      const modelPath = path.resolve(import.meta.dirname, './dasherModel.js');
      return send(res, 200, fs.readFileSync(modelPath), 'text/javascript');
    }

    // Static UI.
    const file = route === '/' ? 'index.html' : route.replace(/^\/+/, '');
    const filePath = path.join(uiDir, file);
    if (!filePath.startsWith(uiDir)) return send(res, 403, { error: 'forbidden' });
    if (fs.existsSync(filePath) && fs.statSync(filePath).isFile()) {
      const type = MIME[path.extname(filePath)] ?? 'application/octet-stream';
      return send(res, 200, fs.readFileSync(filePath), type);
    }
    return send(res, 404, { error: 'not found' });
  } catch (err) {
    return send(res, 500, { error: err.message });
  }
});

/** Bare hosts ("example.com") and local paths both become real URLs. */
function normalizeTarget(input) {
  const value = input.trim();
  if (/^[a-z]+:\/\//i.test(value)) return value;
  if (fs.existsSync(value)) return pathToFileURL(path.resolve(value)).href;
  return 'https://' + value;
}

const phoneTransport = attachPhoneTransport(server, session);

server.listen(port, () => {
  console.log('DOM tree inspector: http://localhost:' + port);
  console.log('Phone transport (WebSocket): ws://localhost:' + port + '/phone');
  console.log('Inspecting: ' + startUrl);
  console.log('The controlled Chromium window is separate — drive it there, or from the inspector.');
});

const shutdown = async () => { phoneTransport.close(); await session.close(); process.exit(0); };
process.on('SIGINT', shutdown);
process.on('SIGTERM', shutdown);
session.onEvent(event => { if (event.type === 'closed') process.exit(0); });
