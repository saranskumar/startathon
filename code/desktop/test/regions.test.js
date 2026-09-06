// Pins region extraction: top-level landmarks only, nested landmarks folded
// into their parent, friendly names, and feature membership lookup.
//
//   npm test

import test from 'node:test';
import assert from 'node:assert/strict';
import { buildAuxiliaryTree } from '../src/domTreeEngine.js';
import { extractRegions, describeRegions, regionOf } from '../src/regions.js';

const box = (x, y, width, height) => ({ x, y, width, height });

function samplePage() {
  return buildAuxiliaryTree([
    {
      role: 'banner', name: 'Header', ref: 'e1', box: box(0, 0, 800, 60),
      children: [{ role: 'link', name: 'Home', ref: 'e2', box: box(0, 0, 80, 40) }],
    },
    {
      role: 'navigation', name: 'Sidebar', ref: 'e3', box: box(0, 60, 200, 400),
      children: [
        { role: 'link', name: 'Rail', ref: 'e4', box: box(0, 60, 200, 40) },
        { role: 'link', name: 'Pay', ref: 'e5', box: box(0, 100, 200, 40) },
      ],
    },
    {
      role: 'main', name: null, ref: 'e6', box: box(200, 60, 600, 400),
      children: [
        {
          role: 'search', name: 'Site search', ref: 'e7', box: box(200, 60, 300, 40),
          children: [{ role: 'textbox', name: 'Query', ref: 'e8', box: box(200, 60, 200, 40) }],
        },
        { role: 'heading', name: 'Welcome', level: 1, ref: 'e9', box: box(200, 110, 300, 40) },
      ],
    },
  ]);
}

test('extracts exactly the three top-level landmarks with friendly names', () => {
  const { tree } = samplePage();
  const regions = extractRegions(tree);
  const names = regions.map(r => r.friendlyName).sort();
  assert.deepEqual(names, ['main content', 'side panel', 'top bar']);
});

test('a landmark nested inside another (search inside main) is folded into the parent', () => {
  const { tree } = samplePage();
  const regions = extractRegions(tree);
  const main = regions.find(r => r.role === 'main');
  // The search region's own textbox should show up as one of main's features,
  // not as a fourth sibling region.
  assert.ok(main.features.some(f => f.role === 'textbox'));
  assert.equal(regions.some(r => r.role === 'search'), false);
});

test('each region lists its own kept, non-landmark descendants', () => {
  const { tree } = samplePage();
  const regions = extractRegions(tree);
  const sidebar = regions.find(r => r.role === 'navigation');
  assert.equal(sidebar.features.length, 2);
  assert.ok(sidebar.features.every(f => !f.isLandmark));
});

test('describeRegions summarizes item counts per panel', () => {
  const { tree } = samplePage();
  const regions = extractRegions(tree);
  const summary = describeRegions(regions);
  assert.match(summary, /3 panels:/);
  assert.match(summary, /top bar \(1 items\)/);
});

test('describeRegions handles an empty region list', () => {
  assert.equal(describeRegions([]), 'No named regions on this page.');
});

test('regionOf finds the region owning a given feature path', () => {
  const { tree } = samplePage();
  const regions = extractRegions(tree);
  const sidebar = regions.find(r => r.role === 'navigation');
  const railFeature = sidebar.features.find(f => f.name === 'Rail');
  assert.equal(regionOf(regions, railFeature.path), sidebar);
});

test('regionOf returns null for a path outside every landmark', () => {
  const { tree } = samplePage();
  const regions = extractRegions(tree);
  assert.equal(regionOf(regions, 'not.a.real.path'), null);
});
