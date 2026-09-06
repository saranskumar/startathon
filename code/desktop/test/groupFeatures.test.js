// Pins the hierarchical packing rules: structural clusters first, then a
// 4-way spatial split, recurse until every visible level fits under `limit`.

import test from 'node:test';
import assert from 'node:assert/strict';
import { buildAuxiliaryTree } from '../src/domTreeEngine.js';
import {
  packToLimit, splitSpatial, bundleChrome, makeGroup, unionBox,
} from '../src/groupFeatures.js';

const box = (x, y, width, height) => ({ x, y, width, height });

function leafCount(items) {
  let n = 0;
  for (const item of items) {
    if (item.isGroup) n += leafCount(item.members);
    else n += 1;
  }
  return n;
}

function flatten(items) {
  const out = [];
  for (const item of items) {
    if (item.isGroup) out.push(...flatten(item.members));
    else out.push(item);
  }
  return out;
}

test('unionBox covers every member', () => {
  const u = unionBox([
    { box: box(10, 20, 30, 40) },
    { box: box(100, 50, 20, 10) },
  ]);
  assert.deepEqual(u, { x: 10, y: 20, width: 110, height: 40 });
});

test('splitSpatial yields up to four non-empty quadrants', () => {
  const features = [
    { name: 'nw', box: box(0, 0, 10, 10), score: 1 },
    { name: 'ne', box: box(100, 0, 10, 10), score: 1 },
    { name: 'sw', box: box(0, 100, 10, 10), score: 1 },
    { name: 'se', box: box(100, 100, 10, 10), score: 1 },
  ];
  const quads = splitSpatial(features);
  assert.equal(quads.length, 4);
  assert.ok(quads.every(q => q.items.length === 1));
});

test('100 equal items pack into 4 groups of 25 at the first level', () => {
  const features = Array.from({ length: 100 }, (_, i) => ({
    role: 'button',
    name: 'Seat ' + i,
    label: 'Seat ' + i,
    score: 3,
    box: box((i % 10) * 40, Math.floor(i / 10) * 40, 36, 36),
    inChrome: false,
    inMain: true,
  }));

  const packed = packToLimit(features, 12);
  assert.ok(packed.length <= 12);
  assert.ok(packed.every(f => f.isGroup), 'overflow should be groups, not a silent slice');
  assert.equal(leafCount(packed), 100, 'every leaf stays reachable');

  // With a uniform grid and no structural keys, the first split is spatial → 4.
  assert.equal(packed.length, 4);
  for (const g of packed) {
    assert.equal(g.memberCount, 25);
  }
});

test('40 seat buttons become groups and every seat is reachable', () => {
  const seats = Array.from({ length: 40 }, (_, i) => {
    const row = Math.floor(i / 5);
    const col = i % 5;
    return {
      role: 'button',
      name: 'Seat ' + (row + 1) + String.fromCharCode(65 + col),
      ref: 's' + i,
      box: box(col * 50, 80 + row * 40, 44, 36),
    };
  });

  const { navigation } = buildAuxiliaryTree([{
    role: 'main',
    ref: 'e1',
    box: box(0, 0, 400, 500),
    children: [
      { role: 'heading', name: 'Pick a seat', level: 1, ref: 'h', box: box(0, 0, 200, 30) },
      {
        role: 'group',
        name: 'Seat map',
        ref: 'g',
        box: box(0, 80, 260, 360),
        children: seats,
      },
    ],
  }], { limit: 12 });

  assert.ok(navigation.length <= 12);
  assert.ok(navigation.some(f => f.isGroup), 'dense seat map must group');
  const leaves = flatten(navigation);
  assert.equal(leaves.filter(f => f.role === 'button').length, 40);
});

test('a form with two section headings packs into two groups', () => {
  const applicant = ['Full name', 'Parent', 'Date of birth', 'Aadhaar', 'Mobile', 'Email'];
  const address = ['House', 'Street', 'Village', 'District', 'Pincode', 'Purpose', 'Declare', 'Captcha'];

  const children = [
    { role: 'heading', name: 'Applicant', level: 2, ref: 'h1', box: box(0, 0, 200, 24) },
    ...applicant.map((name, i) => ({
      role: 'textbox', name, ref: 'a' + i, box: box(0, 40 + i * 40, 280, 30),
    })),
    { role: 'heading', name: 'Address', level: 2, ref: 'h2', box: box(0, 300, 200, 24) },
    ...address.map((name, i) => ({
      role: 'textbox', name, ref: 'b' + i, box: box(0, 340 + i * 40, 280, 30),
    })),
  ];

  const { navigation } = buildAuxiliaryTree([{
    role: 'form',
    name: 'Application',
    ref: 'f',
    box: box(0, 0, 400, 800),
    children,
  }], { limit: 12 });

  const groups = navigation.filter(f => f.isGroup);
  assert.ok(groups.length >= 2, 'two section headings should become (at least) two groups');
  const labels = groups.map(g => g.name || g.label).join(' ');
  assert.ok(/Applicant/i.test(labels));
  assert.ok(/Address/i.test(labels));
  assert.equal(flatten(navigation).filter(f => f.role === 'textbox').length, 14);
});

test('bundleChrome collapses chrome when main content exists', () => {
  const features = [
    { name: 'Home', score: 4, inChrome: true, inMain: false },
    { name: 'Help', score: 4, inChrome: true, inMain: false },
    { name: 'About', score: 4, inChrome: true, inMain: false },
    { name: 'Submit', score: 5, inChrome: false, inMain: true },
  ];
  const bundled = bundleChrome(features);
  assert.equal(bundled.length, 2);
  assert.ok(bundled.some(f => f.isGroup && /chrome/i.test(f.label)));
  assert.ok(bundled.some(f => f.name === 'Submit'));
});

test('makeGroup score is the best member score', () => {
  const g = makeGroup('Seats', [
    { score: 2.1, box: box(0, 0, 10, 10) },
    { score: 4.5, box: box(20, 0, 10, 10) },
  ]);
  assert.equal(g.isGroup, true);
  assert.equal(g.action, 'open');
  assert.equal(g.score, 4.5);
  assert.equal(g.memberCount, 2);
  assert.match(g.label, /· 2$/);
});
