// Pins the N-ary scan-tree builder: arity padding, weight ordering (higher
// score = shorter path), and the voice-vocabulary fallback.
//
//   npm test

import test from 'node:test';
import assert from 'node:assert/strict';
import { buildScanTree, pathsOf, describe, assignVocabulary } from '../src/scanTree.js';

const feature = (label, score) => ({ label, score });

test('two features, binary arity: one merge, one path each', () => {
  const a = feature('Search', 5);
  const b = feature('Menu', 2);
  const tree = buildScanTree([a, b], { arity: 2 });
  const paths = pathsOf(tree);
  assert.equal(paths.get(a).length, 1);
  assert.equal(paths.get(b).length, 1);
  assert.notDeepEqual(paths.get(a), paths.get(b));
});

test('higher-scored features get shorter or equal paths (Huffman property)', () => {
  const features = [
    feature('Highest', 100),
    feature('High', 50),
    feature('Low', 5),
    feature('Lowest', 1),
    feature('Mid', 20),
  ];
  const tree = buildScanTree(features, { arity: 2 });
  const paths = pathsOf(tree);
  const byScoreDesc = [...features].sort((a, b) => b.score - a.score);
  for (let i = 0; i < byScoreDesc.length - 1; i += 1) {
    const shorter = paths.get(byScoreDesc[i]).length;
    const longer = paths.get(byScoreDesc[i + 1]).length;
    assert.ok(shorter <= longer, `${byScoreDesc[i].label} should not be deeper than ${byScoreDesc[i + 1].label}`);
  }
});

test('every internal node has exactly `arity` children, even when padding is needed', () => {
  const features = [1, 2, 3, 4, 5].map((s, i) => feature('f' + i, s));
  const tree = buildScanTree(features, { arity: 3 });
  (function walk(node) {
    if (node.kind === 'leaf') return;
    assert.equal(node.children.length, 3);
    node.children.forEach(walk);
  })(tree);
});

test('single feature returns a bare leaf, no tree needed', () => {
  const only = feature('Only', 1);
  const tree = buildScanTree([only]);
  assert.equal(tree.kind, 'leaf');
  assert.equal(pathsOf(tree).get(only).length, 0);
});

test('empty input returns null', () => {
  assert.equal(buildScanTree([]), null);
});

test('rejects arity below 2', () => {
  assert.throws(() => buildScanTree([feature('a', 1)], { arity: 1 }));
});

test('describe: a leaf announces its own feature, a group lists its leaves', () => {
  const a = feature('Search', 5);
  const b = feature('Menu', 2);
  const tree = buildScanTree([a, b], { arity: 2 });
  assert.deepEqual(describe(tree).split(', ').sort(), ['Menu', 'Search']);
  const leafPath = pathsOf(tree).get(a);
  assert.equal(leafPath.length, 1);
});

test('describe: a large group summarizes instead of listing everything', () => {
  const features = ['A', 'B', 'C', 'D', 'E'].map((l, i) => feature(l, i + 1));
  const tree = buildScanTree(features, { arity: 5 });
  assert.match(describe(tree), /and \d+ more$/);
});

test('assignVocabulary: direct word-per-child when vocabulary covers arity', () => {
  const features = [feature('A', 1), feature('B', 2)];
  const tree = buildScanTree(features, { arity: 2 });
  const mapping = assignVocabulary(tree, ['water', 'yellow']);
  assert.deepEqual(Object.values(mapping).sort(), [0, 1]);
});

test('assignVocabulary: next/previous/select fallback when vocabulary is smaller than arity', () => {
  const features = [feature('A', 1), feature('B', 2), feature('C', 3), feature('D', 4)];
  const tree = buildScanTree(features, { arity: 4 });
  const mapping = assignVocabulary(tree, ['water']);
  assert.deepEqual(mapping, { water: 'next' });
});

test('assignVocabulary: on a leaf or with no vocabulary, returns nothing to map', () => {
  const tree = buildScanTree([feature('Only', 1)]);
  assert.deepEqual(assignVocabulary(tree, ['water']), {});
  const group = buildScanTree([feature('A', 1), feature('B', 2)], { arity: 2 });
  assert.deepEqual(assignVocabulary(group, []), {});
});
