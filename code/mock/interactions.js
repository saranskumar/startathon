// Preprogrammed interaction map for the demo (RailLink).
//
// NOTHING HERE IS PARSED. The demo does not read the page to work out what is
// on it -- every interaction below is authored by hand, and a selector is used
// only to find the element to click once the phone has already decided what to
// do. Live DOM parsing is the separate later demo (code/desktop's DOM tree
// engine, frozen for now).
//
// Each interaction is mapped to EVERY input method up front (`inputs` below).
// The phone does not decide how to render anything; it picks
// `interaction.inputs[activeMethod]` for whatever method the calibrated
// profile resolved to. Same interaction, five pre-authored renderings.
//
// The repetitive parts (4 trains, 48 seat cells) are generated from the same
// authored constants rail.js already declares, rather than hand-typed five
// times each. That is still preprogramming: the list of things is fixed at
// authoring time, not discovered from the page.

(function (global) {
  const SEAT_COLS = ['A', 'B', 'C', 'D', 'E', 'F'];

  // rail.js declares these at top level of a classic script, so they live in
  // the shared global lexical scope. Fall back to empty so this file can load
  // on a page that is not rail.html without throwing.
  const trains = () => (typeof TRAINS !== 'undefined' ? TRAINS : []);
  const stations = () => (typeof STATIONS !== 'undefined' ? STATIONS : []);
  const taken = () => (typeof TAKEN !== 'undefined' ? TAKEN : new Set());
  const railState = () => (typeof S !== 'undefined' ? S : {});

  // The panel framing (docs/idea/29 section 1) -- authored, not derived from
  // landmarks. Two panels on these pages; "side panel" does not exist on
  // RailLink, and claiming three would be a lie the overlay then draws.
  const REGIONS = [
    { id: 'topbar', name: 'top bar', sel: 'header.topbar' },
    { id: 'main', name: 'main content', sel: 'main#app' },
  ];

  // ---------- per-screen authored interactions ----------

  function searchScreen() {
    const list = [
      { id: 'from', label: 'From station', shape: 'discrete', region: 'main', sel: '#from', act: 'set', options: stations().map((s) => s.id), words: ['from', 'origin'] },
      { id: 'to', label: 'To station', shape: 'discrete', region: 'main', sel: '#to', act: 'set', options: stations().map((s) => s.id), words: ['to', 'destination'] },
      { id: 'date', label: 'Journey date', shape: 'text', region: 'main', sel: '#date', act: 'set', words: ['date', 'when'] },
    ];
    ['SL', '3A', '2A', 'CC'].forEach((k, i) => {
      list.push({ id: 'class-' + k, label: 'Class ' + k, shape: 'discrete', region: 'main', sel: '.chips .chip', nth: i, act: 'click', words: [k.toLowerCase()] });
    });
    list.push({ id: 'search', label: 'Search trains', shape: 'discrete', region: 'main', sel: 'form .actions .btn.primary', act: 'click', words: ['search', 'go'] });
    return { title: 'Book a train', interactions: list };
  }

  function resultsScreen() {
    const list = [
      { id: 'back-search', label: 'Change search', shape: 'discrete', region: 'main', sel: '.btn', nth: 0, act: 'click', words: ['back', 'change'] },
    ];
    trains().forEach((t, i) => {
      list.push({
        id: 'train-' + t.no,
        label: t.name + ' ' + t.dep,
        detail: t.no + ' - ' + t.dep + ' to ' + t.arr + ' - Rs ' + t.fare,
        shape: 'discrete',
        region: 'main',
        sel: '.list-btn',
        nth: i,
        act: 'click',
        words: [t.name.split(' ')[0].toLowerCase(), String(i + 1)],
      });
    });
    return { title: 'Trains for this route', interactions: list };
  }

  function seatsScreen() {
    const list = [
      { id: 'back-trains', label: 'All trains', shape: 'discrete', region: 'main', sel: '.btn', nth: 0, act: 'click', words: ['back'] },
    ];
    // 8 rows x 6 lettered seats, in the order rail.js paints them. The aisle
    // is a span, not a button, so it never enters this list -- but it also
    // never advances `nth`, which counts buttons only.
    let nth = 0;
    for (let r = 1; r <= 8; r++) {
      for (const col of SEAT_COLS) {
        const id = String(r) + col;
        if (!taken().has(id)) {
          list.push({
            id: 'seat-' + id,
            label: 'Seat ' + id,
            shape: 'pointing',
            region: 'main',
            sel: '.seat-map button.seat',
            nth,
            act: 'click',
            words: [String(r), col.toLowerCase()],
            grid: { row: r, col: SEAT_COLS.indexOf(col) + 1 },
          });
        }
        nth++;
      }
    }
    list.push({ id: 'seat-continue', label: 'Continue with this seat', shape: 'discrete', region: 'main', sel: '.actions .btn.primary', act: 'click', words: ['continue', 'next'] });
    return { title: 'Pick a seat', interactions: list };
  }

  function passengerScreen() {
    return {
      title: 'Passenger details',
      interactions: [
        { id: 'back-seats', label: 'Seat map', shape: 'discrete', region: 'main', sel: '.btn', nth: 0, act: 'click', words: ['back'] },
        { id: 'pname', label: 'Full name', shape: 'text', region: 'main', sel: '#pname', act: 'set', suggestions: ['Asha Menon', 'Ravi Kumar'], words: ['name'] },
        { id: 'age', label: 'Age', shape: 'continuous', region: 'main', sel: '#age', act: 'set', min: 1, max: 120, step: 1, words: ['age'] },
        { id: 'gender', label: 'Gender', shape: 'discrete', region: 'main', sel: '#gender', act: 'set', options: ['F', 'M', 'X'], words: ['gender'] },
        { id: 'berth', label: 'Berth preference', shape: 'discrete', region: 'main', sel: '#berth', act: 'set', options: ['No preference', 'Lower', 'Middle', 'Upper', 'Side lower'], words: ['berth'] },
        { id: 'mobile', label: 'Mobile number', shape: 'text', region: 'main', sel: '#mobile', act: 'set', suggestions: ['9847012345'], words: ['mobile', 'phone'] },
        { id: 'passenger-submit', label: 'Go to payment', shape: 'discrete', region: 'main', sel: 'form .actions .btn.primary', act: 'click', words: ['pay', 'next'] },
      ],
    };
  }

  function payScreen() {
    return {
      title: 'Pay for the ticket',
      interactions: [
        { id: 'back-passenger', label: 'Passenger', shape: 'discrete', region: 'main', sel: '.btn', nth: 0, act: 'click', words: ['back'] },
        { id: 'upi', label: 'UPI ID', shape: 'text', region: 'main', sel: '#upi', act: 'set', suggestions: ['asha@bank'], words: ['upi'] },
        { id: 'otp', label: 'OTP', shape: 'text', region: 'main', sel: '#otp', act: 'set', suggestions: ['482193'], words: ['otp', 'code'] },
        // The one consequential act in the chain -- the phone must confirm
        // before this is sent (FR7 / wireframe 4.8 task 5).
        { id: 'pay-submit', label: 'Confirm and pay', shape: 'discrete', region: 'main', sel: 'form .actions .btn.primary', act: 'click', consequential: true, words: ['confirm', 'pay'] },
      ],
    };
  }

  function doneScreen() {
    return {
      title: 'Ticket booked',
      interactions: [
        { id: 'book-another', label: 'Book another', shape: 'discrete', region: 'main', sel: '.done .actions .btn.primary', act: 'click', words: ['again', 'another'] },
        { id: 'back-daily', label: 'Back to Daily', shape: 'discrete', region: 'main', sel: '.done .actions .btn', nth: 1, act: 'click', words: ['home', 'daily'] },
      ],
    };
  }

  const SCREENS = {
    search: searchScreen,
    results: resultsScreen,
    seats: seatsScreen,
    passenger: passengerScreen,
    pay: payScreen,
    done: doneScreen,
  };

  // ---------- the one-to-all-methods mapping ----------

  // Every interaction gets a rendering for every method. This is the "map each
  // interaction to all the possible inputs" step, done once here so the phone
  // never has to decide how something should be driven -- it looks up
  // inputs[method] for whatever the profile resolved to.
  function mapToAllInputs(list, arity) {
    return list.map((it, i) => {
      const group = Math.floor(i / arity);
      const inputs = {
        // Direct tap: the label is the button face.
        buttons: { kind: 'tap', label: it.label, detail: it.detail ?? null },
        // Cycle-and-confirm: position in the fixed authored order.
        joystick: { kind: 'cycle', order: i, of: list.length },
        // Drag-to-hover: overlay.js fills the live box in, since only the page
        // knows where its own elements landed.
        trackpad: { kind: 'hover', order: i },
        // Two-level scan: pick the group, then the item inside it.
        switchScan: { kind: 'scan', group, indexInGroup: i % arity, steps: [group, i % arity] },
        // Say a word, or say the number.
        voice: { kind: 'word', words: [...(it.words ?? []), String(i + 1)] },
      };
      // Content-bearing shapes carry what the content choices are, so the
      // phone can fill them without inventing anything.
      if (it.shape === 'text') inputs.text = { kind: 'dictateOrPick', suggestions: it.suggestions ?? [] };
      if (it.shape === 'continuous') inputs.stepper = { kind: 'adjust', min: it.min, max: it.max, step: it.step ?? 1 };
      if (it.shape === 'discrete' && it.options) inputs.buttons.options = it.options;
      return { ...it, inputs };
    });
  }

  // Captions for the switch-scan groups -- what pressing a switch narrows to.
  function groupCaptions(list, arity) {
    const out = [];
    for (let i = 0; i < list.length; i += arity) {
      const chunk = list.slice(i, i + arity);
      const shown = chunk.slice(0, 2).map((c) => c.label);
      const rest = chunk.length - shown.length;
      out.push({
        group: out.length,
        ids: chunk.map((c) => c.id),
        caption: rest > 0 ? shown.join(', ') + ', and ' + rest + ' more' : shown.join(', '),
      });
    }
    return out;
  }

  function currentScreen() {
    const s = railState().screen;
    if (s && SCREENS[s]) return s;
    const param = new URLSearchParams(location.search).get('s');
    return SCREENS[param] ? param : 'search';
  }

  // The full payload the page pushes to the phone on every screen change.
  function snapshot(arity) {
    const n = Math.max(2, arity || 2);
    const screen = currentScreen();
    const built = SCREENS[screen]();
    const interactions = mapToAllInputs(built.interactions, n);
    return {
      screen,
      title: built.title,
      site: 'RailLink',
      regions: REGIONS.map((r) => ({
        ...r,
        count: interactions.filter((it) => it.region === r.id).length,
      })),
      interactions,
      scanGroups: groupCaptions(interactions, n),
      arity: n,
    };
  }

  global.Interactions = { snapshot, currentScreen, REGIONS, SCREENS };
})(window);
