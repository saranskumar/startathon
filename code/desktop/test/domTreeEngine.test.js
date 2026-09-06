// Pins the ranking decisions that were reached by looking at real output —
// the mock UI, its form, and a real Wikipedia article. Doc 08 §5 is explicit
// that the tier-1 weights are hand-tuned starting points rather than proven
// constants, so these are regression guards for tuning already done, not
// claims that the numbers are correct in the abstract.
//
//   node --test test/

import test from 'node:test';
import assert from 'node:assert/strict';
import { buildAuxiliaryTree, featureSignature, featureIdentity } from '../src/domTreeEngine.js';

const box = (x, y, width, height) => ({ x, y, width, height });

test('static text already inside an ancestor accessible name is pruned', () => {
  const { information, stats } = buildAuxiliaryTree([{
    role: 'main',
    ref: 'e1',
    box: box(0, 0, 800, 600),
    children: [{
      role: 'button',
      name: 'Item one no note',
      ref: 'e2',
      box: box(0, 0, 400, 50),
      children: [
        { role: 'generic', text: 'Item one', ref: 'e3', box: box(0, 0, 60, 20) },
        { role: 'generic', text: 'no note', ref: 'e4', box: box(60, 0, 40, 20) },
      ],
    }],
  }]);

  assert.equal(information.length, 0, 'the button already says both halves');
  assert.equal(stats.prunedNodes, 2);
});

test('a text node that only repeats a control label is pruned', () => {
  const { information } = buildAuxiliaryTree([{
    role: 'form',
    ref: 'e1',
    box: box(0, 0, 800, 600),
    children: [
      // A <label> is a sibling of its control, so the ancestor check can't see it.
      { role: 'generic', text: 'Rating (0-10)', ref: 'e2', box: box(0, 0, 120, 20) },
      { role: 'spinbutton', name: 'Rating (0-10)', ref: 'e3', box: box(0, 24, 120, 30) },
    ],
  }]);

  assert.deepEqual(information.map(f => f.name), []);
});

test('a landmark scores its own proximity, not its parent’s', () => {
  const { tree } = buildAuxiliaryTree([{
    role: 'generic',
    ref: 'e1',
    box: box(0, 0, 800, 600),
    children: [{ role: 'navigation', name: 'Site', ref: 'e2', box: box(0, 0, 800, 60), children: [] }],
  }]);

  const nav = tree[0].children[0];
  const proximity = nav.parts.find(p => p.label === 'near a landmark');
  assert.ok(proximity, 'a landmark is at depth 0 from itself, so it earns the full bonus');
  assert.equal(proximity.value, 1.5);
});

test('landmarks stay out of the Information bucket', () => {
  const { information } = buildAuxiliaryTree([{
    role: 'generic',
    ref: 'e1',
    box: box(0, 0, 800, 600),
    children: [
      { role: 'navigation', name: 'Page tools', ref: 'e2', box: box(0, 0, 200, 600), children: [] },
      { role: 'heading', name: 'Accessibility', level: 1, ref: 'e3', box: box(220, 0, 400, 40) },
    ],
  }]);

  assert.deepEqual(information.map(f => f.name), ['Accessibility']);
});

test('link density demotes links in a nav blob, not links in prose', () => {
  const linkFarm = {
    role: 'navigation',
    name: 'Related',
    ref: 'e1',
    box: box(0, 0, 300, 400),
    children: Array.from({ length: 6 }, (_, i) => ({
      role: 'link', name: 'Sidebar link number ' + i, ref: 'f' + i, box: box(0, i * 30, 280, 24),
    })),
  };
  const prose = {
    role: 'main',
    ref: 'e2',
    box: box(320, 0, 600, 400),
    children: [
      {
        role: 'paragraph',
        text: 'A long stretch of ordinary body copy that goes on for a while so that the ' +
          'single link inside it is a small fraction of the total text in this block.',
        ref: 'p1',
        box: box(320, 0, 600, 80),
      },
      { role: 'link', name: 'Sidebar link number 0', ref: 'p2', box: box(320, 90, 200, 24) },
    ],
  };

  const { navigation } = buildAuxiliaryTree([{
    role: 'generic', ref: 'root', box: box(0, 0, 920, 400), children: [linkFarm, prose],
  }]);

  // Flatten groups — chrome bundling may wrap the nav-blob links.
  const flat = [];
  const walk = (items) => {
    for (const f of items) {
      if (f.isGroup) walk(f.members);
      else flat.push(f);
    }
  };
  walk(navigation);

  const proseLink = flat.find(f => f.ref === 'p2');
  const farmLink = flat.find(f => f.ref === 'f1');
  assert.ok(proseLink && farmLink);
  assert.ok(proseLink.score > farmLink.score,
    'the in-prose link should outrank an identical link in a link farm');
});

test('a heading’s level outweighs how long its text is', () => {
  const { information } = buildAuxiliaryTree([{
    role: 'main',
    ref: 'e1',
    box: box(0, 0, 800, 600),
    children: [
      { role: 'heading', name: 'Accessibility', level: 1, ref: 'e2', box: box(0, 0, 400, 40) },
      {
        role: 'heading', level: 3, ref: 'e3', box: box(0, 50, 400, 30),
        name: 'Accessibility planning for transportation in a much longer subsection title',
      },
    ],
  }]);

  assert.equal(information[0].level, 1, 'the h1 must come first');
});

test('a pointer-cursor div with no role is flagged, not silently dropped', () => {
  const { navigation, ambiguity } = buildAuxiliaryTree([{
    role: 'main',
    ref: 'e1',
    box: box(0, 0, 800, 600),
    children: [{ role: 'generic', text: 'Open settings', cursor: 'pointer', ref: 'e2', box: box(0, 0, 120, 30) }],
  }]);

  const feature = navigation.find(f => f.ref === 'e2');
  assert.ok(feature, 'it is actionable in practice, so it belongs in Navigation');
  assert.equal(feature.isAmbiguous, true);
  assert.equal(feature.action, 'click');
  assert.equal(ambiguity.unknownInteractive, 1);
  assert.ok(ambiguity.reasons.some(r => r.includes('no ARIA role')));
});

test('disabled and zero-size controls never reach the Navigation bucket', () => {
  const { navigation } = buildAuxiliaryTree([{
    role: 'main',
    ref: 'e1',
    box: box(0, 0, 800, 600),
    children: [
      { role: 'button', name: 'Submit', ref: 'e2', box: box(0, 0, 100, 30), disabled: true },
      { role: 'button', name: 'Hidden', ref: 'e3', box: box(0, 0, 0, 0) },
      { role: 'button', name: 'Continue', ref: 'e4', box: box(0, 40, 100, 30) },
    ],
  }]);

  assert.deepEqual(navigation.map(f => f.name), ['Continue']);
});

test('a long accessible name gets a short label from the heading inside it', () => {
  const { navigation } = buildAuxiliaryTree([{
    role: 'main',
    ref: 'e1',
    box: box(0, 0, 800, 600),
    children: [{
      role: 'button',
      name: 'Option A Simple patterns One isolated UI pattern per step: scroll selector, card grid, tabs.',
      ref: 'e2',
      box: box(0, 0, 280, 190),
      children: [{ role: 'heading', name: 'Simple patterns', level: 3, ref: 'e3', box: box(10, 40, 230, 25) }],
    }],
  }]);

  assert.equal(navigation[0].label, 'Simple patterns');
  assert.ok(navigation[0].name.length > 48, 'the full name is still carried for locating it');
});

test('roles carry the phone app’s task shape and the action to dispatch', () => {
  const { navigation } = buildAuxiliaryTree([{
    role: 'form',
    ref: 'e1',
    box: box(0, 0, 800, 600),
    children: [
      { role: 'textbox', name: 'Message', ref: 'e2', box: box(0, 0, 300, 30) },
      { role: 'slider', name: 'Volume', ref: 'e3', box: box(0, 40, 300, 30) },
      { role: 'checkbox', name: 'Subscribe', ref: 'e4', box: box(0, 80, 30, 30) },
      { role: 'link', name: 'Back', ref: 'e5', box: box(0, 120, 80, 20) },
    ],
  }]);

  const shapes = Object.fromEntries(navigation.map(f => [f.name, [f.taskShape, f.action]]));
  assert.deepEqual(shapes.Message, ['text', 'fill']);
  assert.deepEqual(shapes.Volume, ['continuous', 'set']);
  assert.deepEqual(shapes.Subscribe, ['discrete', 'check']);
  assert.deepEqual(shapes.Back, ['discrete', 'click']);
});

test('usage counts raise a feature above an otherwise identical one', () => {
  const page = [{
    role: 'main',
    ref: 'e1',
    box: box(0, 0, 800, 600),
    children: [
      { role: 'button', name: 'Alpha', ref: 'e2', box: box(0, 0, 100, 30) },
      { role: 'button', name: 'Bravo', ref: 'e3', box: box(0, 40, 100, 30) },
    ],
  }];

  const cold = buildAuxiliaryTree(page);
  assert.equal(cold.navigation[0].name, 'Alpha', 'ties fall back to document order');

  const warm = buildAuxiliaryTree(page, { usageCounts: { 'button::bravo': 7 } });
  assert.equal(warm.navigation[0].name, 'Bravo');
  assert.ok(warm.navigation[0].parts.some(p => p.label === 'picked 7x before'));
});

test('every score is the exact sum of its own parts', () => {
  const { navigation, information } = buildAuxiliaryTree([{
    role: 'main',
    ref: 'e1',
    box: box(0, 0, 800, 600),
    children: [
      { role: 'heading', name: 'Settings', level: 2, ref: 'e2', box: box(0, 0, 300, 30) },
      { role: 'button', name: 'Save', ref: 'e3', box: box(0, 40, 100, 30) },
      { role: 'button', name: 'Off screen', ref: 'e4', box: box(0, 9000, 100, 30) },
    ],
  }]);

  for (const feature of [...navigation, ...information]) {
    const sum = feature.parts.reduce((total, p) => total + p.value, 0);
    assert.ok(Math.abs(sum - feature.score) < 0.011,
      feature.name + ': parts sum to ' + sum + ' but score is ' + feature.score);
  }
});

test('a signature is stable across snapshots and absent when there is no name', () => {
  assert.equal(featureSignature({ role: 'button', name: '  Save   Changes ' }), 'button::save changes');
  assert.equal(featureSignature({ role: 'button' }), null,
    'unnamed nodes must not share one usage counter');
});

test('a single node, an array of roots, and missing children all parse', () => {
  const single = buildAuxiliaryTree({ role: 'button', name: 'Go', ref: 'e1' });
  assert.equal(single.navigation.length, 1);
  assert.equal(buildAuxiliaryTree([]).navigation.length, 0);
  assert.equal(buildAuxiliaryTree([null, { role: 'main', ref: 'e1' }]).stats.rawNodes, 1);
});

test('a filled text field carries its content as the feature value', () => {
  const { navigation } = buildAuxiliaryTree([{
    role: 'form',
    ref: 'e1',
    box: box(0, 0, 800, 600),
    children: [
      // Playwright reports a text field's content as the node's text, while
      // its accessible name stays the label.
      { role: 'textbox', name: 'Message', text: 'hello there', ref: 'e2', box: box(0, 0, 300, 30) },
      { role: 'textbox', name: 'Empty', ref: 'e3', box: box(0, 40, 300, 30) },
    ],
  }]);

  const byName = Object.fromEntries(navigation.map(f => [f.name, f]));
  assert.equal(byName.Message.value, 'hello there');
  assert.equal(byName.Message.name, 'Message', 'the label is still the name');
  assert.equal(byName.Empty.value, null);
});

test('offscreen controls are excluded from buckets but stay in the tree', () => {
  const { navigation, tree } = buildAuxiliaryTree([{
    role: 'main',
    ref: 'e1',
    box: box(0, 0, 800, 600),
    children: [
      { role: 'button', name: 'Visible', ref: 'e2', box: box(0, 0, 100, 30) },
      { role: 'button', name: 'Off screen', ref: 'e3', box: box(0, 9000, 100, 30) },
    ],
  }]);

  assert.deepEqual(navigation.map(f => f.name), ['Visible']);
  const off = tree[0].children.find(c => c.ref === 'e3');
  assert.ok(off);
  assert.equal(off.offscreen, true);
  assert.equal(off.prunedBecause, 'outside viewport');
});

test('page chrome ranks below an in-main control', () => {
  const { navigation } = buildAuxiliaryTree([{
    role: 'generic',
    ref: 'root',
    box: box(0, 0, 800, 600),
    children: [
      {
        role: 'banner',
        name: 'Site',
        ref: 'b',
        box: box(0, 0, 800, 40),
        children: [
          { role: 'link', name: 'Home', ref: 'b1', box: box(0, 0, 60, 30) },
          { role: 'link', name: 'Help', ref: 'b2', box: box(70, 0, 60, 30) },
          { role: 'link', name: 'About', ref: 'b3', box: box(140, 0, 60, 30) },
        ],
      },
      {
        role: 'main',
        ref: 'm',
        box: box(0, 50, 800, 500),
        children: [
          { role: 'button', name: 'Book ticket', ref: 'm1', box: box(0, 50, 120, 40) },
        ],
      },
    ],
  }]);

  assert.equal(navigation[0].name, 'Book ticket');
  const chrome = navigation.find(f => f.isGroup && /chrome/i.test(f.label));
  assert.ok(chrome, 'several chrome links collapse into one Site chrome group');
  assert.ok(chrome.memberCount >= 3);
});

test('two identical labels under different headings keep distinct identities', () => {
  const { navigation } = buildAuxiliaryTree([{
    role: 'main',
    ref: 'e1',
    box: box(0, 0, 800, 600),
    children: [
      { role: 'heading', name: 'Dialog', level: 2, ref: 'h1', box: box(0, 0, 200, 30) },
      { role: 'button', name: 'Cancel', ref: 'c1', box: box(0, 40, 80, 30) },
      { role: 'heading', name: 'Page chrome', level: 2, ref: 'h2', box: box(0, 100, 200, 30) },
      { role: 'button', name: 'Cancel', ref: 'c2', box: box(0, 140, 80, 30) },
    ],
  }]);

  assert.equal(navigation.length, 2, 'both Cancel buttons survive dedupe');
  const ids = navigation.map(f => f.identity).sort();
  assert.notEqual(ids[0], ids[1]);
  assert.equal(featureSignature({ role: 'button', name: 'Cancel' }), 'button::cancel');
  assert.ok(ids.every(id => id.startsWith('button::cancel::')));
});

test('a small page stays a flat ranked list with no groups', () => {
  const { navigation } = buildAuxiliaryTree([{
    role: 'main',
    ref: 'e1',
    box: box(0, 0, 800, 600),
    children: [
      { role: 'button', name: 'One', ref: 'e2', box: box(0, 0, 80, 30) },
      { role: 'button', name: 'Two', ref: 'e3', box: box(0, 40, 80, 30) },
      { role: 'button', name: 'Three', ref: 'e4', box: box(0, 80, 80, 30) },
    ],
  }]);

  assert.equal(navigation.length, 3);
  assert.ok(navigation.every(f => !f.isGroup));
});

test('featureIdentity includes the nearest named ancestor', () => {
  assert.equal(
    featureIdentity({ role: 'button', name: 'Cancel' }, 'Dialog'),
    'button::cancel::dialog');
  assert.equal(featureIdentity({ role: 'button', name: 'Cancel' }), 'button::cancel');
  assert.equal(featureIdentity({ role: 'button' }), null);
});
