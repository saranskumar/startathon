// Generalizes single-switch scanning (docs/idea/03-input-calibration.md §3.5)
// and the button-count coarse-to-fine fallback (§3.3, "pick a quadrant, then a
// sub-zone, then confirm") into one shape: an N-ary partition tree over
// ranked features, where N is however many simultaneous signals the
// calibrated input can produce right now — 2 for a two-button/left-right
// switch or a binary quadrant split, 4 for a four-way swipe/D-pad, or however
// many words a calibrated voice vocabulary holds (docs/app/lib/inputs/
// voice_vocab.dart's VocabMapping is the same idea on the phone side, applied
// to the four fixed demo tasks instead of a live ranked feature list).
//
// Higher-`score` features (domTreeEngine.js's ranking) get shorter root-to-leaf
// paths — the same principle Huffman coding uses, and the same one group-
// scanning AAC software already applies to make the likely target reachable in
// fewer steps than an unlikely one. This module is pure and synchronous, same
// discipline as domTreeEngine.js and dasherModel.js: no Playwright, no network.

/**
 * @typedef {object} ScanNode
 * @property {'leaf'|'group'} kind
 * @property {number} weight - Sum of leaf scores under this node; used only to
 *   pick merge order, never shown to a user.
 * @property {object} [feature] - Present on `kind: 'leaf'` — the domTreeEngine
 *   feature this node resolves to.
 * @property {ScanNode[]} [children] - Present on `kind: 'group'`.
 */

/**
 * Build an `arity`-ary scan tree over a flat, ranked feature list.
 *
 * Huffman's n-ary merge rule: repeatingly combine the `arity` lowest-weight
 * nodes into one parent, until a single root remains. That only produces a
 * tree where every internal node has exactly `arity` children when
 * `(count - 1) % (arity - 1) == 0`; short of that, zero-weight placeholder
 * leaves are padded in first. A scanning device expects a fixed number of
 * positions per step (2 buttons are always 2 buttons), not a tree that is
 * binary on one branch and ternary on another, so the padding is required
 * correctness, not a cosmetic nicety. Placeholders never surface in
 * `describe()` or `pathsOf()` output.
 *
 * @param {object[]} features - domTreeEngine features (each needs `.score`).
 * @param {object} [options]
 * @param {number} [options.arity] - Simultaneous signals available this step
 *   (button count, swipe directions, or a voice vocabulary's word count).
 * @returns {ScanNode|null} null for an empty feature list.
 */
export function buildScanTree(features, { arity = 2 } = {}) {
  if (!Array.isArray(features) || features.length === 0) return null;
  if (!Number.isInteger(arity) || arity < 2) {
    throw new Error('arity must be an integer >= 2');
  }

  /** @type {ScanNode[]} */
  let nodes = features.map(f => ({
    kind: 'leaf',
    feature: f,
    weight: Math.max(f.score ?? 0, 0.0001),
  }));

  if (nodes.length === 1) return nodes[0];

  // Pad with zero-weight placeholders so every merge step consumes exactly
  // `arity` nodes and the final merge also lands on exactly `arity`.
  const placeholderCount = (arity - 1 - ((nodes.length - 1) % (arity - 1))) % (arity - 1);
  for (let i = 0; i < placeholderCount; i += 1) {
    nodes.push({ kind: 'leaf', feature: null, weight: 0 });
  }

  nodes.sort((a, b) => a.weight - b.weight);

  while (nodes.length > 1) {
    const group = nodes.splice(0, arity);
    const merged = {
      kind: 'group',
      children: group,
      weight: group.reduce((sum, n) => sum + n.weight, 0),
    };
    // Re-insert in sorted position (linear scan is fine — feature counts on
    // one screen are in the tens, not thousands).
    const at = nodes.findIndex(n => n.weight > merged.weight);
    if (at === -1) nodes.push(merged); else nodes.splice(at, 0, merged);
  }

  return dropEmptyPlaceholders(nodes[0]);
}

/** Placeholders (`feature: null`) exist only to keep arity fixed during the
 * merge; strip any group left holding only placeholders, and unwrap a group
 * that padding reduced to a single real child. */
function dropEmptyPlaceholders(node) {
  if (node.kind === 'leaf') return node;
  const children = node.children
    .map(dropEmptyPlaceholders)
    .filter(c => c !== null);
  if (children.length === 0) return null;
  if (children.length === 1) return children[0];
  return { ...node, children };
}

/**
 * Root-to-leaf paths for every real feature in the tree, as index sequences
 * into each level's `children` array (e.g. `[0, 1]` = "first branch, then
 * second"). The caller renders indices as whatever the calibrated input
 * actually is — `left`/`right` for a two-switch profile, `up`/`down`/`left`/
 * `right` for swipes, a spoken number for a voice grid (research/10's
 * "Android Voice Access grid" pattern), or vocabulary words via
 * `assignVocabulary` below.
 *
 * @param {ScanNode} tree
 * @returns {Map<object, number[]>} feature -> path
 */
export function pathsOf(tree) {
  const out = new Map();
  if (!tree) return out;
  (function walk(node, path) {
    if (node.kind === 'leaf') {
      if (node.feature) out.set(node.feature, path);
      return;
    }
    node.children.forEach((child, i) => walk(child, [...path, i]));
  })(tree, []);
  return out;
}

/**
 * Narration/highlight text for one node — what the narrator says (or the
 * desktop inspector shows as the highlight label) while this node is the
 * current scan position. A leaf announces the feature directly; a group
 * announces what pressing further will narrow into, so the user never sees
 * "group of 3" with no content.
 *
 * @param {ScanNode} node
 * @returns {string}
 */
export function describe(node) {
  if (!node) return '';
  if (node.kind === 'leaf') return node.feature ? node.feature.label : '';
  const names = leavesOf(node).map(f => f.label).filter(Boolean);
  if (names.length <= 3) return names.join(', ');
  return `${names.slice(0, 2).join(', ')}, and ${names.length - 2} more`;
}

function leavesOf(node) {
  if (node.kind === 'leaf') return node.feature ? [node.feature] : [];
  return node.children.flatMap(leavesOf);
}

/**
 * Map a calibrated voice vocabulary onto one node's children, mirroring
 * `code/app/lib/inputs/voice_vocab.dart`'s `VocabMapping.mapWords`: when there
 * are at least as many words as children, each child gets its own word
 * directly; otherwise the first word means "next child", the second (if any)
 * "previous", the third (if any) "select this one" — the same three-tier
 * fallback the phone already uses for the four fixed demo tasks, applied here
 * to a live ranked feature list instead.
 *
 * @param {ScanNode} node - A `kind: 'group'` node.
 * @param {string[]} vocabulary
 * @returns {Record<string, number>} word -> child index, or word -> the
 *   string `'next' | 'previous' | 'select'` when direct mapping doesn't fit.
 */
export function assignVocabulary(node, vocabulary) {
  if (!node || node.kind !== 'group' || vocabulary.length === 0) return {};
  const words = vocabulary.map(w => w.trim().toLowerCase()).filter(Boolean);
  if (words.length === 0) return {};

  if (node.children.length <= words.length) {
    return Object.fromEntries(node.children.map((_, i) => [words[i], i]));
  }

  const out = { [words[0]]: 'next' };
  if (words.length > 1) out[words[1]] = 'previous';
  if (words.length > 2) out[words[2]] = 'select';
  return out;
}
