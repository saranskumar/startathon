// Pins the zooming navigator's behaviour: probability sizing, the DasherCore
// step dynamics, commit safety, and reversal.
//
//   npm test

import test from 'node:test';
import assert from 'node:assert/strict';
import { buildAuxiliaryTree } from '../src/domTreeEngine.js';
import {
  buildNavigationTree, childrenOf, assignBounds, softmax,
  DasherEngine, MAX_Y, ORIGIN_Y, NORMALIZATION,
} from '../src/dasherModel.js';

const box = (x, y, width, height) => ({ x, y, width, height });

function samplePage(extra = []) {
  return buildAuxiliaryTree([{
    role: 'main',
    ref: 'e1',
    box: box(0, 0, 800, 600),
    children: [
      { role: 'button', name: 'Continue', ref: 'e2', box: box(0, 0, 120, 40) },
      { role: 'button', name: 'Cancel', ref: 'e3', box: box(130, 0, 120, 40) },
      { role: 'textbox', name: 'Message', ref: 'e4', box: box(0, 60, 300, 40) },
      { role: 'heading', name: 'Checkout', level: 1, ref: 'e5', box: box(0, 110, 300, 40) },
      ...extra,
    ],
  }]);
}

/** Slider position, in dasher coordinates, at the middle of a top-level box. */
function centreOf(child) {
  return ((child.lbnd + child.hbnd) / 2 / NORMALIZATION) * MAX_Y;
}

function drive(engine, targetY, frames, direction = 1) {
  for (let i = 0; i < frames; i += 1) engine.step(targetY, direction);
}

/**
 * Steer at a box, tracking it as it moves — boxes shift every frame as the
 * view zooms, so a fixed slider position drifts off target. Stops as soon as
 * `until` is satisfied, so a test can stop short of a commit.
 */
function track(engine, pick, frames, until = () => false) {
  for (let i = 0; i < frames; i += 1) {
    const target = pick(engine);
    if (!target) return i;
    engine.step(engine.aimAt(target), 1);
    if (until(engine)) return i;
  }
  return frames;
}

const byLabel = (label) => (engine) => childrenOf(engine.root).find(c => c.label === label);
const byKind = (kind) => (engine) => childrenOf(engine.root).find(c => c.kind === kind);

test('every child gets a hittable share, however unlikely', () => {
  const children = assignBounds([
    { weight: 1000 }, { weight: 0.0001 }, { weight: 0.0001 },
  ]);
  const total = children.reduce((sum, c) => sum + c.share, 0);
  assert.ok(Math.abs(total - 1) < 1e-6, 'shares must sum to 1');
  for (const child of children) {
    assert.ok(child.share >= 0.011, 'no box may collapse to unreachable: ' + child.share);
  }
  assert.equal(children[0].lbnd, 0);
  assert.equal(children.at(-1).hbnd, NORMALIZATION);
});

test('softmax temperature controls how much the favourite dominates', () => {
  const scores = [5, 3, 1];
  const sharp = softmax(scores, 0.5);
  const flat = softmax(scores, 5);
  assert.ok(sharp[0] > flat[0], 'lower temperature concentrates probability');
  assert.ok(flat[2] > sharp[2], 'higher temperature keeps long shots reachable');
  for (const dist of [sharp, flat]) {
    assert.ok(Math.abs(dist.reduce((a, b) => a + b, 0) - 1) < 1e-9);
  }
});

test('a higher-scoring option gets a bigger target', () => {
  const aux = samplePage();
  const root = buildNavigationTree(aux);
  const top = childrenOf(root);

  const byLabel = Object.fromEntries(top.map(c => [c.label, c]));
  const best = aux.navigation[0].label;
  const worst = aux.navigation.at(-1).label;
  assert.ok(byLabel[best].share >= byLabel[worst].share,
    'the top-ranked feature must not be a smaller target than the last');
  assert.ok(top.some(c => c.kind === 'group'), 'information is reachable as its own branch');
});

test('usage history widens the box for a feature picked before', () => {
  const cold = buildNavigationTree(samplePage());
  const warm = buildNavigationTree(
    buildAuxiliaryTree(rawSample(), { usageCounts: { 'button::cancel': 9 } }));

  const shareOf = (root, label) => childrenOf(root).find(c => c.label === label)?.share ?? 0;
  assert.ok(shareOf(warm, 'Cancel') > shareOf(cold, 'Cancel'),
    'prediction is the point: what you pick often becomes easier to hit');
});

function rawSample() {
  return [{
    role: 'main',
    ref: 'e1',
    box: box(0, 0, 800, 600),
    children: [
      { role: 'button', name: 'Continue', ref: 'e2', box: box(0, 0, 120, 40) },
      { role: 'button', name: 'Cancel', ref: 'e3', box: box(130, 0, 120, 40) },
      { role: 'textbox', name: 'Message', ref: 'e4', box: box(0, 60, 300, 40) },
      { role: 'heading', name: 'Checkout', level: 1, ref: 'e5', box: box(0, 110, 300, 40) },
    ],
  }];
}

test('steering at a box and advancing enters it', () => {
  const root = buildNavigationTree(samplePage());
  const engine = new DasherEngine(root, { speed: 'advanced' });
  const entered = [];
  engine.onCommit = ({ node }) => entered.push(node.label);

  const frames = track(engine, byLabel('Cancel'), 200, e => e.root.label === 'Cancel');
  assert.equal(engine.root.label, 'Cancel');
  assert.deepEqual(entered, ['Cancel']);
  assert.ok(frames < 120, 'selecting one of four options took ' + frames + ' frames');
});

test('a slider held off centre scrolls the list rather than selecting', () => {
  // Worth pinning because it is the one behaviour that reads as a bug and is
  // not one. Steering moves whatever is at the slider toward the crosshair, so
  // a position that never changes never converges on anything — content keeps
  // flowing past it. Dasher is the same: you steer continuously, you do not
  // set an aim once. The UI's own affordance is to track a chosen box.
  const root = buildNavigationTree(samplePage());
  const engine = new DasherEngine(root, { speed: 'advanced' });
  const entered = [];
  engine.onCommit = ({ node }) => entered.push(node.label);

  drive(engine, centreOf(childrenOf(root).find(c => c.label === 'Cancel')), 200);
  assert.ok(entered.length > 1, 'a held slider keeps travelling, it does not settle');
});

test('holding still on one option never enters a different one', () => {
  const root = buildNavigationTree(samplePage());
  const engine = new DasherEngine(root, { speed: 'beginner' });
  const target = childrenOf(root).find(c => c.label === 'Continue');
  const entered = [];
  engine.onCommit = ({ node }) => entered.push(node.label);

  drive(engine, centreOf(target), 30);
  assert.ok(entered.every(label => label === 'Continue' || label.startsWith('✓')),
    'entered ' + JSON.stringify(entered));
});

test('an action fires only from its own confirm box, never by passing through', () => {
  const fired = [];
  const aux = samplePage();
  const root = buildNavigationTree(aux, { onAct: a => fired.push(a.feature.name + ':' + a.action) });
  const engine = new DasherEngine(root, { speed: 'advanced' });
  const target = childrenOf(root).find(c => c.label === 'Continue');

  // Enough frames to enter the feature, but stopped before the confirm box.
  track(engine, byLabel('Continue'), 200, e => e.root.label === 'Continue');
  assert.equal(engine.root.label, 'Continue');
  assert.deepEqual(fired, [], 'entering a feature must not dispatch anything');

  track(engine, byKind('commit'), 200, () => fired.length > 0);
  assert.deepEqual(fired, ['Continue:click']);
});

test('dispatching an action rewinds to the top for the next pass', () => {
  const fired = [];
  const root = buildNavigationTree(samplePage(), { onAct: a => fired.push(a) });
  const engine = new DasherEngine(root, { speed: 'advanced' });

  track(engine, byLabel('Continue'), 200, e => e.root.label === 'Continue');
  track(engine, byKind('commit'), 200, () => fired.length > 0);

  assert.equal(fired.length, 1);
  assert.equal(engine.root, root, 'the page is about to change; start over');
  assert.equal(engine.ancestors.length, 0);
  assert.equal(engine.rootMin, 0);
  assert.equal(engine.rootMax, MAX_Y);
});

test('reversing climbs back out of a branch', () => {
  const root = buildNavigationTree(samplePage());
  const engine = new DasherEngine(root, { speed: 'advanced' });

  track(engine, byLabel('Message'), 200, e => e.root.label === 'Message');
  assert.equal(engine.root.label, 'Message');

  // Steering anywhere while reversing must get back to the top.
  for (let i = 0; i < 200; i += 1) engine.step(ORIGIN_Y, -1);
  assert.equal(engine.root, root);
});

test('the back box escapes a branch without dispatching', () => {
  const fired = [];
  const root = buildNavigationTree(samplePage(), { onAct: a => fired.push(a) });
  const engine = new DasherEngine(root, { speed: 'advanced' });

  track(engine, byLabel('Cancel'), 200, e => e.root.label === 'Cancel');
  assert.equal(engine.root.label, 'Cancel');

  track(engine, byKind('back'), 200, e => e.root === root);
  assert.deepEqual(fired, [], 'backing out is not an action');
  assert.equal(engine.root, root);
});

test('a text field opens an alphabet you can keep spelling into', () => {
  const typed = [];
  const filled = [];
  const root = buildNavigationTree(samplePage(), {
    onAct: a => filled.push(a.value),
    onText: buffer => typed.push(buffer),
  });
  const engine = new DasherEngine(root, { speed: 'advanced' });

  track(engine, byLabel('Message'), 200, e => e.root.label === 'Message');

  const letters = childrenOf(engine.root).filter(c => c.kind === 'letter');
  assert.ok(letters.length > 26, 'the alphabet plus digits and punctuation');
  const e = letters.find(c => c.char === 'e');
  const z = letters.find(c => c.char === 'z');
  assert.ok(e.share > z.share, 'common letters must be bigger targets');

  track(engine, (eng) => childrenOf(eng.root).find(c => c.char === 'e'), 200, () => typed.length > 0);
  assert.deepEqual(typed, ['e']);
  assert.equal(engine.root.char, 'e', 'still inside the alphabet, ready for the next letter');
  assert.deepEqual(filled, [], 'typing a letter does not fill the field');
});

test('layout returns on-screen boxes and the crosshair path', () => {
  const root = buildNavigationTree(samplePage());
  const engine = new DasherEngine(root);
  const boxes = engine.layout();

  assert.ok(boxes.length >= childrenOf(root).length);
  for (const b of boxes) {
    assert.ok(b.max > 0 && b.min < MAX_Y, 'culled boxes must not be returned');
    assert.ok(b.max > b.min);
  }

  const path = engine.crosshairPath(boxes);
  assert.ok(path.length >= 1, 'something is always under the crosshair');
  assert.ok(path[0].min <= ORIGIN_Y && path[0].max > ORIGIN_Y);
  assert.deepEqual(path.map(p => p.depth), [...path.map(p => p.depth)].sort((a, b) => a - b));
});

test('the root never shrinks below a quarter screen or leaves the crosshair', () => {
  const root = buildNavigationTree(samplePage());
  const engine = new DasherEngine(root, { speed: 'advanced' });

  for (let i = 0; i < 300; i += 1) {
    engine.step((i * 137) % MAX_Y, i % 7 === 0 ? -1 : 1);
    assert.ok(engine.rootMax - engine.rootMin >= MAX_Y / 4 - 1e-6,
      'root width collapsed at frame ' + i);
    assert.ok(engine.rootMin <= ORIGIN_Y && engine.rootMax >= ORIGIN_Y,
      'root stopped covering the crosshair at frame ' + i);
  }
});

test('an empty page produces a usable tree rather than throwing', () => {
  const root = buildNavigationTree(buildAuxiliaryTree([]));
  const engine = new DasherEngine(root);
  assert.doesNotThrow(() => { drive(engine, ORIGIN_Y, 30); });
  assert.ok(childrenOf(root).length >= 1, 'the information branch is always present');
});
