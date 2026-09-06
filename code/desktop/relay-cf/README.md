# KAI demo relay (Cloudflare)

Vercel cannot hold the WebSocket. Once the mock is on `https://`, a `ws://` LAN address is blocked as mixed content. This Worker is the always-on `wss://` host.

## Deploy (do this before the demo)

```bash
cd code/desktop/relay-cf
npx wrangler login
npx wrangler deploy
```

Wrangler prints a URL like `https://kai-relay.<account>.workers.dev`. Warm it with `/health` right before the talk if the worker has been idle.

## Point the clients at it

- Laptop mock (Vercel): `https://<mock>/rail.html?room=DEMO&relay=wss://kai-relay.<account>.workers.dev`
- Phone Live screen: relay host `wss://kai-relay.<account>.workers.dev`

Local rehearsal still uses `npm run relay` in `code/desktop` and `http://localhost:7777/rail.html` — same protocol, no Worker needed.
