const CATS = ['All', 'Dairy', 'Produce', 'Staples', 'Home'];

const ITEMS = [
  { id: 'milk', name: 'Toned milk 500 ml', cat: 'Dairy', price: 28, color: '#f3efe0' },
  { id: 'curd', name: 'Curd 400 g', cat: 'Dairy', price: 32, color: '#fff8e7' },
  { id: 'tomato', name: 'Tomatoes 1 kg', cat: 'Produce', price: 36, color: '#f4c7b8' },
  { id: 'onion', name: 'Onions 1 kg', cat: 'Produce', price: 30, color: '#ead8c8' },
  { id: 'banana', name: 'Bananas 6', cat: 'Produce', price: 42, color: '#f7e37a' },
  { id: 'rice', name: 'Matta rice 5 kg', cat: 'Staples', price: 340, color: '#e8d5b5' },
  { id: 'oil', name: 'Coconut oil 1 L', cat: 'Staples', price: 210, color: '#f0e2a8' },
  { id: 'tea', name: 'Leaf tea 250 g', cat: 'Staples', price: 95, color: '#c8d5b8' },
  { id: 'soap', name: 'Bath soap 3-pack', cat: 'Home', price: 78, color: '#d7e4f0' },
  { id: 'det', name: 'Detergent 1 kg', cat: 'Home', price: 120, color: '#c9e0ef' },
];

const S = {
  cat: 'All',
  qty: Object.fromEntries(ITEMS.map((i) => [i.id, 0])),
  address: '',
  slot: '7–9 pm',
  phone: '',
};

function count() {
  return Object.values(S.qty).reduce((a, b) => a + b, 0);
}

function total() {
  return ITEMS.reduce((sum, i) => sum + i.price * (S.qty[i.id] || 0), 0);
}

function shopView() {
  const list = ITEMS.filter((i) => S.cat === 'All' || i.cat === S.cat);
  return `
    <div style="display:flex;justify-content:space-between;align-items:baseline;gap:12px">
      <h1>Today’s kirana</h1>
      <button type="button" class="btn primary" onclick="go('cart')">Cart · ${count()}</button>
    </div>
    <p class="lede">Add what you need. Same-evening slots at checkout.</p>
    <div class="chips" role="tablist" aria-label="Category">
      ${CATS.map((c) =>
        `<button type="button" role="tab" class="chip ${S.cat === c ? 'on' : ''}" aria-selected="${S.cat === c}" onclick="setCat('${c}')">${c}</button>`
      ).join('')}
    </div>
    <div class="products" style="margin-top:14px">
      ${list.map((i) => `
        <article class="card">
          <div class="swatch" style="background:${i.color}" aria-hidden="true"></div>
          <strong>${Aperture.escapeHtml(i.name)}</strong>
          <div class="lede" style="margin:4px 0 0">₹${i.price}</div>
          <div class="qty">
            <button type="button" class="btn tiny" aria-label="Fewer ${Aperture.escapeHtml(i.name)}" onclick="add('${i.id}',-1)">−</button>
            <span aria-live="polite">${S.qty[i.id]}</span>
            <button type="button" class="btn tiny" aria-label="More ${Aperture.escapeHtml(i.name)}" onclick="add('${i.id}',1)">+</button>
          </div>
        </article>
      `).join('')}
    </div>
  `;
}

function setCat(c) { S.cat = c; draw(); }
function add(id, n) {
  S.qty[id] = Math.max(0, (S.qty[id] || 0) + n);
  draw();
}

function cartView() {
  const lines = ITEMS.filter((i) => S.qty[i.id] > 0);
  if (!lines.length) {
    return `
      <button class="btn" onclick="go('shop')">← Shop</button>
      <h1 style="margin-top:16px">Cart is empty</h1>
      <p class="lede">Add something with the + buttons first.</p>
    `;
  }
  return `
    <button class="btn" onclick="go('shop')">← Shop</button>
    <h1 style="margin-top:16px">Cart · ₹${total()}</h1>
    <div class="row">
      ${lines.map((i) => `
        <div class="list-btn" style="cursor:default">
          <span><strong>${Aperture.escapeHtml(i.name)}</strong><br><span class="meta">${S.qty[i.id]} × ₹${i.price}</span></span>
          <span>
            <button type="button" class="btn tiny" aria-label="Fewer ${Aperture.escapeHtml(i.name)}" onclick="add('${i.id}',-1)">−</button>
            ${S.qty[i.id]}
            <button type="button" class="btn tiny" aria-label="More ${Aperture.escapeHtml(i.name)}" onclick="add('${i.id}',1)">+</button>
          </span>
        </div>
      `).join('')}
    </div>
    <div class="actions">
      <button type="button" class="btn primary" onclick="go('address')">Checkout</button>
    </div>
  `;
}

function addressView() {
  return `
    <button class="btn" onclick="go('cart')">← Cart</button>
    <h1 style="margin-top:16px">Deliver · ₹${total()}</h1>
    <form class="panel row" onsubmit="onAddr(event)">
      <label class="field" for="address">Address
        <textarea id="address" name="address" rows="3" required>${Aperture.escapeHtml(S.address)}</textarea>
      </label>
      <label class="field" for="phone">Phone
        <input id="phone" name="phone" inputmode="numeric" required value="${Aperture.escapeHtml(S.phone)}" />
      </label>
      <fieldset class="field" style="border:0;padding:0">
        <legend style="margin-bottom:6px">Slot</legend>
        <div class="chips">
          ${['10–12 am', '4–6 pm', '7–9 pm'].map((s) =>
            `<button type="button" class="chip ${S.slot === s ? 'on' : ''}" aria-pressed="${S.slot === s}" onclick="S.slot='${s}';draw()">${s}</button>`
          ).join('')}
        </div>
      </fieldset>
      <div class="actions">
        <button type="submit" class="btn primary">Place order</button>
      </div>
    </form>
  `;
}

function onAddr(e) {
  e.preventDefault();
  const fd = new FormData(e.target);
  S.address = fd.get('address');
  S.phone = fd.get('phone');
  go('done');
}

function doneView() {
  return `
    <div class="panel done">
      <span class="badge">Order placed</span>
      <div class="big">₹${total()}</div>
      <p>${count()} items · ${S.slot}</p>
      <p class="lede">${Aperture.escapeHtml(S.address)}</p>
      <div class="actions">
        <a class="btn primary" href="shop.html">Shop again</a>
        <a class="btn" href="index.html">Back to Daily</a>
      </div>
    </div>
  `;
}

const views = { shop: shopView, cart: cartView, address: addressView, done: doneView };

function go(screen) {
  S.screen = screen;
  Aperture.gotoScreen(screen);
  draw();
}

function draw() {
  const screen = S.screen || Aperture.screenParam() || 'shop';
  S.screen = views[screen] ? screen : 'shop';
  document.title = `KiranaCart — ${S.screen}`;
  document.getElementById('app').innerHTML = views[S.screen]();
}

Aperture.bindPop((s) => { S.screen = s || 'shop'; draw(); });
S.screen = Aperture.screenParam() || 'shop';
draw();
