// A Dasher-style zooming navigator over the auxiliary tree.
//
// Prior art and the decision to build rather than embed:
// docs/tech/research/07-dasher-integration.md assessed Dasher — the
// Cambridge/GNOME zooming predictive text-entry system — and concluded the
// library itself is not integrable here (no Dart binding; the WASM port is
// disclaimed by its own maintainers as "a demo, not a supported product"; and
// DasherCore is wired specifically to letters and an n-gram language model).
// What it flagged as tractable was §7.2(a) option (ii): borrow the *mechanism*
// — probability-sized nested regions, continuous steer-and-commit — and build
// a purpose-specific widget. That is this file.
//
// The one objection doc 07 raised against that path was that repurposing the
// zoom for non-alphabet choices would mean "awkwardly encoding [options] as a
// fake alphabet/corpus" to get region sizes. That objection does not apply
// here: domTreeEngine.js already produces a real score per feature, and
// usageStore.js already counts how often each was picked. Those are genuine
// probabilities over exactly the options being navigated — the language model's
// role, filled by the ranking we already have.
//
// The dynamics below follow DasherCore's own (Src/DasherCore/DasherModel.cpp):
// the same normalized coordinate space, the same arithmetic-coding-style
// interval nesting for child bounds, the same one-step interpolation toward
// "the target range fills the viewport", and the same re-root rule. Constants
// are DasherCore's.
//
// Pure and synchronous: no DOM, no Playwright, no network, no LLM.

/** DasherCore's coordinate space (Src/DasherCore/DasherModel.h). */
export const MAX_Y = 4096;
export const ORIGIN_Y = MAX_Y / 2; // the crosshair
export const NORMALIZATION = 1 << 16;

// DasherCore refuses an update that would shrink the root below MAX_Y/4.
const MIN_ROOT_WIDTH = MAX_Y / 4;

// No child may be narrower than this share of NORMALIZATION. Dasher keeps every
// letter hittable however unlikely it is; the same has to hold here or a
// low-scoring option becomes impossible to steer into with a coarse input.
const MIN_CHILD_SHARE = 0.012;

/** Steps to zoom a target range up to full screen — Dasher's Speed Control. */
// Tuned by timing a full select-and-confirm against the mock: roughly 1.8s,
// 1.0s and 0.5s respectively. Dasher ships the same three-way manual preset
// rather than measuring the user (doc 07 §7.2d), so this is the same knob.
export const SPEED_PRESETS = { beginner: 60, intermediate: 34, advanced: 18 };

// How much the view expands per full traversal. Forward, the range under the
// crosshair spanning a quarter-screen fills the screen; backward, the inverse,
// which makes `frac` below go negative and the same step function reverse.
const MAX_ZOOM = 4;

/**
 * Forward speed, bounded by how far the aim is from the crosshair.
 *
 * DasherCore does this too (CDefaultFilter::ApplyTransform's
 * `iDasherX = max(iDasherX, ORIGIN_X * xmax(double_y))`): steering hard up or
 * down caps how fast you can also be moving forward. It is not a nicety. Zoom
 * and steering converge at the same rate, so without it a box you are aiming
 * at from a distance can still be short of the crosshair at the moment the
 * view has to re-root — and the neighbour sitting on the crosshair gets
 * committed instead. Slowing the zoom while the aim is still travelling means
 * you always arrive before anything is decided.
 */
function forwardRange(targetY) {
  const offset = Math.min(Math.abs(targetY - ORIGIN_Y) / ORIGIN_Y, 1);
  const zoom = 1 + (MAX_ZOOM - 1) * (1 - offset) ** 2;
  return MAX_Y / zoom;
}

const REVERSE_RANGE = MAX_Y * MAX_ZOOM;

// ---------------------------------------------------------------------------
// Probabilities
// ---------------------------------------------------------------------------

/**
 * Turn engine scores into a probability distribution. Softmax rather than
 * normalizing the raw scores because scores are unbounded and can be negative,
 * and because the temperature is the one knob that decides how aggressively
 * the interface favours what it thinks you want: low temperature gives the top
 * option a big, easy target, high temperature flattens everything toward equal
 * widths. It is the same trade-off as Dasher's language model being confident
 * or not, exposed as a setting rather than buried.
 */
export function softmax(values, temperature = 1.2) {
  if (values.length === 0) return [];
  const max = Math.max(...values);
  const exps = values.map(v => Math.exp((v - max) / Math.max(temperature, 0.01)));
  const total = exps.reduce((a, b) => a + b, 0);
  return exps.map(e => e / total);
}

/**
 * Assign each child an interval in [0, NORMALIZATION), proportional to weight
 * but never below MIN_CHILD_SHARE. This is the arithmetic-coding nesting
 * DasherCore uses: a child's on-screen extent is always its own share of
 * whatever its parent currently occupies, at every zoom level.
 */
export function assignBounds(children) {
  if (children.length === 0) return children;

  const floor = Math.min(MIN_CHILD_SHARE, 1 / children.length);
  const raw = children.map(c => Math.max(c.weight ?? 0, 0));
  const total = raw.reduce((a, b) => a + b, 0);
  const even = raw.map(v => (total > 0 ? v / total : 1 / children.length));

  // Lift everything to the floor, then take the excess back off whatever is
  // above it, in proportion — so the floor never pushes the total past 1.
  const lifted = even.map(p => Math.max(p, floor));
  const excess = lifted.reduce((a, b) => a + b, 0) - 1;
  const headroom = lifted.reduce((a, p) => a + Math.max(p - floor, 0), 0);
  const shares = lifted.map(p => (excess > 0 && headroom > 0
    ? p - (Math.max(p - floor, 0) / headroom) * excess
    : p));

  let cursor = 0;
  children.forEach((child, i) => {
    child.lbnd = Math.round(cursor * NORMALIZATION);
    cursor += shares[i];
    child.hbnd = Math.round(Math.min(cursor, 1) * NORMALIZATION);
    child.share = shares[i];
  });
  children[children.length - 1].hbnd = NORMALIZATION;
  return children;
}

// English letter frequencies, used to size the alphabet when a text field is
// being filled. This is an order-0 model — deliberately not a claim to have
// reimplemented Dasher's PPM: it is the cheapest thing that makes common
// letters bigger targets than rare ones, which is the property that matters
// for a low-precision input.
const LETTER_FREQ = {
  ' ': 18.0, e: 10.2, t: 7.5, a: 6.5, o: 6.2, i: 5.7, n: 5.7, s: 5.3, r: 5.0,
  h: 5.0, l: 3.3, d: 3.3, u: 2.3, c: 2.3, m: 2.0, f: 2.0, w: 1.7, g: 1.6,
  y: 1.6, p: 1.6, b: 1.2, v: 0.8, k: 0.6, x: 0.15, j: 0.12, q: 0.1, z: 0.07,
};

const EXTRA_CHARS = '0123456789.,-@/?!\'';

function alphabetChildren(onChar) {
  const letters = Object.entries(LETTER_FREQ).map(([char, freq]) => ({
    kind: 'letter',
    label: char === ' ' ? '␣' : char,
    char,
    weight: freq,
    onCommit: () => onChar(char),
  }));
  const extras = [...EXTRA_CHARS].map(char => ({
    kind: 'letter', label: char, char, weight: 0.4, onCommit: () => onChar(char),
  }));
  return [...letters, ...extras];
}

// ---------------------------------------------------------------------------
// Tree construction
// ---------------------------------------------------------------------------

let nextId = 0;
function node(spec) {
  return { id: 'n' + (nextId++), children: null, ...spec };
}

/**
 * Build the navigable tree from one scan of the auxiliary tree.
 *
 * A feature is never committed just by being zoomed into — every action sits
 * behind its own confirm box, so drifting through a region cannot fire a real
 * click. That is a deliberate departure from Dasher, where entering a node
 * outputs a letter and backing out un-outputs it: a letter is retractable, a
 * click on someone's page is not. It also matches the confirm/dispatch step
 * the architecture already calls for.
 *
 * @param aux - a scan from domTreeEngine.buildAuxiliaryTree.
 * @param handlers.onAct    - ({ feature, action, value }) => void, a real dispatch.
 * @param handlers.onText   - (buffer) => void, called as a text buffer changes.
 * @param options.temperature - softmax temperature over feature scores.
 */
export function buildNavigationTree(aux, handlers = {}, options = {}) {
  const { onAct = () => {}, onText = () => {} } = handlers;
  const { temperature = 1.2 } = options;

  const navigation = aux?.navigation ?? [];
  const information = aux?.information ?? [];
  const navProbabilities = softmax(navigation.map(f => f.score), temperature);

  const back = () => node({ kind: 'back', label: '← back', weight: 0.9 });

  const textBranch = (feature) => {
    let buffer = String(feature.value ?? '');
    const emit = () => onText(buffer);
    const write = (char) => { buffer += char; emit(); };
    const children = () => [
      node({
        kind: 'commit',
        label: '✓ type',
        // `labelOf` rather than a baked string: childrenOf caches a resolved
        // child list, so a label built from the buffer would show whatever the
        // buffer held the first time that list was materialized — which is
        // before any letter has been steered into. The weight has to be
        // constant for the same reason, and a confirm box that stays the same
        // size is better anyway: clearing a field is a legitimate thing to do.
        labelOf: () => '✓ type "' + buffer + '"',
        weight: 5,
        onCommit: () => onAct({ feature, action: feature.action, value: buffer }),
      }),
      ...alphabetChildren(write).map(spec => node({
        ...spec,
        // Letters keep their subtree so you can keep spelling without ever
        // leaving the zoom — the whole point of Dasher's model.
        children: () => children(),
      })),
      node({
        kind: 'letter',
        label: '⌫',
        weight: 1.5,
        onCommit: () => { buffer = buffer.slice(0, -1); emit(); },
        children: () => children(),
      }),
      back(),
    ];
    return children;
  };

  const featureChildren = (feature) => {
    // Groups expand to their members — zooming into "Seat map" is the
    // hierarchical split, not a page click.
    if (feature.isGroup || feature.action === 'open') {
      const members = feature.members ?? [];
      const weights = softmax(members.map(m => m.score), temperature);
      return () => [
        ...members.map((member, i) => node({
          kind: 'feature',
          bucket: 'navigation',
          label: member.label ?? member.name ?? member.role,
          feature: member,
          weight: weights[i] ?? 0.1,
          children: featureChildren(member),
        })),
        back(),
      ];
    }
    if (feature.action === 'fill' || feature.action === 'set') return textBranch(feature);
    if (feature.action === 'check') {
      return () => [
        node({ kind: 'commit', label: '✓ tick', weight: 5, onCommit: () => onAct({ feature, action: 'check', value: true }) }),
        node({ kind: 'commit', label: '✕ untick', weight: 3, onCommit: () => onAct({ feature, action: 'check', value: false }) }),
        back(),
      ];
    }
    return () => [
      node({
        kind: 'commit',
        label: '✓ ' + (feature.action ?? 'click'),
        weight: 6,
        onCommit: () => onAct({ feature, action: feature.action ?? 'click' }),
      }),
      back(),
    ];
  };

  const navNodes = navigation.map((feature, i) => node({
    kind: 'feature',
    bucket: 'navigation',
    label: feature.label ?? feature.name ?? feature.role,
    feature,
    weight: navProbabilities[i] ?? 0,
    children: featureChildren(feature),
  }));

  const readNode = node({
    kind: 'group',
    label: 'Read the page',
    // One box for everything there is to read, sized so it stays reachable
    // without competing with the controls: the point of the widget is acting,
    // and information is a branch you deliberately steer into.
    weight: 0.22,
    children: () => [
      ...information.map(feature => {
        if (feature.isGroup || feature.action === 'open') {
          const members = feature.members ?? [];
          return node({
            kind: 'feature',
            bucket: 'information',
            label: feature.label ?? feature.name ?? feature.role,
            feature,
            weight: Math.max(feature.score, 0.1),
            children: () => [
              ...members.map(member => node({
                kind: 'feature',
                bucket: 'information',
                label: member.label ?? member.name ?? member.role,
                feature: member,
                weight: Math.max(member.score, 0.1),
                children: () => [
                  node({
                    kind: 'commit',
                    label: '✓ mark seen',
                    weight: 4,
                    onCommit: () => onAct({ feature: member, action: 'view' }),
                  }),
                  back(),
                ],
              })),
              back(),
            ],
          });
        }
        return node({
          kind: 'feature',
          bucket: 'information',
          label: feature.label ?? feature.name ?? feature.role,
          feature,
          weight: Math.max(feature.score, 0.1),
          children: () => [
            node({
              kind: 'commit',
              label: '✓ mark seen',
              weight: 4,
              onCommit: () => onAct({ feature, action: 'view' }),
            }),
            back(),
          ],
        });
      }),
      back(),
    ],
  });

  return node({
    kind: 'root',
    label: aux?.url ?? 'page',
    children: () => assignBounds([...navNodes, readNode]),
  });
}

/** Children are lazy so a text branch's alphabet is only built when entered. */
export function childrenOf(target) {
  if (!target) return [];
  if (target.resolved) return target.resolved;
  const raw = typeof target.children === 'function' ? target.children() : target.children;
  target.resolved = assignBounds(raw ?? []);
  return target.resolved;
}

// ---------------------------------------------------------------------------
// Dynamics
// ---------------------------------------------------------------------------

/**
 * The zooming state machine. One `step()` per animation frame, given where the
 * slider is pointing and whether the user is advancing or reversing.
 */
export class DasherEngine {
  constructor(root, { speed = 'intermediate' } = {}) {
    this.setRoot(root);
    this.speed = speed;
    this.onCommit = () => {};
  }

  setRoot(root) {
    this.baseRoot = root;
    this.root = root;
    this.rootMin = 0;
    this.rootMax = MAX_Y;
    this.ancestors = []; // [{ node, lbnd, hbnd }] so reversing can back out
  }

  /** Back to the top of the tree, fully zoomed out. */
  rewind() {
    this.restartAt(this.baseRoot, []);
  }

  /**
   * Jump the view to `target`, fully zoomed out, and tell the current step to
   * stop: its in-flight coordinates describe the branch we just left, and
   * letting it finish would clamp them straight back over this.
   */
  restartAt(target, ancestors) {
    this.root = target;
    this.ancestors = ancestors;
    this.rootMin = 0;
    this.rootMax = MAX_Y;
    this.restarted = true;
  }

  /** Where a child of the current root sits on screen right now. */
  rangeOf(child) {
    const width = this.rootMax - this.rootMin;
    return {
      min: this.rootMin + (width * child.lbnd) / NORMALIZATION,
      max: this.rootMin + (width * child.hbnd) / NORMALIZATION,
    };
  }

  /**
   * The slider position that steers at `child` this frame. Boxes move as the
   * view zooms, so this has to be re-read every frame — which is exactly what
   * a person does, steering continuously rather than setting an aim once.
   */
  aimAt(child) {
    const { min, max } = this.rangeOf(child);
    return Math.min(Math.max((min + max) / 2, 0), MAX_Y);
  }

  get steps() {
    return SPEED_PRESETS[this.speed] ?? SPEED_PRESETS.intermediate;
  }

  /**
   * One frame. `targetY` is the slider position in [0, MAX_Y]; `direction` is
   * +1 to advance or -1 to reverse. Returns true if anything moved.
   */
  step(targetY, direction = 1) {
    const range = direction >= 0 ? forwardRange(targetY) : REVERSE_RANGE;
    const y1 = targetY - range / 2;
    const y2 = targetY + range / 2;

    const R1 = this.rootMin;
    const R2 = this.rootMax;

    // Where the root would sit if [y1, y2] filled the viewport.
    const r1 = (MAX_Y * (R1 - y1)) / range;
    const r2 = (MAX_Y * (R2 - y1)) / range;

    // DasherModel.cpp's exact interpolation: the fraction of the way from
    // (R1,R2) to (r1,r2) that expands the root by one step's worth, where a
    // full traversal takes `steps` frames.
    const ratio = MAX_Y / range;
    const eFac = Math.pow(ratio, 1 / this.steps);
    const frac = Math.abs(ratio - 1) < 1e-9
      ? 1 / this.steps
      : (eFac - 1) / (ratio - 1);

    let newMin = R1 + frac * (r1 - R1);
    let newMax = R2 + frac * (r2 - R2);

    // Descend once the child under the crosshair has grown to fill the screen.
    // That, not any width threshold, is what "you have zoomed into this" means,
    // and it is the condition that makes descending and ascending exact
    // inverses: a child is only entered when it already covers [0, MAX_Y], so
    // the ascent test immediately below is false by construction and the two
    // cannot fight each other. Every width-multiple threshold tried here
    // instead either committed a neighbour before the aim had converged, or
    // popped straight back out of any child smaller than the threshold's share.
    // At most one descent per frame. A frame that moved far enough to satisfy
    // the condition at two levels would otherwise enter a feature and fire its
    // confirm box in the same tick, with no frame in between for anyone to see
    // it happening or steer away — one commit per frame is both safer and
    // closer to how this reads on screen.
    this.restarted = false;
    const child = this.crosshairChild(newMin, newMax);
    if (child) {
      const width = newMax - newMin;
      const childMin = newMin + (width * child.lbnd) / NORMALIZATION;
      const childMax = newMin + (width * child.hbnd) / NORMALIZATION;
      if (childMin <= 0 && childMax >= MAX_Y && this.enter(child)) {
        newMin = childMin;
        newMax = childMax;
      }
      if (this.restarted) return true; // the view has already been placed
    }

    if (direction >= 0) {
      // Going forward, the root always covers the viewport. Steering hard at a
      // child near the edge of the current node otherwise slides the root
      // partly off screen, which the ascent rule below reads as "zoomed out"
      // and pops you out of the very node you are trying to steer inside —
      // reaching for a letter would drop you out of the text field.
      newMin = Math.min(newMin, 0);
      newMax = Math.max(newMax, MAX_Y);
    } else {
      // Reversing is the only way up. Climb while the root no longer fills the
      // viewport, so siblings reappear as you back out.
      while ((newMin > 0 || newMax < MAX_Y) && this.ancestors.length > 0) {
        const { node: parent, lbnd, hbnd } = this.ancestors.pop();
        const share = (hbnd - lbnd) / NORMALIZATION;
        const width = (newMax - newMin) / Math.max(share, 1e-9);
        newMin -= (width * lbnd) / NORMALIZATION;
        newMax = newMin + width;
        this.root = parent;
      }
    }

    // The root must always straddle the crosshair, and never shrink to nothing.
    newMin = Math.min(newMin, ORIGIN_Y - 1);
    newMax = Math.max(newMax, ORIGIN_Y + 1);
    if (newMax - newMin < MIN_ROOT_WIDTH) return false;

    const moved = Math.abs(newMin - R1) > 1e-6 || Math.abs(newMax - R2) > 1e-6;
    this.rootMin = newMin;
    this.rootMax = newMax;
    return moved;
  }

  /** The child of the current root spanning the crosshair, at given bounds. */
  crosshairChild(min, max) {
    const children = childrenOf(this.root);
    if (children.length === 0) return null;
    const width = max - min;
    return children.find(child =>
      min + (width * child.hbnd) / NORMALIZATION > ORIGIN_Y) ?? children[children.length - 1];
  }

  /**
   * Make `target` the root. Returning null stops the caller's descent, which
   * is what every terminal case wants: there is nothing left to zoom into.
   */
  enter(target) {
    // A back box undoes the hop that led into its parent, rather than being
    // entered itself.
    if (target.kind === 'back') {
      const parent = this.ancestors.pop();
      this.restartAt(parent ? parent.node : this.baseRoot, this.ancestors);
      this.onCommit({ node: target, kind: 'back' });
      return null;
    }

    if (typeof target.onCommit === 'function') target.onCommit();
    this.onCommit({ node: target, kind: target.kind });

    // A leaf has nothing below it — entering it would leave the view empty.
    // Dispatching an action ends the pass: the page is about to change, and
    // the watcher's rescan will hand us a fresh tree to start over from.
    if (childrenOf(target).length === 0) {
      this.rewind();
      return null;
    }

    this.ancestors.push({ node: this.root, lbnd: target.lbnd, hbnd: target.hbnd });
    this.root = target;
    return target;
  }

  /**
   * Every box currently on screen, as { node, min, max, depth } in dasher
   * coordinates. Boxes narrower than `minWidth` are not descended into — the
   * same culling that keeps Dasher's frame cost flat however deep the tree.
   */
  layout({ maxDepth = 4, minWidth = MAX_Y / 48, maxBoxes = 400 } = {}) {
    const boxes = [];
    const visit = (target, min, max, depth) => {
      if (depth > maxDepth || boxes.length >= maxBoxes) return;
      if (max < 0 || min > MAX_Y) return;
      // Not just a rendering nicety: descending into slivers would walk (and
      // materialize) the whole alphabet subtree, which branches ~45 ways per
      // level. Culling by on-screen size keeps the cost flat however deep the
      // tree goes — the same reason Dasher can afford an unbounded one.
      if (max - min < minWidth) return;
      const width = max - min;
      for (const child of childrenOf(target)) {
        const childMin = min + (width * child.lbnd) / NORMALIZATION;
        const childMax = min + (width * child.hbnd) / NORMALIZATION;
        if (childMax < 0 || childMin > MAX_Y) continue;
        if (childMax - childMin < minWidth) continue;
        boxes.push({ node: child, min: childMin, max: childMax, depth });
        visit(child, childMin, childMax, depth + 1);
        if (boxes.length >= maxBoxes) return;
      }
    };
    visit(this.root, this.rootMin, this.rootMax, 0);
    return boxes;
  }

  /** The chain of boxes under the crosshair — what committing would enter. */
  crosshairPath(boxes) {
    return boxes
      .filter(box => box.min <= ORIGIN_Y && box.max > ORIGIN_Y)
      .sort((a, b) => a.depth - b.depth);
  }
}
